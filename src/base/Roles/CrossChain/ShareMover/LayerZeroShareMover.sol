// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ShareMover} from "./ShareMover.sol";
import {MessageLib} from "./MessageLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {OAppAuth, Origin, MessagingFee, MessagingReceipt} from "@oapp-auth/OAppAuth.sol";
import {OptionsBuilder} from "@oapp-auth/OptionsBuilder.sol";
import {PairwiseRateLimiter} from "../PairwiseRateLimiter.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

/**
 * @title LayerZeroShareMover
 * @notice Concrete implementation of ShareMover using LayerZero for cross-chain bridging.
 * @dev Inherits from ShareMover, OAppAuth for LayerZero integration, PairwiseRateLimiter for rate limiting.
 */
contract LayerZeroShareMover is Auth, ShareMover, OAppAuth, PairwiseRateLimiter, IPausable {
    using SafeTransferLib for ERC20;
    using OptionsBuilder for bytes;
    using MessageLib for MessageLib.Message;

    // ========================================= STATE =========================================

    /**
    * @notice Enum to represent different chain types
    */
    enum ChainType {
        EVM,     // Ethereum-compatible chains (20-byte addresses)
        SOLANA   // Solana (32-byte addresses)
    }

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
        ChainType chainType;
    }

    /**
     * @notice Bridge parameters decoded from bridgeWildCard
     * @param chainId The destination LayerZero endpoint ID.
     * @param feeToken The token address to pay fees in (use NATIVE for native token).
     */
    struct BridgeParams {
        uint32 chainId;
        address feeToken;
        uint256 maxFee;
    }

    /**
     * @notice Maps chain endpoint ID to chain information.
     */
    mapping(uint32 => Chain) public chains;

    /**
     * @notice The decimal places used by the vault shares on this chain.
     */
    uint8 public immutable localDecimals;

    /**
     * @notice The LayerZero token address for fee payments.
     */
    address public immutable lzToken;

    // ========================================= PAUSING =========================================

    bool public isPaused;

    error EnforcedPause();

    function _pause() internal {
        isPaused = true;
    }

    function _unpause() internal {
        isPaused = false;
    }

    // ========================================= ERRORS =========================================

    error LayerZeroShareMover__MessagesNotAllowedFrom(uint32 chainId);
    error LayerZeroShareMover__MessagesNotAllowedTo(uint32 chainId);
    error LayerZeroShareMover__FeeExceedsMax(uint32 chainId, uint256 fee, uint256 maxFee);
    error LayerZeroShareMover__BadFeeToken();
    error LayerZeroShareMover__ZeroMessageGasLimit();
    error LayerZeroShareMover__InvalidChainId();
    error LayerZeroShareMover__InvalidTargetDecimals();
    error LayerZeroShareMover__InvalidBridgeParams();
    error LayerZeroShareMover__InvalidRecipientAddressFormat(uint32 chainId, uint256 expectedBytes, uint256 actualBytes);

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
     * @param _owner The owner address for Auth.
     * @param _authority The authority address for Auth.
     * @param _vault The address of the Boring Vault.
     * @param _lzEndpoint The LayerZero endpoint address.
     * @param _delegate The delegate address for OApp.
     * @param _lzToken The LayerZero token address for fee payments.
     */
    constructor(
        address _owner,
        address _authority,
        address _vault,
        address _lzEndpoint,
        address _delegate,
        address _lzToken
    )
        Auth(_owner, Authority(_authority))
        ShareMover(_vault)
        OAppAuth(_lzEndpoint, _delegate)
    {
        localDecimals = vault.decimals();
        lzToken = _lzToken;
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
     * @param chainType The target chain type for address sanitation
     */
    function addChain(
        uint32 chainId,
        bool allowMessagesFrom,
        bool allowMessagesTo,
        bytes32 targetShareMover,
        uint128 messageGasLimit,
        uint8 targetDecimals,
        ChainType chainType  // Add this parameter
    ) external requiresAuth {
        if (chainId == 0) revert LayerZeroShareMover__InvalidChainId();
        if (allowMessagesTo && messageGasLimit == 0) revert LayerZeroShareMover__ZeroMessageGasLimit();
        if (targetDecimals == 0 || targetDecimals > 27) revert LayerZeroShareMover__InvalidTargetDecimals();
        
        chains[chainId] = Chain(allowMessagesFrom, allowMessagesTo, messageGasLimit, targetDecimals, chainType);
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
        if (isPaused) revert EnforcedPause();
        
        // Check if messages are allowed from this chain
        Chain memory sourceChain = chains[_origin.srcEid];
        if (!sourceChain.allowMessagesFrom) revert LayerZeroShareMover__MessagesNotAllowedFrom(_origin.srcEid);
        
        // Decode the message
        MessageLib.Message memory message = MessageLib.decodeMessage(_message);
        
        // Check rate limits using the original amount (before decimal conversion)
        _checkAndUpdateInboundRateLimit(_origin.srcEid, message.amount);
        
        // Complete the message receive
        _completeMessageReceive(_guid, _origin.srcEid, message);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /**
    * @notice Sanitize and validate the recipient address based on destination chain type
    * @param recipient The recipient address as bytes32
    * @param chainId The destination chain ID
    * @return sanitizedRecipient The validated recipient address
    */
    function _sanitizeRecipient(bytes32 recipient, uint32 chainId) internal view returns (bytes32 sanitizedRecipient) {
        Chain memory destChain = chains[chainId];
        
        if (destChain.chainType == ChainType.EVM) {
            // For EVM chains, expect the last 20 bytes to contain the address
            // and the first 12 bytes to be zero
            bytes12 prefix = bytes12(recipient);
            if (prefix != bytes12(0)) {
                revert LayerZeroShareMover__InvalidRecipientAddressFormat(chainId, 20, 32);
            }
            sanitizedRecipient = recipient;
        } else if (destChain.chainType == ChainType.SOLANA) {
            // For Solana, we expect all 32 bytes to be used
            // Check if it's not a zero address
            if (recipient == bytes32(0)) {
                revert LayerZeroShareMover__InvalidRecipientAddressFormat(chainId, 32, 0);
            }
            sanitizedRecipient = recipient;
        } else {
            // Default to accepting the full 32 bytes for unknown chain types
            sanitizedRecipient = recipient;
        }
        
        return sanitizedRecipient;
    }

    /**
     * @notice Internal function to send a cross-chain message using LayerZero.
     * @param message The Message to send.
     * @param chainId The destination chain ID.
     * @param bridgeWildCard Bridge-specific data containing chainId and feeToken.
     * @param feeToken The token address to pay fees in (use NATIVE for native token).
     * @return messageId The unique identifier of the sent message.
     */
    function _sendMessage(
        MessageLib.Message memory message,
        uint32 chainId,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) internal override virtual returns (bytes32 messageId) {
        // Decode bridge parameters from bridgeWildCard (including maxFee)
        BridgeParams memory params = _decodeBridgeParams(bridgeWildCard);
        
        // Sanity check: ensure the supplied chainId and feeToken match the data encoded inside bridgeWildCard
        if (chainId != 0 && chainId != params.chainId) revert LayerZeroShareMover__InvalidChainId();
        if (address(feeToken) != address(0) && address(feeToken) != params.feeToken) revert LayerZeroShareMover__BadFeeToken();

        // Validate destination chain
        Chain memory destChain = chains[params.chainId];
        if (!destChain.allowMessagesTo) revert LayerZeroShareMover__MessagesNotAllowedTo(params.chainId);

        // Sanitize recipient address
        bytes32 sanitizedRecipient = _sanitizeRecipient(message.recipient, params.chainId);
        
        // Check outbound rate limits using original amount (before any decimal conversion)
        _checkAndUpdateOutboundRateLimit(params.chainId, message.amount);
        
        // Create a copy of the message for processing
        MessageLib.Message memory processedMessage = MessageLib.Message({
            recipient: sanitizedRecipient,
            amount: message.amount
        });
        
        // Convert amount to destination chain decimals
        if (localDecimals != destChain.targetDecimals) {
            processedMessage.amount = MessageLib.convertAmountDecimals(
                processedMessage.amount, 
                localDecimals, 
                destChain.targetDecimals
            );
        }
        
        // Encode the message
        bytes memory encodedMessage = MessageLib.encodeMessage(processedMessage);
        
        // Build LayerZero options
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(destChain.messageGasLimit, 0);
        
        // Get fee quote
        MessagingFee memory fee = _quote(params.chainId, encodedMessage, options, params.feeToken != NATIVE);
        
        // Validate fee token and fee amount
        uint256 requiredFee;
        if (params.feeToken == NATIVE) {
            requiredFee = fee.nativeFee;
        } else if (params.feeToken == lzToken) {
            requiredFee = fee.lzTokenFee;
        } else {
            revert LayerZeroShareMover__BadFeeToken();
        }
        
        // Check against maxFee from bridgeWildCard
        if (requiredFee > params.maxFee) {
            revert LayerZeroShareMover__FeeExceedsMax(params.chainId, requiredFee, params.maxFee);
        }
        
        // Collect fee if using ERC20 token
        if (params.feeToken != NATIVE) {
            SafeTransferLib.safeTransferFrom(ERC20(params.feeToken), msg.sender, address(this), requiredFee);
        }
        
        // Send the message
        MessagingReceipt memory receipt = _lzSend(params.chainId, encodedMessage, options, fee, msg.sender);
        
        messageId = receipt.guid;
    }

    /**
     * @notice Internal function to preview the fee required to bridge shares.
     * @param message The Message to send.
     * @param chainId The destination chain ID.
     * @param bridgeWildCard Bridge-specific data containing chainId and feeToken.
     * @param feeToken The token address to pay fees in (use NATIVE for native token).
     * @return fee The estimated fee required.
     */
    function _previewFee(
        MessageLib.Message memory message,
        uint32 chainId,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) internal view override virtual returns (uint256 fee) {
        // Decode bridge parameters from bridgeWildCard
        BridgeParams memory params = _decodeBridgeParams(bridgeWildCard);
        
        // Validate consistency with supplied args & fee token correctness
        if (chainId != 0 && chainId != params.chainId) revert LayerZeroShareMover__InvalidChainId();
        if (address(feeToken) != address(0) && address(feeToken) != params.feeToken) revert LayerZeroShareMover__BadFeeToken();
        if (params.feeToken != NATIVE && params.feeToken != lzToken) revert LayerZeroShareMover__BadFeeToken();

        // Validate destination chain
        Chain memory destChain = chains[params.chainId];
        if (!destChain.allowMessagesTo) revert LayerZeroShareMover__MessagesNotAllowedTo(params.chainId);
        
        // Create a copy of the message to avoid modifying the original
        MessageLib.Message memory messageCopy = MessageLib.Message({
            recipient: message.recipient,
            amount: message.amount
        });
        
        // Convert amount to destination chain decimals for accurate fee calculation
        if (localDecimals != destChain.targetDecimals) {
            messageCopy.amount = MessageLib.convertAmountDecimals(
                messageCopy.amount, 
                localDecimals, 
                destChain.targetDecimals
            );
        }
        
        // Encode the message
        bytes memory encodedMessage = MessageLib.encodeMessage(messageCopy);
        
        // Build LayerZero options
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(destChain.messageGasLimit, 0);
        
        // Get fee quote
        MessagingFee memory messageFee = _quote(params.chainId, encodedMessage, options, params.feeToken != NATIVE);
        
        fee = params.feeToken == NATIVE ? messageFee.nativeFee : messageFee.lzTokenFee;
    }

    /**
     * @notice Decode bridge parameters from bridgeWildCard.
     * @param bridgeWildCard The encoded bridge parameters.
     * @return params The decoded BridgeParams struct.
     */
    function _decodeBridgeParams(bytes calldata bridgeWildCard) internal pure returns (BridgeParams memory params) {
        // Expecting: 4 bytes (uint32) + 32 bytes (address) + 32 bytes (uint256) = 68 bytes
        if (bridgeWildCard.length < 68) {
            revert LayerZeroShareMover__InvalidBridgeParams();
        }
        
        // Decode: abi.encode(uint32 chainId, address feeToken, uint256 maxFee)
        (params.chainId, params.feeToken, params.maxFee) = abi.decode(
            bridgeWildCard, 
            (uint32, address, uint256)
        );
        
        if (params.chainId == 0) revert LayerZeroShareMover__InvalidChainId();
    }

    // ========================================= USER-FACING OVERRIDES WITH PAUSE GUARD =========================================

    /// @notice See {ShareMover-bridge}
    function bridge(
        uint96 shareAmount,
        uint32 chainId,
        bytes32 to,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) public payable override {
        if (isPaused) revert EnforcedPause();
        super.bridge(shareAmount, chainId, to, bridgeWildCard, feeToken);
    }

    /// @notice See {ShareMover-bridgeWithPermit}
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
    ) public payable override {
        if (isPaused) revert EnforcedPause();
        super.bridgeWithPermit(shareAmount, chainId, to, bridgeWildCard, deadline, v, r, s, feeToken);
    }

    /// @notice See {ShareMover-previewFee}
    function previewFee(
        uint96 shareAmount,
        uint32 chainId,
        bytes32 to,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) public view override returns (uint256 fee) {
        if (isPaused) revert EnforcedPause();
        return super.previewFee(shareAmount, chainId, to, bridgeWildCard, feeToken);
    }
}