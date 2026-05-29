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

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address);
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

interface IUniswapV3PoolFee {
    function fee() external view returns (uint24);
}

contract OpenOceanAdapter is IAdapter, BaseAdapter {

    //============================== Errors ===============================

    error OpenOceanAdapter__InvalidCaller();
    error OpenOceanAdapter__SrcReceiverMismatch();
    error OpenOceanAdapter__WethFlagsNotAllowed();
    error OpenOceanAdapter__InvalidPool();

    //============================== State ===============================

    address public immutable router;
    address public immutable openOceanCaller;
    address public immutable univ2Factory;
    address public immutable univ3Factory;

    //============================== Constants ===============================

    // UniV2 pool bit masks — applied to bytes32[] pools elements cast to uint256.
    // REVERSE_MASK: when set, output token is token0 (selling token1); otherwise output is token1.
    // WETH_MASK: blocked — causes OpenOcean to unwrap WETH to ETH before delivery. The vault is
    //            ERC20-only and cannot meaningfully receive raw ETH.
    uint256 internal constant REVERSE_MASK = 1 << 255;
    uint256 internal constant WETH_MASK    = 1 << 254;

    // UniV3 pool bit masks — applied to uint256[] pools elements.
    // ONE_FOR_ZERO_MASK: when set, zeroForOne = false (token1 → token0).
    uint256 internal constant ONE_FOR_ZERO_MASK = 1 << 255;
    uint256 internal constant WETH_WRAP_MASK    = 1 << 254; //disallowed: vault is ERC20 only.
    uint256 internal constant WETH_UNWRAP_MASK  = 1 << 253; //disallowed

    //============================== Constructor ===============================

    constructor(address _router, address _openOceanCaller, address _univ2Factory, address _univ3Factory) {
        router = _router;
        openOceanCaller = _openOceanCaller;
        univ2Factory = _univ2Factory;
        univ3Factory = _univ3Factory;
    }

    //============================== Main swap functions ===============================

    function swap(
        address caller,
        DecoderCustomTypes.OpenOceanSwapDescription calldata desc,
        DecoderCustomTypes.OpenOceanCallDescription[] calldata /*calls*/
    ) external view returns (address, uint256) {
        if (caller != openOceanCaller) revert OpenOceanAdapter__InvalidCaller();

        if (desc.srcReceiver != openOceanCaller) revert OpenOceanAdapter__SrcReceiverMismatch();
        if (desc.dstReceiver != msg.sender) revert Adapter__ReceiverMismatch();

        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, desc.amount);
    }

    function simpleSwap(
        address caller,
        DecoderCustomTypes.OpenOceanSimpleSwapDescription calldata desc,
        DecoderCustomTypes.OpenOceanCallDescription[] calldata /*calls*/
    ) external view returns (address, uint256) {
        if (caller != openOceanCaller) revert OpenOceanAdapter__InvalidCaller();

        if (desc.srcReceiver != openOceanCaller) revert OpenOceanAdapter__SrcReceiverMismatch();
        if (desc.dstReceiver != msg.sender) revert Adapter__ReceiverMismatch();

        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, desc.amount);
    }

    function swapGmxV2(
        address caller,
        DecoderCustomTypes.OpenOceanSwapDescription calldata desc,
        DecoderCustomTypes.OpenOceanCallDescription[] calldata /*calls*/
    ) external view returns (address, uint256) {
        if (caller != openOceanCaller) revert OpenOceanAdapter__InvalidCaller();

        if (desc.srcReceiver != openOceanCaller) revert OpenOceanAdapter__SrcReceiverMismatch();
        if (desc.dstReceiver != msg.sender) revert Adapter__ReceiverMismatch();

        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, desc.amount);
    }

    //============================== UniswapV2 direct paths ===============================

    function callUniswap(
        address srcToken,
        uint256 amount,
        uint256, /*minReturn*/
        bytes32[] calldata pools
    ) external view returns (address, uint256) {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(srcToken) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address dstToken = _getUniV2DstToken(pools);
        if (ERC20(dstToken) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, amount);
    }

    function callUniswapTo(
        address srcToken,
        uint256 amount,
        uint256, /*minReturn*/
        bytes32[] calldata pools,
        address payable recipient
    ) external view returns (address, uint256) {
        if (recipient != payable(msg.sender)) revert Adapter__ReceiverMismatch();
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(srcToken) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address dstToken = _getUniV2DstToken(pools);
        if (ERC20(dstToken) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, amount);
    }

    //============================== UniswapV3 direct path ===============================

    function uniswapV3SwapTo(
        address payable recipient,
        uint256 amount,
        uint256, /*minReturn*/
        uint256[] calldata pools
    ) external view returns (address, uint256) {
        if (recipient != payable(msg.sender)) revert Adapter__ReceiverMismatch();
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();

        address srcToken = _getUniV3SrcToken(pools);
        if (ERC20(srcToken) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();

        address dstToken = _getUniV3DstToken(pools);
        if (ERC20(dstToken) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (router, amount);
    }

    //============================== Limit Orders (unsupported) ===============================

    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata, address) external pure returns (OrderInfo memory) {
        revert Adapter__LimitOrdersNotSupported();
    }

    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata, address, bytes calldata /*cancelData*/, bytes calldata /*context*/) external pure returns (address, bytes memory) {
        revert Adapter__LimitOrdersNotSupported();
    }

    function filledAmount(ISwapperTypes.SwapConfig calldata, address, bytes calldata /*context*/) external pure returns (uint256) {
        revert Adapter__LimitOrdersNotSupported();
    }

    function version() external pure returns (string memory) {
        return "v1";
    }

    //============================== Internal helpers ===============================

    /// @dev Derives the output token from the last pool in a UniV2 pools chain.
    ///      Reverts if WETH_MASK is set — that path delivers ETH, not an ERC20.
    ///      Validates every pool against the V2 factory so intermediate pools can't absorb tokens.
    function _getUniV2DstToken(bytes32[] calldata pools) internal view returns (address) {
        for (uint256 i; i < pools.length; ++i) {
            uint256 rawPool = uint256(pools[i]);
            if (rawPool & WETH_MASK != 0) revert OpenOceanAdapter__WethFlagsNotAllowed();
            _validateV2Pool(address(uint160(rawPool)));
        }
        uint256 lastRaw = uint256(pools[pools.length - 1]);
        address lastPool = address(uint160(lastRaw));
        bool reversed = lastRaw & REVERSE_MASK != 0;
        return reversed ? IUniswapV3(lastPool).token0() : IUniswapV3(lastPool).token1();
    }

    /// @dev Derives the input token from the first pool in a UniV3 pools chain.
    ///      Reverts if WETH_WRAP_MASK is set — that path expects ETH as input, not an ERC20.
    ///      Validates every pool against the V3 factory.
    function _getUniV3SrcToken(uint256[] calldata pools) internal view returns (address) {
        for (uint256 i; i < pools.length; ++i) {
            if (pools[i] & WETH_WRAP_MASK != 0) revert OpenOceanAdapter__WethFlagsNotAllowed();
            _validateV3Pool(address(uint160(pools[i])));
        }
        uint256 firstPool = pools[0];
        address poolAddr = address(uint160(firstPool));
        bool zeroForOne = firstPool & ONE_FOR_ZERO_MASK == 0;
        return zeroForOne ? IUniswapV3(poolAddr).token0() : IUniswapV3(poolAddr).token1();
    }

    /// @dev Derives the output token from the last pool in a UniV3 pools chain.
    ///      Reverts if WETH_UNWRAP_MASK is set — that path delivers ETH, not an ERC20.
    function _getUniV3DstToken(uint256[] calldata pools) internal view returns (address) {
        uint256 lastPool = pools[pools.length - 1];
        if (lastPool & WETH_UNWRAP_MASK != 0) revert OpenOceanAdapter__WethFlagsNotAllowed();
        address poolAddr = address(uint160(lastPool));
        bool zeroForOne = lastPool & ONE_FOR_ZERO_MASK == 0;
        return zeroForOne ? IUniswapV3(poolAddr).token1() : IUniswapV3(poolAddr).token0();
    }

    function _validateV2Pool(address pool) internal view {
        address token0 = IUniswapV3(pool).token0();
        address token1 = IUniswapV3(pool).token1();
        if (IUniswapV2Factory(univ2Factory).getPair(token0, token1) != pool) revert OpenOceanAdapter__InvalidPool();
    }

    function _validateV3Pool(address pool) internal view {
        address token0 = IUniswapV3(pool).token0();
        address token1 = IUniswapV3(pool).token1();
        uint24 fee = IUniswapV3PoolFee(pool).fee();
        if (IUniswapV3Factory(univ3Factory).getPool(token0, token1, fee) != pool) revert OpenOceanAdapter__InvalidPool();
    }
}
