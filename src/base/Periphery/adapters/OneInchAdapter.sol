// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {BaseAdapter} from "src/base/Periphery/adapters/BaseAdapter.sol";
import {IUniswapV3} from "src/interfaces/IUniswapV3.sol";
import {ICurvePool} from "src/interfaces/ICurvePool.sol";

interface IOneInchOrderMixin {
    function bitInvalidatorForOrder(address maker, uint256 slot) external view returns (uint256);
}
contract OneInchAdapter is IAdapter, BaseAdapter {

    //============================== Errors ===============================

    error OneInchAdapter__ExecutorMismatch();
    error OneInchAdapter__SrcReceiverMismatch();
    error OneInchAdapter__DstReceiverNotSwapper();
    error OneInchAdapter__SrcTokenMismatch();
    error OneInchAdapter__DstTokenMismatch();
    error OneInchAdapter__TokenInMismatch();
    error OneInchAdapter__TokenOutMismatch();
    error OneInchAdapter__ToNotSwapper();
    error OneInchAdapter__TakerAssetMismatch();
    error OneInchAdapter__MakerAssetMismatch();
    error OneInchAdapter__ReceiverNotSwapper();
    error OneInchAdapter__CustomTargetNotAllowed();
    error OneInchAdapter__MakerNotSwapper();
    error OneInchAdapter__UnknownFeeTaker();
    error OneInchAdapter__ExtensionReceiverMismatch();
    error OneInchAdapter__ReceiverMismatch();
    error OneInchAdapter__ExtensionTooShort();
    error OneInchAdapter__PostInteractionTooShort();
    error OneInchAdapter__NoCustomReceiver();
    error OneInchAdapter__CustomReceiverOutOfBounds();
    error OneInchAdapter__UnsupportedProtocol();
    error OneInchAdapter__PartialFillsNotAllowed();
    error OneInchAdapter__EpochManagerNotAllowed();

    address public immutable router;
    address public immutable feeTaker;
    address public immutable trustedExecutor;

    bytes32 constant ONEINCH_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"
    );

    bytes32 immutable DOMAIN_SEPARATOR;

    // If set in takerTraits, makerAsset is sent to a custom address instead of msg.sender
    uint256 private constant _ARGS_HAS_TARGET = 1 << 251;

    // makerTraits flags. NO_PARTIAL_FILLS_FLAG forces single-shot orders, which routes invalidation
    // through BitInvalidator and guarantees `isValidSignature` is called on the fill. Without it,
    // 1inch only validates the signature on the *first* fill — local revocation can't stop
    // subsequent fills. NEED_CHECK_EPOCH_MANAGER_FLAG is incompatible with BitInvalidator (the protocol
    // reverts `EpochManagerAndBitInvalidatorsAreIncompatible` at fill time); reject early.
    uint256 private constant _NO_PARTIAL_FILLS_FLAG = 1 << 255;
    uint256 private constant _NEED_CHECK_EPOCH_MANAGER_FLAG = 1 << 250;

    // nonceOrEpoch is packed at bits [120, 160) of makerTraits as a uint40.
    uint256 private constant _NONCE_OR_EPOCH_OFFSET = 120;
    uint256 private constant _NONCE_OR_EPOCH_MASK = type(uint40).max;

    //General Offsets
    uint256 private constant PROTOCOL_OFFSET = 253;

    //Curve Offsets
    uint256 private constant CURVE_TO_COINS_ARG_OFFSET = 216;
    uint256 private constant CURVE_TO_COINS_ARG_MASK = 0xff;

    constructor(address _router, address _feeTaker, address _executor) {
        router = _router;
        feeTaker = _feeTaker;
        trustedExecutor = _executor;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("1inch Aggregation Router"),
                keccak256("6"),
                block.chainid,
                _router
            )
        );
    }

    //============================== V6 swap ===============================

    function swap(
        address executor,
        DecoderCustomTypes.SwapDescription memory desc,
        bytes memory /*data*/
    )
        external
        view
        returns (address, uint256)
    {
        if (executor != trustedExecutor) revert OneInchAdapter__ExecutorMismatch();
        if (desc.srcReceiver != payable(trustedExecutor)) revert OneInchAdapter__SrcReceiverMismatch();
        if (desc.dstReceiver != payable(msg.sender)) revert OneInchAdapter__DstReceiverNotSwapper();

        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__SrcTokenMismatch();
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__DstTokenMismatch();

        return (router, desc.amount);
    }

    //============================== V6 unoswap ===============================

    function unoswap(
        uint256 token,
        uint256 amount,
        uint256,
        /*minReturn*/
        uint256 dex
    )
        external
        view
        returns (address, uint256)
    {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__TokenInMismatch();

        address tokenOut = _unoswapCheck(dex, token);

        if (ERC20(tokenOut) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__TokenOutMismatch();
        return (router, amount);
    }

    function unoswap2(
        uint256 token,
        uint256 amount,
        uint256,
        /*minReturn*/
        uint256 dex,
        uint256 dex2
    )
        external
        view
        returns (address, uint256)
    {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__TokenInMismatch();

        address tokenOutDex2 = _unoswap2Check(dex, dex2, token);

        if (ERC20(tokenOutDex2) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__TokenOutMismatch();
        return (router, amount);
    }

    function unoswap3(
        uint256 token,
        uint256 amount,
        uint256,
        /*minReturn*/
        uint256 dex,
        uint256 dex2,
        uint256 dex3
    )
        external
        view
        returns (address, uint256)
    {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__TokenInMismatch();

        address tokenOutDex3 = _unoswap3Check(dex, dex2, dex3, token);

        if (ERC20(tokenOutDex3) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__TokenOutMismatch();
        return (router, amount);
    }

    function unoswapTo(
        uint256 to,
        uint256 token,
        uint256 amount,
        uint256,
        /*minReturn*/
        uint256 dex
    )
        external
        view
        returns (address, uint256)
    {
        if (address(uint160(to)) != msg.sender) revert OneInchAdapter__ToNotSwapper();
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__TokenInMismatch();

        address tokenOut = _unoswapCheck(dex, token);
        if (ERC20(tokenOut) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__TokenOutMismatch();

        return (router, amount);
    }

    function unoswapTo2(
        uint256 to,
        uint256 token,
        uint256 amount,
        uint256,
        /*minReturn*/
        uint256 dex,
        uint256 dex2
    )
        external
        view
        returns (address, uint256)
    {
        if (address(uint160(to)) != msg.sender) revert OneInchAdapter__ToNotSwapper();
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__TokenInMismatch();

        address tokenOutDex2 = _unoswap2Check(dex, dex2, token);
        if (ERC20(tokenOutDex2) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__TokenOutMismatch();

        return (router, amount);
    }

    function unoswapTo3(
        uint256 to,
        uint256 token,
        uint256 amount,
        uint256,
        /*minReturn*/
        uint256 dex,
        uint256 dex2,
        uint256 dex3
    ) external view returns (address, uint256) {
        if (address(uint160(to)) != msg.sender) revert OneInchAdapter__ToNotSwapper();
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__TokenInMismatch();

        address tokenOutDex3 = _unoswap3Check(dex, dex2, dex3, token);
        if (ERC20(tokenOutDex3) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__TokenOutMismatch();

        return (router, amount);
    }

    function fillOrder(
        DecoderCustomTypes.OneInchV6Order calldata order,
        bytes32 /*r*/,
        bytes32 /*vs*/,
        uint256 amount,
        uint256 takerTraits
    )
        external
        view
        returns (address, uint256)
    {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(order.takerAsset))) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__TakerAssetMismatch();
        if (ERC20(address(uint160(order.makerAsset))) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__MakerAssetMismatch();
        // _ARGS_HAS_TARGET (bit 251): if set, makerAsset is redirected to a custom address
        // instead of msg.sender (the swapper). Reject to ensure output always lands at the
        // swapper for slippage verification before forwarding to the vault.
        if (takerTraits & _ARGS_HAS_TARGET != 0) revert OneInchAdapter__CustomTargetNotAllowed();

        return (router, amount);
    }

    //============================== Limit Orders ===============================

    /// @notice swapData encoding: abi.encode(OneInchLimitOrder order, bytes extension)
    /// The extension contains the FeeTaker postInteraction data where the custom receiver (vault) is embedded.
    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address swapper)
        external
        view
        returns (OrderInfo memory)
    {
        (DecoderCustomTypes.OneInchLimitOrder memory order, bytes memory extension) =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.OneInchLimitOrder, bytes));

        if (ERC20(order.makerAsset) != swapConfig.tokenRoute.tokenIn) revert OneInchAdapter__MakerAssetMismatch();
        if (ERC20(order.takerAsset) != swapConfig.tokenRoute.tokenOut) revert OneInchAdapter__TakerAssetMismatch();
        if (order.maker != swapper) revert OneInchAdapter__MakerNotSwapper();
        if (order.makerTraits & _NO_PARTIAL_FILLS_FLAG == 0) revert OneInchAdapter__PartialFillsNotAllowed();
        if (order.makerTraits & _NEED_CHECK_EPOCH_MANAGER_FLAG != 0) revert OneInchAdapter__EpochManagerNotAllowed();

        //for orders with a fee extension, the order.receiver is the fee taker contract.
        //the actual receiver (vault) is embedded in the extension's postInteraction data.
        if (extension.length > 0) {
            if (order.receiver != feeTaker) revert OneInchAdapter__UnknownFeeTaker();
            address customReceiver = _extractCustomReceiver(extension);
            if (customReceiver != address(swapConfig.receiver)) revert OneInchAdapter__ExtensionReceiverMismatch();
        } else {
            if (order.receiver != address(swapConfig.receiver)) revert OneInchAdapter__ReceiverMismatch();
        }

        bytes memory orderData = abi.encode(order);
        bytes32 orderHash = _computeOrderHash(orderData);

        return OrderInfo({
            approvalTarget: router,
            cancelTarget: router,
            inputToken: order.makerAsset,
            outputToken: order.takerAsset,
            inputAmount: order.makingAmount,
            outputAmount: order.takingAmount,
            protocolHash: orderHash
        });
    }

    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address)
        external
        view
        returns (address, bytes memory)
    {
        (DecoderCustomTypes.OneInchLimitOrder memory order,) =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.OneInchLimitOrder, bytes));
        bytes memory orderData = abi.encode(order);
        bytes32 orderHash = _computeOrderHash(orderData);
        return (router, abi.encodeWithSignature("cancelOrder(uint256,bytes32)", order.makerTraits, orderHash));
    }

    /// @dev The same bit is set on cancel too, but the swapper only cancels from inside `_cancelOrder`
    ///      and queries `isFilled` BEFORE that call — so a set bit at this site means the protocol
    ///      filled the order. `verifyLimitOrder` enforces `NO_PARTIAL_FILLS_FLAG` so all orders route
    ///      through BitInvalidator; a partially-fillable order would use RemainingInvalidator and this
    ///      check would return false on a real fill (RemainingInvalidator records the remaining
    ///      amount instead of flipping the bit we read).
    function isFilled(ISwapperTypes.SwapConfig calldata swapConfig, address swapper)
        external
        view
        returns (bool)
    {
        (DecoderCustomTypes.OneInchLimitOrder memory order,) =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.OneInchLimitOrder, bytes));
        uint256 nonceOrEpoch = (order.makerTraits >> _NONCE_OR_EPOCH_OFFSET) & _NONCE_OR_EPOCH_MASK;
        uint256 slot = nonceOrEpoch >> 8;
        uint256 bit = 1 << (nonceOrEpoch & 0xff);
        return IOneInchOrderMixin(router).bitInvalidatorForOrder(swapper, slot) & bit != 0;
    }

    function version() external view returns (uint256) {
        return 1;
    }

    //============================== Internal ===============================

    function _computeOrderHash(bytes memory orderData) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, orderData));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function _protocol(uint256 dex) internal pure returns (uint8) {
        // there is no need to mask because protocol is stored in the highest 3 bits
        return uint8(dex >> PROTOCOL_OFFSET);
    }

    /// @notice Extracts the custom receiver address from a 1inch FeeTaker extension.
    /// Extension layout:
    ///   [32 bytes] header — 8 packed uint32 offsets
    ///   [variable] data   — concatenated fields
    /// PostInteraction layout (within data):
    ///   [20 bytes] fee taker address
    ///   [ 1 byte ] flags (bit 0 = CUSTOM_RECEIVER_FLAG)
    ///   [20 bytes] integrator fee recipient
    ///   [20 bytes] protocol fee recipient
    ///   [20 bytes] custom receiver (only if flags & 1)
    function _extractCustomReceiver(bytes memory extension) internal pure returns (address) {
        if (extension.length < 32) revert OneInchAdapter__ExtensionTooShort();

        // Header offset[1] (bytes 4-7) = postInteraction start in data
        uint32 postInteractionStart;
        assembly {
            postInteractionStart := shr(224, mload(add(extension, 36))) // bytes 4-7 of header
        }

        // postInteraction is at: 32 (header) + postInteractionStart
        uint256 piOffset = 32 + uint256(postInteractionStart);
        if (extension.length < piOffset + 62) revert OneInchAdapter__PostInteractionTooShort();

        // Read flags byte at postInteraction + 20 (after fee taker address)
        uint8 flags;
        assembly {
            flags := byte(0, mload(add(add(extension, 32), add(piOffset, 20))))
        }

        if (flags & 1 != 1) revert OneInchAdapter__NoCustomReceiver();
        if (extension.length < piOffset + 81) revert OneInchAdapter__CustomReceiverOutOfBounds();

        // Custom receiver is at postInteraction + 61 (after: 20 addr + 1 flags + 20 integrator + 20 protocol)
        address customReceiver;
        assembly {
            customReceiver := shr(96, mload(add(add(extension, 32), add(piOffset, 61))))
        }

        return customReceiver;
    }

    function _getTokenOut(uint256 dex, address tokenIn) internal view returns (address) {
        uint8 protocol = _protocol(dex);
        if (protocol == 0 || protocol == 1) return _getTokenOutUni(dex, tokenIn);
        if (protocol == 2) return _getTokenOutCurve(dex);
        revert OneInchAdapter__UnsupportedProtocol();
    }

    function _unoswapCheck(uint256 dex, uint256 token) internal view returns (address) {
        return _getTokenOut(dex, address(uint160(token)));
    }

    function _unoswap2Check(uint256 dex, uint256 dex2, uint256 token) internal view returns (address) {
        address tokenOutDex = _getTokenOut(dex, address(uint160(token)));
        return _getTokenOut(dex2, tokenOutDex);
    }

    function _unoswap3Check(uint256 dex, uint256 dex2, uint256 dex3, uint256 token) internal view returns (address) {
        address tokenOutDex = _getTokenOut(dex, address(uint160(token)));
        address tokenOutDex2 = _getTokenOut(dex2, tokenOutDex);
        return _getTokenOut(dex3, tokenOutDex2);
    }

    function _getTokenOutUni(uint256 dex, address tokenIn) internal view returns (address) {
        address pool = address(uint160(dex));
        return IUniswapV3(pool).token0() == tokenIn ? IUniswapV3(pool).token1() : IUniswapV3(pool).token0();
    }

    function _getTokenOutCurve(uint256 dex) internal view returns (address) {
        //extract the pool address
        address pool = address(uint160(dex));
        uint256 toTokenIndex = (dex >> CURVE_TO_COINS_ARG_OFFSET) & CURVE_TO_COINS_ARG_MASK;
        return ICurvePool(pool).coins(toTokenIndex);
    }
}
