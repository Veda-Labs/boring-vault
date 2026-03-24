// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {
    TellerWithMultiAssetSupport,
    ERC20,
    DepositParams,
    ComplianceData,
    PermitData,
    Asset
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {MessageLib} from "src/base/Roles/CrossChain/MessageLib.sol";
import {CrossChainTellerLib} from "src/base/Roles/CrossChain/CrossChainTellerLib.sol";

abstract contract CrossChainTellerWithGenericBridge is TellerWithMultiAssetSupport {
    using MessageLib for uint256;
    using MessageLib for MessageLib.Message;

    //============================== STRUCTS ===============================
    struct DepositAndBridgeWithPermitParams {
        DepositParams depositParams;
        PermitData permit;
        address to;
        bytes bridgeWildCard;
        ERC20 feeToken;
        uint256 maxFee;
        address referralAddress;
        ComplianceData compliance;
    }

    //============================== ERRORS ===============================

    error CrossChainTellerWithGenericBridge__UnsafeCastToUint96();

    //============================== EVENTS ===============================

    event MessageSent(bytes32 indexed messageId, uint256 shareAmount, address indexed to);

    //============================== IMMUTABLES ===============================

    constructor(address _owner, address _vault, address _accountant, address _weth)
        TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth)
    {}

    // ========================================= PUBLIC FUNCTIONS =========================================

    /**
     * @notice Deposit an asset and bridge the shares to another chain.
     * @dev This function will REVERT if `beforeTransfer` hook reverts from:
     *     - shares being locked
     *     - allow list
     * @dev Since call to `bridge` is public, msg.sig is not updated which means any role capabilities regarding this function
     *      are also granted to the `bridge` function.
     */
    function depositAndBridge(
        DepositParams calldata params,
        address to,
        bytes calldata bridgeWildCard,
        ERC20 feeToken,
        uint256 maxFee,
        address referralAddress,
        ComplianceData calldata compliance
    ) external payable requiresAuth nonReentrant returns (uint256 sharesBridged) {
        sharesBridged = _depositAndBridge(params, to, bridgeWildCard, feeToken, maxFee, referralAddress, compliance);
    }

    /**
     * @notice Deposit an asset and bridge the shares to another chain using a permit.
     * @dev This function will REVERT if `beforeTransfer` hook reverts from:
     *     - shares being locked
     *     - allow list
     * @dev Since calls to `depositWithPermit` and `bridge` are public, msg.sig is not updated which means any role capabilities regarding this function
     *      are also granted to the `depositWithPermit` and `bridge` function.
     */
    function depositAndBridgeWithPermit(DepositAndBridgeWithPermitParams calldata params)
        external
        payable
        requiresAuth
        nonReentrant
        returns (uint256 sharesBridged)
    {
        _handlePermit(params.depositParams.depositAsset, params.depositParams.depositAmount, params.permit);
        sharesBridged = _depositAndBridge(
            params.depositParams,
            params.to,
            params.bridgeWildCard,
            params.feeToken,
            params.maxFee,
            params.referralAddress,
            params.compliance
        );
    }

    /**
     * @notice Bridge shares to another chain.
     * @param shareAmount The amount of shares to bridge.
     * @param to The address to send the shares to on the other chain.
     * @param bridgeWildCard The bridge specific data to configure message.
     * @param feeToken The token to pay the bridge fee in.
     * @param maxFee The maximum fee to pay the bridge.
     */
    function bridge(
        uint96 shareAmount,
        address to,
        bytes calldata bridgeWildCard,
        ERC20 feeToken,
        uint256 maxFee,
        ComplianceData calldata compliance
    ) external payable requiresAuth nonReentrant {
        if (isPaused) revert TellerWithMultiAssetSupport__Paused();
        _verifyBridgeCompliance(msg.sender, shareAmount, to, compliance.deadline, compliance.signature);
        _bridge(shareAmount, to, bridgeWildCard, feeToken, maxFee);
    }

    /**
     * @notice Preview fee required to bridge shares in a given feeToken.
     */
    function previewFee(uint96 shareAmount, address to, bytes calldata bridgeWildCard, ERC20 feeToken)
        external
        view
        returns (uint256 fee)
    {
        MessageLib.Message memory m = MessageLib.Message(shareAmount, to);
        uint256 message = m.messageToUint256();

        return _previewFee(message, bridgeWildCard, feeToken);
    }

    // ========================================= INTERNAL BRIDGE FUNCTIONS =========================================

    /**
     * @notice Verify compliance for a combined deposit-and-bridge operation.
     * @dev Builds a message hash that covers both the deposit parameters and the bridge destination,
     *      so the compliance signer explicitly approves the full action in a single signature.
     */
    function _verifyDepositAndBridgeCompliance(
        address depositor,
        ERC20 depositAsset,
        uint256 depositAmount,
        address to,
        ComplianceData calldata compliance
    ) internal {
        if (complianceSigner == address(0)) return;
        bytes32 messageHash = keccak256(
            abi.encode(
                address(this), block.chainid, depositor, address(depositAsset), depositAmount, to, compliance.deadline
            )
        );
        _verifyAndMark(messageHash, compliance.deadline, compliance.signature);
    }

    /**
     * @notice Shared deposit-and-bridge logic used by both `depositAndBridge` and `depositAndBridgeWithPermit`.
     * @dev `depositParams.to` is intentionally ignored; shares are minted to `msg.sender` then immediately bridged
     *      to the separate `to` parameter (the cross-chain recipient).
     */
    function _depositAndBridge(
        DepositParams calldata depositParams,
        address to,
        bytes calldata bridgeWildCard,
        ERC20 feeToken,
        uint256 maxFee,
        address referralAddress,
        ComplianceData calldata compliance
    ) internal returns (uint256 sharesBridged) {
        _verifyDepositAndBridgeCompliance(
            msg.sender, depositParams.depositAsset, depositParams.depositAmount, to, compliance
        );
        {
            Asset memory asset = _beforeDeposit(depositParams.depositAsset);
            sharesBridged = _erc20Deposit(
                depositParams.depositAsset,
                depositParams.depositAmount,
                depositParams.minimumMint,
                msg.sender,
                msg.sender,
                asset
            );
        }
        _checkpointPrincipalAtRate(msg.sender, sharesBridged, true, accountant.getRateSafe());
        _afterPublicDeposit(
            msg.sender,
            depositParams.depositAsset,
            depositParams.depositAmount,
            sharesBridged,
            shareLockPeriod,
            referralAddress
        );

        if (sharesBridged > type(uint96).max) revert CrossChainTellerWithGenericBridge__UnsafeCastToUint96();
        _bridge(uint96(sharesBridged), to, bridgeWildCard, feeToken, maxFee);
    }

    /**
     * @notice Implement the bridge logic.
     */
    function _bridge(uint96 shareAmount, address to, bytes calldata bridgeWildCard, ERC20 feeToken, uint256 maxFee)
        internal
    {
        // Since shares are directly burned, call `beforeTransfer` to enforce before transfer hooks.
        beforeTransfer(msg.sender, address(0), msg.sender);

        // Record withdrawal checkpoint so the sender's principal decreases on the source chain.
        // Without this, bridged users retain phantom principal that inflates off-chain reward calculations.
        _checkpointPrincipalAtRate(msg.sender, shareAmount, false, accountant.getRateSafe());

        // Burn shares and encode the bridge message (delegated to library to reduce bytecode).
        uint256 message = CrossChainTellerLib.burnAndEncode(vault, msg.sender, shareAmount, to);

        bytes32 messageId = _sendMessage(message, bridgeWildCard, feeToken, maxFee);

        emit MessageSent(messageId, shareAmount, to);
    }

    /**
     * @notice Complete the message receive process, should be called in child contract once
     *         message has been confirmed as legit.`
     */
    function _completeMessageReceive(bytes32 messageId, uint256 message) internal {
        CrossChainTellerLib.completeMessageReceive(vault, messageId, message);
    }

    /**
     * @notice Send the message to the bridge implementation.
     * @dev This function should handle reverting if maxFee exceeds the fee required to send the message.
     * @dev This function should handle collecting the fee.
     * @param message The message to send.
     * @param bridgeWildCard The bridge specific data to configure message.
     * @param feeToken The token to pay the bridge fee in.
     * @param maxFee The maximum fee to pay the bridge.
     */
    function _sendMessage(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken, uint256 maxFee)
        internal
        virtual
        returns (bytes32 messageId);

    /**
     * @notice Preview fee required to bridge shares in a given token.
     */
    function _previewFee(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken)
        internal
        view
        virtual
        returns (uint256 fee);

    /**
     * @notice Returns the version of the contract.
     */
    function version() public pure virtual override returns (string memory) {
        return "Cross Chain V0.1, Base V0.3";
    }
}
