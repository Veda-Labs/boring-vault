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
    error OpenOceanAdapter__MakerAssetMismatch();
    error OpenOceanAdapter__TakerAssetMismatch();
    error OpenOceanAdapter__MakerNotSwapper();
    error OpenOceanAdapter__ReceiverMismatch();
    error OpenOceanAdapter__NonEmptyMakerAssetData();
    error OpenOceanAdapter__NonEmptyTakerAssetData();
    error OpenOceanAdapter__NonEmptyGetMakerAmount();
    error OpenOceanAdapter__NonEmptyGetTakerAmount();
    error OpenOceanAdapter__NonEmptyPredicate();
    error OpenOceanAdapter__NonEmptyPermit();
    error OpenOceanAdapter__NonEmptyInteraction();

    //============================== State ===============================

    address public immutable router;
    // Official OpenOcean caller contract — the only permitted IOpenOceanCaller value.
    // Enforced in swap(), simpleSwap(), and swapGmxV2() to prevent arbitrary caller attacks.
    address public immutable openOceanCaller;
    // OpenOcean Limit Order Protocol v2 — separate contract from the swap router.
    address public immutable limitOrderProtocol;
    bytes32 public immutable DOMAIN_SEPARATOR;

    //============================== Constants ===============================

    bytes32 constant LIMIT_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address makerAsset,address takerAsset,address maker,address receiver,address allowedSender,uint256 makingAmount,uint256 takingAmount,bytes makerAssetData,bytes takerAssetData,bytes getMakerAmount,bytes getTakerAmount,bytes predicate,bytes permit,bytes interaction)"
    );

    // cancelOrder(Order) where Order is the 15-field tuple.
    bytes4 constant CANCEL_ORDER_SELECTOR = bytes4(
        keccak256(
            "cancelOrder((uint256,address,address,address,address,address,uint256,uint256,bytes,bytes,bytes,bytes,bytes,bytes,bytes))"
        )
    );

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

    constructor(address _router, address _openOceanCaller, address _limitOrderProtocol) {
        router = _router;
        openOceanCaller = _openOceanCaller;
        limitOrderProtocol = _limitOrderProtocol;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("openocean Limit Order Protocol"),
                keccak256("2"),
                block.chainid,
                _limitOrderProtocol
            )
        );
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

    //============================== Limit Orders ===============================

    /// @notice swapData encoding: abi.encode(OpenOceanLimitOrder order)
    ///
    /// Security constraints:
    ///   - maker must be the BoringSwapper
    ///   - receiver must be swapConfig.receiver (the vault)
    ///   - makerAsset/takerAsset must match the approved token route
    ///   - getMakerAmount/getTakerAmount must be empty (fixed fill amounts only)
    ///   - makerAssetData/takerAssetData must be empty (no custom transfer logic)
    ///   - interaction must be empty (no post-fill callbacks into the swapper)
    ///   - permit must be empty (approvals managed by BoringSwapper)
    ///   - predicate must be empty (no conditional fills)
    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address swapper)
        external
        view
        returns (OrderInfo memory)
    {
        DecoderCustomTypes.OpenOceanLimitOrder memory order =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.OpenOceanLimitOrder));

        if (ERC20(order.makerAsset) != swapConfig.tokenRoute.tokenIn) revert OpenOceanAdapter__MakerAssetMismatch();
        if (ERC20(order.takerAsset) != swapConfig.tokenRoute.tokenOut) revert OpenOceanAdapter__TakerAssetMismatch();
        if (order.maker != swapper) revert OpenOceanAdapter__MakerNotSwapper();
        if (order.receiver != address(swapConfig.receiver)) revert OpenOceanAdapter__ReceiverMismatch();

        if (order.makerAssetData.length != 0) revert OpenOceanAdapter__NonEmptyMakerAssetData();
        if (order.takerAssetData.length != 0) revert OpenOceanAdapter__NonEmptyTakerAssetData();
        if (order.getMakerAmount.length != 0) revert OpenOceanAdapter__NonEmptyGetMakerAmount();
        if (order.getTakerAmount.length != 0) revert OpenOceanAdapter__NonEmptyGetTakerAmount();
        if (order.predicate.length != 0) revert OpenOceanAdapter__NonEmptyPredicate();
        if (order.permit.length != 0) revert OpenOceanAdapter__NonEmptyPermit();
        if (order.interaction.length != 0) revert OpenOceanAdapter__NonEmptyInteraction();

        bytes32 orderHash = _computeOrderHash(order);

        return OrderInfo({
            approvalTarget: limitOrderProtocol,
            cancelTarget: limitOrderProtocol,
            settlementCaller: limitOrderProtocol,
            inputToken: order.makerAsset,
            outputToken: order.takerAsset,
            inputAmount: order.makingAmount,
            outputAmount: order.takingAmount,
            protocolHash: orderHash
        });
    }

    function cancelLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address)
        external
        view
        returns (address, bytes memory)
    {
        DecoderCustomTypes.OpenOceanLimitOrder memory order =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.OpenOceanLimitOrder));
        return (limitOrderProtocol, abi.encodeWithSelector(CANCEL_ORDER_SELECTOR, order));
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    //============================== Internal helpers ===============================

    function _computeOrderHash(DecoderCustomTypes.OpenOceanLimitOrder memory order) internal view returns (bytes32) {
        // Split into two abi.encode calls to avoid stack-too-deep (15 fields total).
        // All arguments are fixed-size (uint256/address/bytes32), so concatenating the two
        // encoded chunks produces identical bytes to a single abi.encode with all 16 args.
        bytes32 structHash = keccak256(
            bytes.concat(
                abi.encode(
                    LIMIT_ORDER_TYPE_HASH,
                    order.salt,
                    order.makerAsset,
                    order.takerAsset,
                    order.maker,
                    order.receiver,
                    order.allowedSender,
                    order.makingAmount,
                    order.takingAmount
                ),
                abi.encode(
                    keccak256(order.makerAssetData),
                    keccak256(order.takerAssetData),
                    keccak256(order.getMakerAmount),
                    keccak256(order.getTakerAmount),
                    keccak256(order.predicate),
                    keccak256(order.permit),
                    keccak256(order.interaction)
                )
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

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
