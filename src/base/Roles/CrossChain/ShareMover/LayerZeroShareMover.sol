// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ShareMover} from "./ShareMover.sol";
import {MessageLib} from "./MessageLib.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {OAppAuth, Origin, MessagingFee, MessagingReceipt} from "@oapp-auth/OAppAuth.sol";
import {OptionsBuilder} from "@oapp-auth/OptionsBuilder.sol";
import {PairwiseRateLimiter} from "./PairwiseRateLimiter.sol";
import {Auth} from "@solmate/auth/Auth.sol";

/**
 * @title LayerZeroShareMover
 * @notice Concrete implementation of ShareMover using LayerZero for cross-chain bridging.
 * @dev Inherits from ShareMover, OAppAuth for LayerZero integration, PairwiseRateLimiter for rate limiting,
 * and Auth for access control.
 */
contract LayerZeroShareMover is ShareMover, OAppAuth, PairwiseRateLimiter, Auth {
    using SafeTransferLib for ERC20;
    using OptionsBuilder for bytes;
    using MessageLib for MessageLib.Message;

    // ========================================= STRUCTS =========================================

    /**
     * @notice Stores information about a chain.
     * @dev Peer address is stored in OAppAuthCore `peers` mapping.
     * @param allowMessagesFrom Whether to allow messages from this chain.
     * @param allowMessagesTo Whether to allow messages to this chain.
     * @param messageGasLimit The gas limit for messages to this chain.
     * @param targetDecimals The decimal places used by shares on the target chain.
     */
    struct Chain {
        bool allowMessagesFrom;
        bool allowMessagesTo;
        uint128 messageGasLimit;
        uint8 targetDecimals;
    }

    // ========================================= STATE =========================================

    /**
     * @notice Maps chain endpoint ID to chain information.
     */
    mapping(uint32 => Chain) public chains;

    /**
     * @notice The decimal places used by the vault shares on this chain.
     */
    uint8 public immutable localDecimals;

    // ========================================= ERRORS =========================================

    error LayerZeroShareMover__MessagesNotAllowedFrom(uint32 chainId);
    error LayerZeroShareMover__MessagesNotAllowedTo(uint32 chainId);
    error LayerZeroShareMover__FeeExceedsMax(uint32 chainId, uint256 fee, uint256 maxFee);
    error LayerZeroShareMover__BadFeeToken();
    error LayerZeroShareMover__ZeroMessageGasLimit();
    error LayerZeroShareMover__InvalidChainId();
    error LayerZeroShareMover__InvalidTargetDecimals();

    // ========================================= EVENTS =========================================

    event ChainAdded(uint32 indexed chainId, bool allowMessagesFrom, bool allowMessagesTo, bytes32 targetShareMover, uint8 targetDecimals);
    event ChainRemoved(uint32 indexed chainId);
    event ChainAllowMessagesFrom(uint32 indexed chainId, bytes32 targetShareMover);
    event ChainAllowMessagesTo(uint32 indexed chainId, bytes32 targetShareMover);
    event ChainStopMessagesFrom(uint32 indexed chainId);
    event ChainStopMessagesTo(uint32 indexed chainId);
    event ChainSetGasLimit(uint32 indexed chainId, uint128 messageGasLimit);

    // ========================================= CONSTRUCTOR =========================================

    /**
     * @notice Constructor for LayerZeroShareMover.
     * @param _owner The owner of this contract (for Auth).
     * @param _authority The authority contract (for Auth).
     * @param _vault The address of the Boring Vault.
     * @param _lzEndpoint The LayerZero endpoint address.
     * @param _delegate The delegate address for OApp.
     */
    constructor(
        address _owner,
        address _authority,
        address _vault,
        address _lzEndpoint,
        address _delegate
    ) 
        ShareMover(_vault)
        OAppAuth(_lzEndpoint, _delegate)
        Auth(_owner, Authority(_authority))
    {
        localDecimals = vault.decimals();
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Add a chain to the ShareMover.
     * @dev Callable by authorized roles.
     * @param chainId The LayerZero endpoint ID to add.
     * @param allowMessagesFrom Whether to allow messages from this chain.
     * @param allowMessagesTo Whether to allow messages to this chain.
     * @param targetShareMover The address of the target ShareMover on the other chain (as bytes32).
     * @param messageGasLimit The gas limit for messages to this chain.
     * @param targetDecimals The decimal places used by shares on the target chain.
     */
    function addChain(
        uint32 chainId,
        bool allowMessagesFrom,
        bool allowMessagesTo,
        bytes32 targetShareMover,
        uint128 messageGasLimit,
        uint8 targetDecimals
    ) external requiresAuth {
        if (chainId == 0) revert LayerZeroShareMover__InvalidChainId();
        if (allowMessagesTo && messageGasLimit == 0) revert LayerZeroShareMover__ZeroMessageGasLimit();
        if (targetDecimals == 0 || targetDecimals > 27) revert LayerZeroShareMover__InvalidTargetDecimals();
        
        chains[chainId] = Chain(allowMessagesFrom, allowMessagesTo, messageGasLimit, targetDecimals);
        _setPeer(chainId, targetShareMover);

        emit ChainAdded(chainId, allowMessagesFrom, allowMessagesTo, targetShareMover, targetDecimals);
    }

    /**
     * @notice Remove a chain from the ShareMover.
     * @dev Callable by authorized roles.
     * @param chainId The LayerZero endpoint ID to remove.
     */
    function removeChain(uint32 chainId) external requiresAuth {
        delete chains[chainId];
        _setPeer(chainId, bytes32(0));

        emit ChainRemoved(chainId);
    }

    /**
     * @notice Allow messages from a chain.
     * @dev Callable by authorized roles.
     * @param chainId The LayerZero endpoint ID.
     * @param targetShareMover The address of the target ShareMover on the other chain (as bytes32).
     */
    function allowMessagesFromChain(uint32 chainId, bytes32 targetShareMover) external requiresAuth {
        Chain storage chain = chains[chainId];
        chain.allowMessagesFrom = true;
        _setPeer(chainId, targetShareMover);

        emit ChainAllowMessagesFrom(chainId, targetShareMover);
    }

    /**
     * @notice Allow messages to a chain.
     * @dev Callable by authorized roles.
     * @param chainId The LayerZero endpoint ID.
     * @param targetShareMover The address of the target ShareMover on the other chain (as bytes32).
     * @param messageGasLimit The gas limit for messages to this chain.
     */
    function allowMessagesToChain(uint32 chainId, bytes32 targetShareMover, uint128 messageGasLimit)
        external
        requiresAuth
    {
        if (messageGasLimit == 0) revert LayerZeroShareMover__ZeroMessageGasLimit();
        
        Chain storage chain = chains[chainId];
        chain.allowMessagesTo = true;
        chain.messageGasLimit = messageGasLimit;
        _setPeer(chainId, targetShareMover);

        emit ChainAllowMessagesTo(chainId, targetShareMover);
    }

    /**
     * @notice Stop messages from a chain.
     * @dev Callable by authorized roles.
     * @param chainId The LayerZero endpoint ID.
     */
    function stopMessagesFromChain(uint32 chainId) external requiresAuth {
        Chain storage chain = chains[chainId];
        chain.allowMessagesFrom = false;

        emit ChainStopMessagesFrom(chainId);
    }

    /**
     * @notice Stop messages to a chain.
     * @dev Callable by authorized roles.
     * @param chainId The LayerZero endpoint ID.
     */
    function stopMessagesToChain(uint32 chainId) external requiresAuth {
        Chain storage chain = chains[chainId];
        chain.allowMessagesTo = false;

        emit ChainStopMessagesTo(chainId);
    }

    /**
     * @notice Set outbound rate limit configurations.
     * @dev Callable by authorized roles.
     * @param _rateLimitConfigs Array of rate limit configurations.
     */
    function setOutboundRateLimits(RateLimitConfig[] calldata _rateLimitConfigs) external requiresAuth {
        _setOutboundRateLimits(_rateLimitConfigs);
    }

    /**
     * @notice Set inbound rate limit configurations.
     * @dev Callable by authorized roles.
     * @param _rateLimitConfigs Array of rate limit configurations.
     */
    function setInboundRateLimits(RateLimitConfig[] calldata _rateLimitConfigs) external requiresAuth {
        _setInboundRateLimits(_rateLimitConfigs);
    }

    /**
     * @notice Set the gas limit for messages to a chain.
     * @dev Callable by authorized roles.
     * @param chainId The LayerZero endpoint ID.
     * @param messageGasLimit The new gas limit.
     */
    function setChainGasLimit(uint32 chainId, uint128 messageGasLimit) external requiresAuth {
        if (messageGasLimit == 0) revert LayerZeroShareMover__ZeroMessageGasLimit();
        
        Chain storage chain = chains[chainId];
        chain.messageGasLimit = messageGasLimit;

        emit ChainSetGasLimit(chainId, messageGasLimit);
    }

    /**
     * @notice Pause the contract.
     * @dev Callable by authorized roles.
     */
    function pause() external requiresAuth {
        _pause();
    }

    /**
     * @notice Unpause the contract.
     * @dev Callable by authorized roles.
     */
    function unpause() external requiresAuth {
        _unpause();
    }

    // ========================================= LAYER ZERO RECEIVE =========================================

    /**
     * @notice Receive messages from the LayerZero endpoint.
     * @dev Implements the OAppAuth receiver interface.
     * @param _origin The origin information containing source endpoint and sender.
     * @param _guid The unique identifier for this message.
     * @param _message The encoded message payload.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address, /*_executor*/
        bytes calldata /*_extraData*/
    ) internal override {
        // Check if paused
        if (paused()) revert EnforcedPause();
        
        // Check if messages are allowed from this chain
        Chain memory sourceChain = chains[_origin.srcEid];
        if (!sourceChain.allowMessagesFrom) revert LayerZeroShareMover__MessagesNotAllowedFrom(_origin.srcEid);
        
        // Decode the message
        MessageLib.Message memory message = MessageLib.decodeMessage(_message);
        
        // Check rate limits
        _checkAndUpdateInboundRateLimit(_origin.srcEid, message.amount);
        
        // Convert amount from source chain decimals to local decimals
        uint8 sourceDecimals = sourceChain.targetDecimals; // Their local decimals = our target decimals
        if (sourceDecimals != localDecimals) {
            message.amount = MessageLib.convertAmountDecimals(message.amount, sourceDecimals, localDecimals);
        }
        
        // Complete the message receive
        _completeMessageReceive(_guid, _origin.srcEid, message);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /**
     * @notice Internal function to send a cross-chain message using LayerZero.
     * @param message The ShareBridgeMessage to send.
     * @param chainId The destination chain endpoint ID.
     * @param bridgeWildCard Bridge-specific data containing fee parameters.
     * @param feeToken The ERC20 token used to pay the bridge fee.
     * @param maxFee The maximum fee to pay for the bridge operation.
     * @return messageId The unique identifier of the sent message.
     */
    function _sendMessage(
        MessageLib.Message memory message,
        uint32 chainId,
        bytes calldata bridgeWildCard,
        ERC20 feeToken,
        uint256 maxFee
    ) internal override returns (bytes32 messageId) {
        // Validate destination chain
        Chain memory destChain = chains[chainId];
        if (!destChain.allowMessagesTo) revert LayerZeroShareMover__MessagesNotAllowedTo(chainId);
        
        // Sanitize recipient address based on destination chain
        // For EVM chains, ensure it's a valid padded EVM address
        // For non-EVM chains (like Solana), any 32-byte value is valid
        if (destChain.targetDecimals == 18 || destChain.targetDecimals == 6) { // Common EVM decimals
            if (!MessageLib.isValidPaddedEvmAddress(message.recipient)) {
                revert ShareMover__InvalidRecipient();
            }
        }
        
        // Convert amount to destination chain decimals
        if (localDecimals != destChain.targetDecimals) {
            message.amount = MessageLib.convertAmountDecimals(message.amount, localDecimals, destChain.targetDecimals);
        }
        
        // Check outbound rate limits
        _checkAndUpdateOutboundRateLimit(chainId, message.amount);
        
        // Encode the message
        bytes memory encodedMessage = MessageLib.encodeMessage(message);
        
        // Build LayerZero options
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(destChain.messageGasLimit, 0);
        
        // Get fee quote
        MessagingFee memory fee = _quote(chainId, encodedMessage, options, address(feeToken) != NATIVE);
        
        // Validate fee
        if (address(feeToken) == NATIVE) {
            if (fee.nativeFee > maxFee) {
                revert LayerZeroShareMover__FeeExceedsMax(chainId, fee.nativeFee, maxFee);
            }
        } else {
            revert LayerZeroShareMover__BadFeeToken(); // Only native fee supported for now
        }
        
        // Send the message
        MessagingReceipt memory receipt = _lzSend(chainId, encodedMessage, options, fee, msg.sender);
        
        messageId = receipt.guid;
    }

    /**
     * @notice Internal function to preview the fee required to bridge shares.
     * @param message The ShareBridgeMessage to send.
     * @param chainId The destination chain endpoint ID.
     * @param bridgeWildCard Bridge-specific data.
     * @param feeToken The ERC20 token to pay the bridge fee in.
     * @return fee The estimated fee required.
     */
    function _previewFee(
        MessageLib.Message memory message,
        uint32 chainId,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) internal view override returns (uint256 fee) {
        // Validate fee token
        if (address(feeToken) != NATIVE) {
            revert LayerZeroShareMover__BadFeeToken(); // Only native fee supported for now
        }
        
        // Validate destination chain
        Chain memory destChain = chains[chainId];
        if (!destChain.allowMessagesTo) revert LayerZeroShareMover__MessagesNotAllowedTo(chainId);
        
        // Create a copy of the message to avoid modifying the original
        MessageLib.Message memory messageCopy = MessageLib.Message({
            recipient: message.recipient,
            amount: message.amount
        });
        
        // Convert amount to destination chain decimals for accurate fee calculation
        if (localDecimals != destChain.targetDecimals) {
            messageCopy.amount = MessageLib.convertAmountDecimals(messageCopy.amount, localDecimals, destChain.targetDecimals);
        }
        
        // Encode the message
        bytes memory encodedMessage = MessageLib.encodeMessage(messageCopy);
        
        // Build LayerZero options
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(destChain.messageGasLimit, 0);
        
        // Get fee quote
        MessagingFee memory messageFee = _quote(chainId, encodedMessage, options, false);
        
        fee = messageFee.nativeFee;
    }
}