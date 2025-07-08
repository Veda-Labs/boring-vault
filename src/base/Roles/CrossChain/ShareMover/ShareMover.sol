// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

// Core dependencies for contract functionality
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol"; // Reentrancy protection
import {ERC20} from "@solmate/tokens/ERC20.sol"; // Standard ERC20 interface

// Custom libraries/interfaces specific to Boring Vault ecosystem
import {MessageLib} from "./MessageLib.sol"; // Message encoding/decoding

/**
 * @notice Interface for the Boring Vault contract.
 * @dev This interface defines the expected functions for interacting with Boring Vault shares.
 */
interface IVault {
    function enter(address from, ERC20 asset, uint256 assetAmount, address to, uint256 shareAmount) external;
    function exit(address to, ERC20 asset, uint256 assetAmount, address from, uint256 shareAmount) external;
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}

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

    // ========================================= STATE =========================================

    /// @notice The address of the Boring Vault contract this ShareMover interacts with.
    IVault public immutable vault;

    // ========================================= ERRORS =========================================

    /// @dev Thrown when an attempt is made to bridge zero shares.
    error ShareMover__ZeroShares();
    /// @dev Thrown when an ERC20 permit signature is invalid.
    error ShareMover__InvalidPermit();
    /// @dev Thrown when insufficient balance for bridge operation.
    error ShareMover__InsufficientBalance();
    /// @dev Thrown when recipient address is invalid (e.g., zero address).
    error ShareMover__InvalidRecipient();
    /// @dev Thrown when message encoding/decoding fails.
    error ShareMover__InvalidMessage();
    /// @dev Thrown when vault.transferFrom returns false.
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
        uint128 amount,
        address user
    );

    /// @notice Emitted when shares are successfully received from another chain and minted.
    /// @param messageId The unique identifier of the cross-chain message.
    /// @param chainId The source chain identifier.
    /// @param recipient The destination address (32-byte format).
    /// @param amount The amount of shares received and minted.
    event MessageReceived(
        bytes32 indexed messageId,
        uint32 indexed chainId,
        bytes32 indexed recipient,
        uint128 amount
    );

    // ========================================= CONSTRUCTOR =========================================

    /**
     * @notice Constructor for the ShareMover contract.
     * @param _vault The address of the Boring Vault contract.
     */
    constructor(address _vault) {
        if (_vault == address(0)) revert ShareMover__InvalidRecipient();
        vault = IVault(_vault);
    }

    // ========================================= PUBLIC FUNCTIONS =========================================

    /**
     * @notice Bridges a specified amount of shares from the caller's account to a destination address on another chain.
     * Requires prior approval of shares to this contract if the vault's share token is standard ERC20.
     * @dev This function includes the `whenNotPaused` modifier, reverting if the contract is paused.
     * @param shareAmount The amount of shares to bridge (in uint96).
     * @param chainId The destination chain identifier.
     * @param to The destination address on the target chain (32-byte format).
     * @param bridgeWildCard Bridge-specific data for configuring the cross-chain message.
     * @param feeToken The ERC20 token used to pay the bridge fee. Use NATIVE for native token.
     */
    function bridge(
        uint96 shareAmount,
        uint32 chainId,
        bytes32 to,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) public payable virtual nonReentrant {
        _bridge(shareAmount, chainId, to, bridgeWildCard, msg.sender, feeToken);
    }

    /**
     * @notice Bridges a specified amount of shares using an EIP-2612 permit signature,
     * avoiding a separate approval transaction for the vault's share token.
     * @dev This function assumes the vault's share token supports the ERC20Permit standard.
     * Includes the `whenNotPaused` modifier, reverting if the contract is paused.
     * @param shareAmount The amount of shares to bridge (in uint96).
     * @param chainId The destination chain identifier.
     * @param to The destination address on the target chain (32-byte format).
     * @param bridgeWildCard Bridge-specific data.
     * @param deadline The time after which the permit is no longer valid.
     * @param v The recovery byte of the signature.
     * @param r The R component of the signature.
     * @param s The S component of the signature.
     * @param feeToken The ERC20 token used to pay the bridge fee. Use NATIVE for native token.
     */
    function bridgeWithPermit(
        uint96 shareAmount,
        uint32 chainId,
        bytes32 to,
        bytes calldata bridgeWildCard,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        ERC20 feeToken
    ) public payable virtual nonReentrant {
        // Attempt to apply the permit signature for the shares.
        try vault.permit(msg.sender, address(this), shareAmount, deadline, v, r, s) {
            // Permit successful, proceed with bridge
        } catch {
            revert ShareMover__InvalidPermit();
        }

        _bridge(shareAmount, chainId, to, bridgeWildCard, msg.sender, feeToken);
    }

    /**
     * @notice Previews the fee required to bridge shares to a given destination chain.
     * @param shareAmount The amount of shares to bridge.
     * @param chainId The destination chain identifier.
     * @param to The destination address on the target chain (32-byte format).
     * @param bridgeWildCard Bridge-specific data for configuring the cross-chain message.
     * @param feeToken The ERC20 token to pay the bridge fee in. Use NATIVE for native token.
     * @return fee The estimated fee required for the bridge operation.
     */
    function previewFee(
        uint96 shareAmount,
        uint32 chainId,
        bytes32 to,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) public view virtual returns (uint256 fee) {
        if (shareAmount == 0) revert ShareMover__ZeroShares();
        if (to == bytes32(0)) revert ShareMover__InvalidRecipient();

        // Create the message struct
        MessageLib.Message memory message = MessageLib.Message({
            recipient: to,
            amount: uint128(shareAmount) // Bridge implementations will handle decimal conversion
        });

        return _previewFee(message, chainId, bridgeWildCard, feeToken);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /**
     * @notice Core internal routine executed by both {bridge} and {bridgeWithPermit}.
     * @dev Steps:
     *  1. Validate inputs (non-zero amount & recipient).
     *  2. Ensure `user` has enough shares in {vault}.
     *  3. Pull shares from `user` via `transferFrom` – *may* trigger before-transfer hooks.
     *  4. Burn those shares by calling `vault.exit` with `from = address(this)`.
     *  5. Assemble a {MessageLib.Message} (shares still in source-chain decimals).
     *  6. Delegate cross-chain logistics to the bridge-specific `_sendMessage`.
     *
     *  The function is `nonReentrant` thanks to the public wrappers, so a malicious
     *  vault hook cannot recursively call back into any ShareMover entrypoint.
     *
     *  Reverts:
     *  - ShareMover__ZeroShares        If `shareAmount == 0`.
     *  - ShareMover__InvalidRecipient  If `to == bytes32(0)`.
     *  - ShareMover__InsufficientBalance If `vault.balanceOf(user) < shareAmount`.
     *  - ShareMover__TransferFailed    If `vault.transferFrom` returns false.
     *
     * @param shareAmount   Amount of shares to bridge on the source chain (uint96 to save gas).
     * @param chainId       Destination chain identifier understood by the concrete mover.
     * @param to            32-byte recipient address on the destination chain.
     * @param bridgeWildCard Opaque bytes forwarded to the concrete mover for fee / gas / etc.
     * @param user          Account that provided the shares (msg.sender in public wrappers).
     * @param feeToken      ERC20 token used for fee payment; `NATIVE` sentinel for native coin.
     */
    function _bridge(
        uint96 shareAmount,
        uint32 chainId,
        bytes32 to,
        bytes calldata bridgeWildCard,
        address user,
        ERC20 feeToken
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

        // Create the message struct - bridge implementations will handle decimal conversion
        MessageLib.Message memory message = MessageLib.Message({
            recipient: to,
            amount: uint128(shareAmount)
        });

        // Call the abstract `_sendMessage` function, which will be implemented by concrete bridge contracts.
        bytes32 messageId = _sendMessage(message, chainId, bridgeWildCard, feeToken);

        emit MessageSent(messageId, chainId, to, uint128(shareAmount), user);
    }

    /**
     * @notice Internal function to complete the message reception process.
     * This function should be called by the concrete bridge implementation (e.g., LayerZeroShareMover)
     * once a cross-chain message has been confirmed as legitimate.
     * It mints shares to the recipient address on the current chain.
     * @param messageId The unique identifier of the cross-chain message.
     * @param sourceChainId The chain ID where the message originated.
     * @param message The decoded Message.
     */
    function _completeMessageReceive(
        bytes32 messageId,
        uint32 sourceChainId,
        MessageLib.Message memory message
    ) internal {
        if (messageId == bytes32(0)) revert ShareMover__InvalidMessage();
        if (message.recipient == bytes32(0)) revert ShareMover__InvalidRecipient();

        // Convert recipient from bytes32 to address for vault operations
        address recipient = MessageLib.extractEvmAddress(message.recipient);
        if (recipient == address(0)) revert ShareMover__InvalidRecipient();

        // Mint shares to the recipient address via vault.enter
        // Note: BoringVault.enter mints shares to the 'to' address (4th parameter)
        vault.enter(address(0), ERC20(address(0)), 0, recipient, message.amount);

        emit MessageReceived(messageId, sourceChainId, message.recipient, message.amount);
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
     * @param message        Prepared Message struct (amount still in source decimals).
     * @param chainId        Destination chain id.
     * @param bridgeWildCard Opaque, bridge-specific configuration blob.
     * @param feeToken       Token used to pay the bridge fee.
     * @return messageId     Unique identifier (GUID, hash, etc.) assigned by the bridge.
     */
    function _sendMessage(
        MessageLib.Message memory message,
        uint32 chainId,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) internal virtual returns (bytes32 messageId);

    /**
     * @notice Lightweight version of {_sendMessage} used for front-end fee estimation.
     * @dev Must apply the **exact** same decimal conversion and options encoding that
     *      `_sendMessage` would use so the quote is accurate.  MUST revert on the same
     *      error conditions except those related to msg.value / approvals.
     */
    function _previewFee(
        MessageLib.Message memory message,
        uint32 chainId,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) internal view virtual returns (uint256 fee);
}