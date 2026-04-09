// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {BaseAdapter} from "src/base/Periphery/adapters/BaseAdapter.sol";
import {IUniswapV3} from "src/interfaces/IUniswapV3.sol";

contract OpenOceanAdapter is IAdapter, BaseAdapter {

    //============================== Errors ===============================

    error OpenOceanAdapter__InvalidCaller();
    error OpenOceanAdapter__DstReceiverNotSwapper();
    error OpenOceanAdapter__SrcTokenMismatch();
    error OpenOceanAdapter__DstTokenMismatch();
    error OpenOceanAdapter__RecipientNotSwapper();
    error OpenOceanAdapter__WethFlagsNotAllowed();

    //============================== State ===============================

    address public immutable router;
    // Official OpenOcean caller contract — the only permitted IOpenOceanCaller value.
    // Enforced in swap(), simpleSwap(), and swapGmxV2() to prevent arbitrary caller attacks.
    address public immutable openOceanCaller;

    //============================== Constants ===============================

    // UniV2 pool bit masks — applied to bytes32[] pools elements cast to uint256.
    // REVERSE_MASK: when set, output token is token0 (selling token1); otherwise output is token1.
    // WETH_MASK: blocked — causes OpenOcean to unwrap WETH to ETH before delivery. The vault is
    //            ERC20-only and cannot meaningfully receive raw ETH.
    uint256 internal constant REVERSE_MASK = 1 << 255;
    uint256 internal constant WETH_MASK    = 1 << 254;

    // UniV3 pool bit masks — applied to uint256[] pools elements.
    // ONE_FOR_ZERO_MASK: when set, zeroForOne = false (token1 → token0).
    // WETH_WRAP_MASK: blocked — causes input ETH to be wrapped to WETH. The vault provides ERC20s,
    //                not raw ETH.
    // WETH_UNWRAP_MASK: blocked — causes output WETH to be unwrapped to ETH. Same reason as above.
    uint256 internal constant ONE_FOR_ZERO_MASK = 1 << 255;
    uint256 internal constant WETH_WRAP_MASK    = 1 << 254;
    uint256 internal constant WETH_UNWRAP_MASK  = 1 << 253;

    //============================== Constructor ===============================

    constructor(address _router, address _openOceanCaller) {
        router = _router;
        openOceanCaller = _openOceanCaller;
    }

    //============================== Main swap functions ===============================

    function swap(
        address caller,
        DecoderCustomTypes.OpenOceanSwapDescription calldata desc,
        DecoderCustomTypes.OpenOceanCallDescription[] calldata /*calls*/
    ) external view returns (address, uint256) {
        if (caller != openOceanCaller) revert OpenOceanAdapter__InvalidCaller();

        if (desc.dstReceiver != msg.sender) revert OpenOceanAdapter__DstReceiverNotSwapper();

        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert OpenOceanAdapter__SrcTokenMismatch();
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert OpenOceanAdapter__DstTokenMismatch();

        return (router, desc.amount);
    }

    function simpleSwap(
        address caller,
        DecoderCustomTypes.OpenOceanSimpleSwapDescription calldata desc,
        DecoderCustomTypes.OpenOceanCallDescription[] calldata /*calls*/
    ) external view returns (address, uint256) {
        if (caller != openOceanCaller) revert OpenOceanAdapter__InvalidCaller();

        if (desc.dstReceiver != msg.sender) revert OpenOceanAdapter__DstReceiverNotSwapper();

        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert OpenOceanAdapter__SrcTokenMismatch();
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert OpenOceanAdapter__DstTokenMismatch();

        return (router, desc.amount);
    }

    function swapGmxV2(
        address caller,
        DecoderCustomTypes.OpenOceanSwapDescription calldata desc,
        DecoderCustomTypes.OpenOceanCallDescription[] calldata /*calls*/
    ) external view returns (address, uint256) {
        if (caller != openOceanCaller) revert OpenOceanAdapter__InvalidCaller();

        if (desc.dstReceiver != msg.sender) revert OpenOceanAdapter__DstReceiverNotSwapper();

        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert OpenOceanAdapter__SrcTokenMismatch();
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert OpenOceanAdapter__DstTokenMismatch();

        return (router, desc.amount);
    }

    //============================== UniswapV2 direct paths ===============================

    function callUniswap(
        address srcToken,
        uint256 amount,
        uint256, /*minReturn*/
        bytes32[] calldata pools
    ) external view returns (address, uint256) {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(srcToken) != swapConfig.tokenRoute.tokenIn) revert OpenOceanAdapter__SrcTokenMismatch();

        address dstToken = _getUniV2DstToken(pools);
        if (ERC20(dstToken) != swapConfig.tokenRoute.tokenOut) revert OpenOceanAdapter__DstTokenMismatch();

        return (router, amount);
    }

    function callUniswapTo(
        address srcToken,
        uint256 amount,
        uint256, /*minReturn*/
        bytes32[] calldata pools,
        address payable recipient
    ) external view returns (address, uint256) {
        if (recipient != payable(msg.sender)) revert OpenOceanAdapter__RecipientNotSwapper();
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(srcToken) != swapConfig.tokenRoute.tokenIn) revert OpenOceanAdapter__SrcTokenMismatch();

        address dstToken = _getUniV2DstToken(pools);
        if (ERC20(dstToken) != swapConfig.tokenRoute.tokenOut) revert OpenOceanAdapter__DstTokenMismatch();

        return (router, amount);
    }

    //============================== UniswapV3 direct path ===============================

    function uniswapV3SwapTo(
        address payable recipient,
        uint256 amount,
        uint256, /*minReturn*/
        uint256[] calldata pools
    ) external view returns (address, uint256) {
        if (recipient != payable(msg.sender)) revert OpenOceanAdapter__RecipientNotSwapper();
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();

        address srcToken = _getUniV3SrcToken(pools);
        if (ERC20(srcToken) != swapConfig.tokenRoute.tokenIn) revert OpenOceanAdapter__SrcTokenMismatch();

        address dstToken = _getUniV3DstToken(pools);
        if (ERC20(dstToken) != swapConfig.tokenRoute.tokenOut) revert OpenOceanAdapter__DstTokenMismatch();

        return (router, amount);
    }

    //============================== IAdapter stubs ===============================

    function verifyLimitOrder(BoringSwapper.SwapConfig calldata, address) external pure returns (OrderInfo memory) {
        return OrderInfo(address(0), address(0), address(0), address(0), address(0), 0, 0, bytes32(0));
    }

    function cancelLimitOrder(BoringSwapper.SwapConfig calldata, address) external pure returns (address, bytes memory) {
        return (address(0), bytes(""));
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    //============================== Internal helpers ===============================

    /// @dev Derives the output token from the last pool in a UniV2 pools chain.
    ///      Reverts if WETH_MASK is set — that path delivers ETH, not an ERC20.
    function _getUniV2DstToken(bytes32[] calldata pools) internal view returns (address) {
        uint256 rawPool = uint256(pools[pools.length - 1]);
        if (rawPool & WETH_MASK != 0) revert OpenOceanAdapter__WethFlagsNotAllowed();
        address poolAddr = address(uint160(rawPool));
        bool reversed = rawPool & REVERSE_MASK != 0;
        return reversed ? IUniswapV3(poolAddr).token0() : IUniswapV3(poolAddr).token1();
    }

    /// @dev Derives the input token from the first pool in a UniV3 pools chain.
    ///      Reverts if WETH_WRAP_MASK is set — that path expects ETH as input, not an ERC20.
    function _getUniV3SrcToken(uint256[] calldata pools) internal view returns (address) {
        uint256 firstPool = pools[0];
        if (firstPool & WETH_WRAP_MASK != 0) revert OpenOceanAdapter__WethFlagsNotAllowed();
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
}
