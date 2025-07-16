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

contract LayerZeroShareMover is Auth, ShareMover, OAppAuth, PairwiseRateLimiter, IPausable {
    using SafeTransferLib for ERC20;
    using OptionsBuilder for bytes;
    using MessageLib for MessageLib.Message;

    // ========================================= STRUCTS =========================================

    /**
    * @notice Enum to represent different chain types
    */
    enum ChainType {
        EVM,      // Ethereum-compatible chains (20-byte addresses)
        SOLANA,   // Solana (32-byte addresses)
        SUI       // Sui (32-byte addresses
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

    // ========================================= STATE =========================================

    /**
     * @notice Maps chain endpoint ID to chain information.
     */
    mapping(uint32 => Chain) public chains;

    /**
     * @notice Whether the contract is paused.
     */
    bool public isPaused;

    // ========================================= IMMUTABLES =========================================

    /**
     * @notice The decimal places used by the vault shares on this chain.
     */
    uint8 public immutable localDecimals;

    /**
     * @notice The LayerZero token address for fee payments.
     */
    address public immutable lzToken;

    // ========================================= ERRORS =========================================

    error LayerZeroShareMover__MessagesNotAllowedFrom(uint32 chainId);
    error LayerZeroShareMover__MessagesNotAllowedTo(uint32 chainId);
    error LayerZeroShareMover__FeeExceedsMax(uint32 chainId, uint256 fee, uint256 maxFee);
    error LayerZeroShareMover__BadFeeToken();
    error LayerZeroShareMover_IsPaused();
    error LayerZeroShareMover__ZeroMessageGasLimit();
    error LayerZeroShareMover__InvalidChainId();
    error LayerZeroShareMover__InvalidTargetDecimals();
    error LayerZeroShareMover__InvalidBridgeParams();
    error LayerZeroShareMover__InvalidRecipientAddressFormat(uint32 chainId, uint256 expectedBytes, uint256 actualBytes);
    error LayerZeroShareMover__AmountOverflow();

    // ========================================= EVENTS =========================================

    event ChainAdded(uint32 indexed chainId, bool allowMessagesFrom, bool allowMessagesTo, bytes32 targetShareMover, uint8 targetDecimals);
    event ChainRemoved(uint32 indexed chainId);
    event ChainAllowMessagesFrom(uint32 indexed chainId, bytes32 targetShareMover);
    event ChainAllowMessagesTo(uint32 indexed chainId, bytes32 targetShareMover);
    event ChainStopMessagesFrom(uint32 indexed chainId);
    event ChainStopMessagesTo(uint32 indexed chainId);
    event ChainSetGasLimit(uint32 indexed chainId, uint128 messageGasLimit);

    // Simple pause/unpause events (local to this contract)
    event Paused();
    event Unpaused();

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
     * @notice Pause the contract.
     * @dev Callable by authorized roles.
     */
    function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause the contract.
     * @dev Callable by authorized roles.
     */
    function unpause() external requiresAuth {
        isPaused = false;
        emit Unpaused();
    }

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
        ChainType chainType
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

    // ========================================= OAppAuthReceiver =========================================

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
        if (isPaused) revert LayerZeroShareMover_IsPaused();
        
        Chain memory sourceChain = chains[_origin.srcEid];
        if (!sourceChain.allowMessagesFrom) revert LayerZeroShareMover__MessagesNotAllowedFrom(_origin.srcEid);
        
        MessageLib.Message memory message = MessageLib.decodeMessage(_message);
        
        _checkAndUpdateInboundRateLimit(_origin.srcEid, message.amount);

        if (message.amount > type(uint96).max) revert LayerZeroShareMover__AmountOverflow();

        _completeMessageReceive(_guid, _origin.srcEid, uint96(message.amount), message.recipient);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /**
     * @notice Validates and converts the recipient address for the target chain.
     * @dev
     *  EVM chains expect a 20-byte address left-padded to 32 bytes.
     *  Solana chains expect the full 32-byte value to be forwarded untouched.
     *  Reverts with LayerZeroShareMover__InvalidRecipientAddressFormat when the supplied
     *  address does not meet the target chain's format requirements.
     * @param recipient The raw 32-byte recipient value supplied by the caller.
     * @param chainId   The LayerZero endpoint id of the destination chain.
     * @return sanitizedRecipient A properly formatted 32-byte recipient ready for encoding in the cross-chain message.
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
        } else {
            // For Solana and Sui, we expect all 32 bytes to be used
            if (recipient == bytes32(0)) {
                revert LayerZeroShareMover__InvalidRecipientAddressFormat(chainId, 32, 0);
            }
            sanitizedRecipient = recipient;
        }
        
        return sanitizedRecipient;
    }

    /**
     * @notice Internal function to send a cross-chain message using LayerZero.
     * @dev Conforms to the new ShareMover interface.
     * @param shareAmount   Amount of shares to bridge on the source chain.
     * @param to            32-byte recipient on the destination chain.
     * @param bridgeWildCard Opaque data blob containing the encoded BridgeParams:
     *                       abi.encode(uint32 chainId, address feeToken, uint256 maxFee).
     * @return messageId    The GUID assigned by LayerZero for this message.
     * @return chainId      Destination LayerZero endpoint id extracted from bridgeWildCard.
     */
    function _sendMessage(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) internal virtual override returns (bytes32 messageId, uint32 chainId) {
        BridgeParams memory params = _decodeBridgeParams(bridgeWildCard);
        chainId = params.chainId;

        if (params.feeToken != NATIVE && params.feeToken != lzToken) {
            revert LayerZeroShareMover__BadFeeToken();
        }

        Chain memory destChain = chains[chainId];
        if (!destChain.allowMessagesTo) revert LayerZeroShareMover__MessagesNotAllowedTo(chainId);

        _checkAndUpdateOutboundRateLimit(chainId, uint128(shareAmount));

        bytes32 sanitizedRecipient = _sanitizeRecipient(to, chainId);

        uint128 bridgedAmount = uint128(shareAmount);
        if (localDecimals != destChain.targetDecimals) {
            bridgedAmount = MessageLib.convertAmountDecimals(
                bridgedAmount,
                localDecimals,
                destChain.targetDecimals
            );
        }

        MessageLib.Message memory msgStruct = MessageLib.Message({
            recipient: sanitizedRecipient,
            amount: bridgedAmount
        });

        bytes memory encodedMessage = MessageLib.encodeMessage(msgStruct);

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(destChain.messageGasLimit, 0);

        MessagingFee memory fee = _quote(chainId, encodedMessage, options, params.feeToken != NATIVE);

        if (params.feeToken == NATIVE) {
            if (fee.nativeFee > params.maxFee) {
                revert LayerZeroShareMover__FeeExceedsMax(chainId, fee.nativeFee, params.maxFee);
            }
        } else {
            // lzToken path
            if (fee.lzTokenFee > params.maxFee) {
                revert LayerZeroShareMover__FeeExceedsMax(chainId, fee.lzTokenFee, params.maxFee);
            }
        }

        MessagingReceipt memory receipt = _lzSend(chainId, encodedMessage, options, fee, msg.sender);
        messageId = receipt.guid;
    }

    /**
     * @notice Preview the fee required to bridge shares using the data encoded in bridgeWildCard.
     */
    function _previewFee(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) internal view virtual override returns (uint256 fee) {
        BridgeParams memory params = _decodeBridgeParams(bridgeWildCard);

        if (params.feeToken != NATIVE && params.feeToken != lzToken) revert LayerZeroShareMover__BadFeeToken();

        Chain memory destChain = chains[params.chainId];
        if (!destChain.allowMessagesTo) revert LayerZeroShareMover__MessagesNotAllowedTo(params.chainId);

        uint128 amountOut = uint128(shareAmount);
        if (localDecimals != destChain.targetDecimals) {
            amountOut = MessageLib.convertAmountDecimals(amountOut, localDecimals, destChain.targetDecimals);
        }

        bytes32 sanitizedRecipient = _sanitizeRecipient(to, params.chainId);
        MessageLib.Message memory msgStruct = MessageLib.Message({recipient: sanitizedRecipient, amount: amountOut});

        bytes memory encodedMessage = MessageLib.encodeMessage(msgStruct);
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(destChain.messageGasLimit, 0);

        MessagingFee memory quote = _quote(params.chainId, encodedMessage, options, params.feeToken != NATIVE);
        fee = params.feeToken == NATIVE ? quote.nativeFee : quote.lzTokenFee;
    }

    /**
     * @notice Decodes the wildcard bytes passed to {bridge} / {previewFee} into strongly-typed parameters.
     * @dev Expected encoding is `abi.encode(uint32 chainId, address feeToken, uint256 maxFee)`.
     *      Reverts with LayerZeroShareMover__InvalidBridgeParams if the byte array is shorter than 68 bytes.
     *      Reverts with LayerZeroShareMover__InvalidChainId if the decoded chainId == 0.
     * @param bridgeWildCard The opaque bytes blob supplied by the caller.
     * @return params The decoded {BridgeParams} struct.
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
        bytes32 to,
        bytes calldata bridgeWildCard
    ) public payable override {
        if (isPaused) revert LayerZeroShareMover_IsPaused();
        super.bridge(shareAmount, to, bridgeWildCard);
    }

    /// @notice See {ShareMover-bridgeWithPermit}
    function bridgeWithPermit(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable override {
        if (isPaused) revert LayerZeroShareMover_IsPaused();
        super.bridgeWithPermit(shareAmount, to, bridgeWildCard, deadline, v, r, s);
    }

    /// @notice See {ShareMover-previewFee}
    function previewFee(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) public view override returns (uint256 fee) {
        if (isPaused) revert LayerZeroShareMover_IsPaused();
        return super.previewFee(shareAmount, to, bridgeWildCard);
    }
}