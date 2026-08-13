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
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV3Factory} from "src/interfaces/IUniswapV3Factory.sol";
import {IOneInchOrderMixin} from "src/interfaces/IOneInchOrderMixin.sol";
import {ICurveMetaRegistry} from "src/interfaces/ICurveMetaRegistry.sol";

contract OneInchAdapterNoLimitOrdersNoExecutor is IAdapter, BaseAdapter {

    //============================== Errors ===============================

    error OneInchAdapter__ExecutorMismatch();
    error OneInchAdapter__SrcReceiverMismatch();
    error OneInchAdapter__DstReceiverNotSwapper();
    error OneInchAdapter__CustomTargetNotAllowed();
    error OneInchAdapter__UnsupportedProtocol();
    error OneInchAdapter__InvalidPool();
    error OneInchAdapter__WethUnwrapNotAllowed();
    error OneInchAdapter__MakerAmountFlagNotAllowed();

    //============================== Immutables ===============================
    
    address public immutable router;
    address public immutable feeTaker;
    /// @notice 1inch protocol/resolver fee receiver (from getFeeParams). Pinned so a strategist cannot
    ///         redirect the fee to themselves. Immutable — redeploy if 1inch ever changes it.
    address public immutable protocolFeeReceiver;
    address public immutable univ2Factory;
    address public immutable univ3Factory;
    address public immutable curveMetaRegistry;
    bytes32 public immutable domainSeparator;

    //============================== Constants ===============================
    
    bytes32 constant ONEINCH_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"
    );
    // If set in takerTraits, makerAsset is sent to a custom address instead of msg.sender
    uint256 private constant _ARGS_HAS_TARGET = 1 << 251;
    uint256 private constant _NEED_CHECK_EPOCH_MANAGER_FLAG = 1 << 250;
    // makerTraits bit 249: order carries an extension.
    uint256 private constant _HAS_EXTENSION_FLAG = 1 << 249;
    // makerTraits bit 251: router calls postInteraction at fill (FeeTaker forwards output to the vault).
    uint256 private constant _POST_INTERACTION_CALL_FLAG = 1 << 251;
    // makerTraits bit 255: order forbids partial fills (fill-or-kill). Selects the BitInvalidator.
    uint256 private constant _NO_PARTIAL_FILLS_FLAG = 1 << 255;
    // makerTraits bit 254: order may be filled multiple times. With partial fills, selects the RemainingInvalidator.
    uint256 private constant _ALLOW_MULTIPLE_FILLS_FLAG = 1 << 254;
    // takerTraits bit 254: router unwraps WETH to ETH before delivering maker asset. Blocked — swapper is ERC20-only.
    uint256 private constant _TAKER_UNWRAP_WETH = 1 << 254;
    // takerTraits bit 255: amount denominates makerAsset output (exact-output). Blocked — swapper assumes amount is takerAsset input.
    uint256 private constant _MAKER_AMOUNT_FLAG = 1 << 255;
    // unoswap dex bit 252: router unwraps WETH to ETH before delivering output. Blocked — swapper is ERC20-only.
    uint256 private constant _DEX_WETH_UNWRAP_FLAG = 1 << 252;
    // nonceOrEpoch is packed at bits [120, 160) of makerTraits as a uint40.
    uint256 private constant _NONCE_OR_EPOCH_OFFSET = 120;
    uint256 private constant _NONCE_OR_EPOCH_MASK = type(uint40).max;
    //General Offsets
    uint256 private constant PROTOCOL_OFFSET = 253;
    uint256 private constant UNISWAP_V3_ZERO_FOR_ONE_OFFSET = 247;
    //Curve Offsets
    uint256 private constant CURVE_TO_COINS_ARG_OFFSET = 216;
    uint256 private constant CURVE_FROM_COINS_ARG_OFFSET = 200;
    uint256 private constant CURVE_TO_COINS_ARG_MASK = 0xff;

    //============================== Constructor ===============================
    
    constructor(
        address _router,
        address _feeTaker,
        address _protocolFeeReceiver,
        address _univ2Factory,
        address _univ3Factory,
        address _curveMetaRegistry
    ) {
        router = _router;
        feeTaker = _feeTaker;
        protocolFeeReceiver = _protocolFeeReceiver;
        univ2Factory = _univ2Factory;
        univ3Factory = _univ3Factory;
        curveMetaRegistry = _curveMetaRegistry;
        domainSeparator = keccak256(
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
        address, /*executor*/
        DecoderCustomTypes.SwapDescription memory desc,
        bytes memory /*data*/
    )
        external
        view
        returns (address, uint256)
    {
        if (desc.dstReceiver != payable(msg.sender)) revert OneInchAdapter__DstReceiverNotSwapper();

        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, desc.amount);
    }

    //============================== V6 unoswap ===============================

    function unoswap(
        uint256 token,
        uint256 amount,
        uint256 /*minReturn*/,
        uint256 dex
    )
        external
        view
        returns (address, uint256)
    {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address tokenOut = _unoswapCheck(dex, token);

        if (ERC20(tokenOut) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();
        return (router, amount);
    }

    function unoswap2(
        uint256 token,
        uint256 amount,
        uint256 /*minReturn*/,
        uint256 dex,
        uint256 dex2
    )
        external
        view
        returns (address, uint256)
    {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address tokenOutDex2 = _unoswap2Check(dex, dex2, token);

        if (ERC20(tokenOutDex2) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();
        return (router, amount);
    }

    function unoswap3(
        uint256 token,
        uint256 amount,
        uint256 /*minReturn*/,
        uint256 dex,
        uint256 dex2,
        uint256 dex3
    )
        external
        view
        returns (address, uint256)
    {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address tokenOutDex3 = _unoswap3Check(dex, dex2, dex3, token);

        if (ERC20(tokenOutDex3) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();
        return (router, amount);
    }

    function unoswapTo(
        uint256 to,
        uint256 token,
        uint256 amount,
        uint256 /*minReturn*/,
        uint256 dex
    )
        external
        view
        returns (address, uint256)
    {
        if (address(uint160(to)) != msg.sender) revert Adapter__ReceiverMismatch();
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address tokenOut = _unoswapCheck(dex, token);
        if (ERC20(tokenOut) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, amount);
    }

    function unoswapTo2(
        uint256 to,
        uint256 token,
        uint256 amount,
        uint256 /*minReturn*/,
        uint256 dex,
        uint256 dex2
    )
        external
        view
        returns (address, uint256)
    {
        if (address(uint160(to)) != msg.sender) revert Adapter__ReceiverMismatch();
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address tokenOutDex2 = _unoswap2Check(dex, dex2, token);
        if (ERC20(tokenOutDex2) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, amount);
    }

    function unoswapTo3(
        uint256 to,
        uint256 token,
        uint256 amount,
        uint256 /*minReturn*/,
        uint256 dex,
        uint256 dex2,
        uint256 dex3
    ) external view returns (address, uint256) {
        if (address(uint160(to)) != msg.sender) revert Adapter__ReceiverMismatch();
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address tokenOutDex3 = _unoswap3Check(dex, dex2, dex3, token);
        if (ERC20(tokenOutDex3) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

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
        if (ERC20(address(uint160(order.takerAsset))) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();
        if (ERC20(address(uint160(order.makerAsset))) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();
        // _ARGS_HAS_TARGET (bit 251): if set, makerAsset is redirected to a custom address
        // instead of msg.sender (the swapper). Reject to ensure output always lands at the
        // swapper for slippage verification before forwarding to the vault.
        if (takerTraits & _ARGS_HAS_TARGET != 0) revert OneInchAdapter__CustomTargetNotAllowed();
        if (takerTraits & _TAKER_UNWRAP_WETH != 0) revert OneInchAdapter__WethUnwrapNotAllowed();
        if (takerTraits & _MAKER_AMOUNT_FLAG != 0) revert OneInchAdapter__MakerAmountFlagNotAllowed();

        return (router, amount);
    }

    //============================== Limit Orders ===============================

    /// @notice swapData encoding: abi.encode(OneInchLimitOrder order, bytes extension)
    /// The extension contains the FeeTaker postInteraction data where the custom receiver (vault) is embedded.
    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata /*swapConfig*/, address /*swapper*/)
        external
        view
        returns (OrderInfo memory)
    {
        revert Adapter__LimitOrdersNotSupported();
    }

    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata /*swapConfig*/, address /*swapper*/, bytes calldata /*cancelData*/, bytes calldata /*context*/)
        external
        view
        returns (address, bytes memory)
    {
        revert Adapter__LimitOrdersNotSupported();
    }

    /// @dev Reads on-chain fill state from whichever invalidator 1inch uses for this order's flags.
    ///      verifyLimitOrder restricts orders to two shapes: fill-or-kill (BitInvalidator) and
    ///      partial+multiple (RemainingInvalidator).
    function filledAmount(ISwapperTypes.SwapConfig calldata /*swapConfig*/, address /*swapper*/, bytes calldata /*context*/)
        external
        view
        returns (uint256)
    {
        revert Adapter__LimitOrdersNotSupported();
    }

    function version() external pure returns (string memory) {
        return "v1";
    }

    //============================== Internal ===============================

    function _computeOrderHash(bytes memory orderData) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, orderData));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _protocol(uint256 dex) internal pure returns (uint8) {
        // there is no need to mask because protocol is stored in the highest 3 bits
        return uint8(dex >> PROTOCOL_OFFSET);
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

    function _getTokenOut(uint256 dex, address tokenIn) internal view returns (address) {
        if (dex & _DEX_WETH_UNWRAP_FLAG != 0) revert OneInchAdapter__WethUnwrapNotAllowed();
        uint8 protocol = _protocol(dex);
        if (protocol == 0) return _getTokenOutUniV2(dex, tokenIn);
        if (protocol == 1) return _getTokenOutUniV3(dex, tokenIn);
        if (protocol == 2) return _getTokenOutCurve(dex, tokenIn);
        revert OneInchAdapter__UnsupportedProtocol();
    }

    /// @dev V2 pools have no fee parameter — factory.getPair(token0, token1) uniquely identifies the pool.
    function _getTokenOutUniV2(uint256 dex, address tokenIn) internal view returns (address) {
        address pool = address(uint160(dex));
        address token0 = IUniswapV3(pool).token0();
        address token1 = IUniswapV3(pool).token1();
        if (IUniswapV2Factory(univ2Factory).getPair(token0, token1) != pool) revert OneInchAdapter__InvalidPool();
        // tokenIn must be one of the pool's tokens
        if (token0 != tokenIn && token1 != tokenIn) revert OneInchAdapter__InvalidPool();
        return token0 == tokenIn ? token1 : token0;
    }

    /// @dev V3 pools are identified by (token0, token1, fee) — read fee from the pool and verify against the factory.
    function _getTokenOutUniV3(uint256 dex, address tokenIn) internal view returns (address) {
        address pool = address(uint160(dex));
        address token0 = IUniswapV3(pool).token0();
        address token1 = IUniswapV3(pool).token1();
        uint24 fee = IUniswapV3(pool).fee();
        if (IUniswapV3Factory(univ3Factory).getPool(token0, token1, fee) != pool) revert OneInchAdapter__InvalidPool();
        bool zeroForOne = (dex >> UNISWAP_V3_ZERO_FOR_ONE_OFFSET) & 1 == 1;
        address inputToken = zeroForOne ? token0 : token1;
        if (inputToken != tokenIn) revert OneInchAdapter__InvalidPool();
        return zeroForOne ? token1 : token0;
    }

    /// @dev Curve has no single factory — validate via MetaRegistry which aggregates StableSwap/CryptoSwap/etc.
    ///      get_coins returns zeros for unregistered pools, so a non-zero coin at the requested index is a valid pool.
    function _getTokenOutCurve(uint256 dex, address tokenIn) internal view returns (address) {
        address pool = address(uint160(dex));
        uint256 fromTokenIndex = (dex >> CURVE_FROM_COINS_ARG_OFFSET) & CURVE_TO_COINS_ARG_MASK;
        uint256 toTokenIndex = (dex >> CURVE_TO_COINS_ARG_OFFSET) & CURVE_TO_COINS_ARG_MASK;
        address[8] memory coins = ICurveMetaRegistry(curveMetaRegistry).get_coins(pool);
        // tokenIn must be the pool's from-coin at the index 1inch will swap from
        if (coins[fromTokenIndex] != tokenIn) revert OneInchAdapter__InvalidPool();
        address tokenOut = coins[toTokenIndex];
        //this will hit if the index is out of range on a valid pool, and return "no registry" on invalid curve pool
        if (tokenOut == address(0)) revert OneInchAdapter__InvalidPool();
        return tokenOut;
    }
}
