// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {
    CrossChainTellerWithGenericBridge,
    ERC20
} from "src/base/Roles/CrossChain/CrossChainTellerWithGenericBridge.sol";
import {OAppAuth, Origin, MessagingFee, MessagingReceipt} from "@oapp-auth/OAppAuth.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {PairwiseRateLimiterLib} from "src/base/Roles/CrossChain/PairwiseRateLimiterLib.sol";
import {MessageLib} from "src/base/Roles/CrossChain/MessageLib.sol";
import {LayerZeroTellerLib} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerLib.sol";

contract LayerZeroTellerWithRateLimiting is CrossChainTellerWithGenericBridge, OAppAuth {
    using AddressToBytes32Lib for address;
    using MessageLib for uint256;

    // ========================================= STATE =========================================

    /**
     * @notice Maps chain selector to chain information.
     */
    mapping(uint32 => LayerZeroTellerLib.Chain) public idToChains;

    /**
     * @dev Mapping from peer endpoint id to RateLimit Configurations.
     */
    mapping(uint32 dstEid => PairwiseRateLimiterLib.RateLimit limit) public outboundRateLimits;
    mapping(uint32 srcEid => PairwiseRateLimiterLib.RateLimit limit) public inboundRateLimits;

    //============================== IMMUTABLES ===============================

    /**
     * @notice The LayerZero token.
     */
    address internal immutable lzToken;

    constructor(
        address _owner,
        address _vault,
        address _accountant,
        address _weth,
        address _lzEndPoint,
        address _delegate,
        address _lzToken
    ) CrossChainTellerWithGenericBridge(_owner, _vault, _accountant, _weth) OAppAuth(_lzEndPoint, _delegate) {
        lzToken = _lzToken;
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Add a chain to the teller, or update an existing one.
     * @dev Callable by OWNER_ROLE. This performs a full overwrite of the chain configuration.
     *      When updating an existing chain (e.g. re-enabling a stopped direction), the caller
     *      must include all desired values — any fields not explicitly set will be overwritten.
     */
    function addChain(
        uint32 chainId,
        bool allowMessagesFrom,
        bool allowMessagesTo,
        address targetTeller,
        uint128 messageGasLimit
    ) external requiresAuth {
        LayerZeroTellerLib.addChain(
            idToChains, chainId, allowMessagesFrom, allowMessagesTo, targetTeller, messageGasLimit
        );
        _setPeer(chainId, targetTeller.toBytes32());
    }

    /**
     * @notice Remove a chain from the teller.
     * @dev Callable by MULTISIG_ROLE.
     */
    function removeChain(uint32 chainId) external requiresAuth {
        LayerZeroTellerLib.removeChain(idToChains, chainId);
        _setPeer(chainId, bytes32(0));
    }

    /**
     * @notice Stop messages from and/or to a chain.
     * @dev Callable by MULTISIG_ROLE.
     */
    function stopMessages(uint32 chainId, bool stopFrom, bool stopTo) external requiresAuth {
        if (stopFrom) LayerZeroTellerLib.stopMessagesFromChain(idToChains, chainId);
        if (stopTo) LayerZeroTellerLib.stopMessagesToChain(idToChains, chainId);
    }

    /**
     * @notice Set outbound and/or inbound rate limit configurations.
     * @dev Callable by MULTISIG_ROLE. Pass empty array to skip a direction.
     */
    function setRateLimits(
        PairwiseRateLimiterLib.RateLimitConfig[] calldata _outboundConfigs,
        PairwiseRateLimiterLib.RateLimitConfig[] calldata _inboundConfigs
    ) external requiresAuth {
        if (_outboundConfigs.length > 0) {
            PairwiseRateLimiterLib.setOutboundRateLimits(outboundRateLimits, _outboundConfigs);
        }
        if (_inboundConfigs.length > 0) {
            PairwiseRateLimiterLib.setInboundRateLimits(inboundRateLimits, _inboundConfigs);
        }
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @notice Get the current amount that can be sent to this peer endpoint id for the given rate limit window.
     */
    function getAmountCanBeSent(uint32 _dstEid)
        external
        view
        returns (uint256 outboundAmountInFlight, uint256 amountCanBeSent)
    {
        return PairwiseRateLimiterLib.getAmountCanBeSentFromMapping(outboundRateLimits, _dstEid);
    }

    /**
     * @notice Get the current amount that can be received from this peer endpoint for the given rate limit window.
     */
    function getAmountCanBeReceived(uint32 _srcEid)
        external
        view
        returns (uint256 inboundAmountInFlight, uint256 amountCanBeReceived)
    {
        return PairwiseRateLimiterLib.getAmountCanBeSentFromMapping(inboundRateLimits, _srcEid);
    }

    // ========================================= OAppAuthReceiver =========================================

    /**
     * @notice Receive messages from the LayerZero endpoint.
     * @dev `lzReceive` only sanitizes the message sender, but we also need to make sure we are allowing messages
     *      from the source chain.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    )
        internal
        override
    {
        LayerZeroTellerLib.validateSourceChain(idToChains, _origin.srcEid);
        uint256 message = abi.decode(_message, (uint256));
        PairwiseRateLimiterLib.checkAndUpdateInboundRateLimit(
            inboundRateLimits, _origin.srcEid, message.uint256ToMessage().shareAmount
        );
        _completeMessageReceive(_guid, message);
    }

    // ========================================= INTERNAL BRIDGE FUNCTIONS =========================================

    /**
     * @notice Sends messages using Layer Zero end point.
     */
    function _sendMessage(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken, uint256 maxFee)
        internal
        override
        returns (bytes32 messageId)
    {
        uint32 destinationId = abi.decode(bridgeWildCard, (uint32));
        PairwiseRateLimiterLib.checkAndUpdateOutboundRateLimit(
            outboundRateLimits, destinationId, message.uint256ToMessage().shareAmount
        );
        (bytes memory m, bytes memory options) =
            LayerZeroTellerLib.validateDestAndBuildMessage(idToChains, destinationId, message);
        MessagingFee memory fee = _quote(destinationId, m, options, address(feeToken) != NATIVE);
        LayerZeroTellerLib.validateFeeAndCheck(address(feeToken), NATIVE, lzToken, destinationId, fee, maxFee);
        MessagingReceipt memory receipt = _lzSend(destinationId, m, options, fee, msg.sender);

        messageId = receipt.guid;
    }

    /**
     * @notice Preview fee required to bridge shares in a given feeToken.
     */
    function _previewFee(uint256 message, bytes calldata bridgeWildCard, ERC20 feeToken)
        internal
        view
        override
        returns (uint256 fee)
    {
        uint32 destinationId = abi.decode(bridgeWildCard, (uint32));
        (bytes memory m, bytes memory options) =
            LayerZeroTellerLib.validateDestAndBuildMessage(idToChains, destinationId, message);
        MessagingFee memory messageFee = _quote(destinationId, m, options, address(feeToken) != NATIVE);
        fee = LayerZeroTellerLib.validateAndSelectFee(address(feeToken), NATIVE, lzToken, messageFee);
    }

    /**
     * @notice Returns the version of the contract.
     */
    function version() public pure virtual override returns (string memory) {
        return "LayerZero Rate Limiting V0.1, Cross Chain V0.1, Base V0.3";
    }
}
