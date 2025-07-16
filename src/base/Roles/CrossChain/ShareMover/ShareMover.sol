// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {MessageLib} from "./MessageLib.sol";

/**
 * @title ShareMover
 * @notice An abstract contract providing a standardized interface for bridging Boring Vault Shares cross-chain.
 * It defines the core logic for burning shares on the source chain and minting on the destination.
 * Specific bridge implementations (e.g., LayerZero) will inherit from this contract.
 * @dev Emergency pause functionality is implemented in concrete ShareMover implementations (e.g., LayerZeroShareMover).
 */
abstract contract ShareMover is ReentrancyGuard {
    using MessageLib for MessageLib.Message;

    // ========================================= CONSTANTS =========================================

    /// @notice Native token identifier for fee payments
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // ========================================= IMMUTABLES =========================================

    /// @notice The address of the Boring Vault contract this ShareMover interacts with.
    BoringVault public immutable vault;

    // ========================================= ERRORS =========================================

    error ShareMover__ZeroShares();
    error ShareMover__InvalidPermit();
    error ShareMover__InsufficientBalance();
    error ShareMover__InvalidRecipient();
    error ShareMover__InvalidMessage();
    error ShareMover__TransferFailed();

    // ========================================= EVENTS =========================================

    /// @notice Emitted when shares are successfully sent to another chain via a bridge.
    /// @param messageId The unique identifier of the cross-chain message.
    /// @param chainId The destination chain identifier.
    /// @param recipient The destination address (32-byte format).
    /// @param amount The amount of shares bridged.
    /// @param user The user who initiated the bridge.
    event MessageSent(
        bytes32 indexed messageId,
        uint32 indexed chainId,
        bytes32 indexed recipient,
        uint96 amount,
        address user
    );

    /// @notice Emitted when shares are successfully received from another chain and minted.
    /// @param messageId The unique identifier of the cross-chain message.
    /// @param chainId The chain id the message originated from.
    /// @param recipient The destination address (32-byte format).
    /// @param amount The amount of shares received and minted.
    event MessageReceived(
        bytes32 indexed messageId,
        uint32 indexed chainId,
        bytes32 indexed recipient,
        uint96 amount
    );

    // ========================================= CONSTRUCTOR =========================================

    /**
     * @notice Constructor for the ShareMover contract.
     * @param _vault The address of the Boring Vault contract.
     */
    constructor(address _vault) {
        vault = BoringVault(payable(_vault));
    }

    // ========================================= PUBLIC FUNCTIONS =========================================

    /**
     * @notice Bridges a specified amount of shares from the caller's account to a destination address on another chain.
     * Requires prior approval of shares to this contract if the vault's share token is standard ERC20.
     * @dev This function includes the `whenNotPaused` modifier, reverting if the contract is paused.
     * @param shareAmount The amount of shares to bridge (in uint96).
     * @param to The destination address on the target chain (32-byte format).
     * @param bridgeWildCard Bridge-specific data for configuring the cross-chain message (includes destination chainId & fee info).
     */
    function bridge(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) public payable virtual nonReentrant {
        _bridge(shareAmount, to, bridgeWildCard, msg.sender);
    }

    /**
     * @notice Bridges a specified amount of shares using an EIP-2612 permit signature,
     * avoiding a separate approval transaction for the vault's share token.
     * @dev This function assumes the vault's share token supports the ERC20Permit standard.
     * Includes the `whenNotPaused` modifier, reverting if the contract is paused.
     * @param shareAmount The amount of shares to bridge (in uint96).
     * @param to The destination address on the target chain (32-byte format).
     * @param bridgeWildCard Bridge-specific data (includes destination chainId & fee info).
     * @param deadline The time after which the permit is no longer valid.
     * @param v The recovery byte of the signature.
     * @param r The R component of the signature.
     * @param s The S component of the signature.
     */
    function bridgeWithPermit(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual nonReentrant {
        try vault.permit(msg.sender, address(this), shareAmount, deadline, v, r, s) {}
        catch {
            revert ShareMover__InvalidPermit();
        }

        _bridge(shareAmount, to, bridgeWildCard, msg.sender);
    }

    /**
     * @notice Previews the fee required to bridge shares to a given destination chain.
     * @param shareAmount The amount of shares to bridge.
     * @param to The destination address on the target chain (32-byte format).
     * @param bridgeWildCard Bridge-specific data for configuring the cross-chain message.
     * @return fee The estimated fee required for the bridge operation.
     */
    function previewFee(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) public view virtual returns (uint256 fee) {
        if (shareAmount == 0) revert ShareMover__ZeroShares();
        if (to == bytes32(0)) revert ShareMover__InvalidRecipient();

        return _previewFee(shareAmount, to, bridgeWildCard);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /**
     * @notice Core internal routine executed by both {bridge} and {bridgeWithPermit}.
     * @param shareAmount   Amount of shares to bridge on the source chain (uint96 to save gas).
     * @param to            32-byte recipient address on the destination chain.
     * @param bridgeWildCard Opaque bytes forwarded to the concrete mover for fee / gas / etc. (includes chainId & fee info).
     * @param user          Account that provided the shares (msg.sender in public wrappers).
     */
    function _bridge(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard,
        address user
    ) internal {
        if (shareAmount == 0) revert ShareMover__ZeroShares();
        if (to == bytes32(0)) revert ShareMover__InvalidRecipient();

        // Check user has sufficient balance
        if (vault.balanceOf(user) < shareAmount) revert ShareMover__InsufficientBalance();

        // Transfer shares from user to this contract (triggers beforeTransfer hook via vault)
        if (!vault.transferFrom(user, address(this), shareAmount)) {
            revert ShareMover__TransferFailed();
        }

        // Burn shares from this contract via vault.exit
        // Note: BoringVault.exit burns shares from the 'from' address (4th parameter)
        vault.exit(address(0), ERC20(address(0)), 0, address(this), shareAmount);

        // Call the abstract `_sendMessage` function, which will be implemented by concrete bridge contracts.
        (bytes32 messageId, uint32 chainId) = _sendMessage(shareAmount, to, bridgeWildCard);

        emit MessageSent(messageId, chainId, to, shareAmount, user);
    }

    /**
     * @notice Internal function to complete the message reception process.
     * This function should be called by the concrete bridge implementation (e.g., LayerZeroShareMover)
     * once a cross-chain message has been confirmed as legitimate.
     * It mints shares to the recipient address on the current chain.
     * @param messageId The unique identifier of the cross-chain message.
     * @param shareAmount The amount of shares to mint on the destination chain.
     * @param to The recipient address on the destination chain (bytes32 format).
     */
    function _completeMessageReceive(
        bytes32 messageId,
        uint32 chainId,
        uint96 shareAmount,
        bytes32 to
    ) internal {
        if (messageId == bytes32(0)) revert ShareMover__InvalidMessage();
        if (to == bytes32(0)) revert ShareMover__InvalidRecipient();

        // Convert recipient from bytes32 to address for vault operations
        address recipient = MessageLib.extractEvmAddress(to);
        if (recipient == address(0)) revert ShareMover__InvalidRecipient();

        // Mint shares to the recipient address via vault.enter
        vault.enter(address(0), ERC20(address(0)), 0, recipient, shareAmount);

        emit MessageReceived(messageId, chainId, to, shareAmount);
    }

    // ========================================= ABSTRACT FUNCTIONS =========================================

    /**
     * @notice Bridge-specific dispatch hook implemented by concrete movers.
     * @dev Implementations **MUST**:
     *  - Convert `message.amount` to destination-decimals before encoding.
     *  - Enforce per-peer rate limits.
     *  - Quote fees and compare against `maxFee` from `bridgeWildCard`.
     *  - Collect the fee (msg.value or ERC20 transfer) *before* calling the transport.
     *  - Revert with a descriptive custom error when any check fails.
     *
     * @param shareAmount    Amount of shares to bridge on the source chain (uint96).
     * @param to             32-byte recipient address on the destination chain.
     * @param bridgeWildCard Opaque, bridge-specific configuration blob.
     * @return messageId     Unique identifier (GUID, hash, etc.) assigned by the bridge.
     * @return chainId       Destination chain identifier parsed from bridgeWildCard.
     */
    function _sendMessage(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) internal virtual returns (bytes32 messageId, uint32 chainId);

    /**
     * @notice Preview fee required to bridge shares using the data encoded in bridgeWildCard.
     */
    function _previewFee(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) internal view virtual returns (uint256 fee);
}