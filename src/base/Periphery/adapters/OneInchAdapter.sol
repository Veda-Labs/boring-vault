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


contract OneInchAdapter is IAdapter, BaseAdapter {

    address public immutable ROUTER;

    bytes32 constant ONEINCH_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"
    );

    bytes32 immutable DOMAIN_SEPARATOR;

    constructor(address _router) {
        ROUTER = _router;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("1inch Limit Order Protocol"),
            keccak256("4"),
            block.chainid,
            _router
        ));
    }

    //============================== V6 swap ===============================

    function swap(
        address executor,
        DecoderCustomTypes.SwapDescription memory desc,
        bytes memory /*data*/
    ) external view returns (address, uint256) {
        if (desc.dstReceiver != payable(msg.sender)) revert("dstReceiver must be swapper");

        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert("srcToken mismatch");
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert("dstToken mismatch");

        return (ROUTER, desc.amount);
    }

    //============================== V6 unoswap ===============================

    function unoswap(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");

        return (ROUTER, amount);
    }

    function unoswap2(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/, uint256 /*dex2*/)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");

        return (ROUTER, amount);
    }

    function unoswap3(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/, uint256 /*dex2*/, uint256 /*dex3*/)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");

        return (ROUTER, amount);
    }

    function version() external view returns (uint256) {
        return 1;
    }

    //============================== Limit Orders ===============================

    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address swapper) external view returns (OrderInfo memory) {
        DecoderCustomTypes.OneInchLimitOrder memory order = abi.decode(swapConfig.swapData, (DecoderCustomTypes.OneInchLimitOrder));

        if (ERC20(order.makerAsset) != swapConfig.tokenRoute.tokenIn) revert("makerAsset mismatch");
        if (ERC20(order.takerAsset) != swapConfig.tokenRoute.tokenOut) revert("takerAsset mismatch");
        if (order.maker != swapper) revert("maker must be swapper");
        if (order.receiver != address(swapConfig.receiver)) revert("receiver mismatch");

        bytes32 orderHash = _computeOrderHash(swapConfig.swapData);

        return OrderInfo({
            settlement: ROUTER,
            inputToken: order.makerAsset,
            outputToken: order.takerAsset,
            inputAmount: order.makingAmount,
            outputAmount: order.takingAmount,
            protocolHash: orderHash
        });
    }

    function cancelLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address) external view returns (address, bytes memory) {
        DecoderCustomTypes.OneInchLimitOrder memory order = abi.decode(swapConfig.swapData, (DecoderCustomTypes.OneInchLimitOrder));
        bytes32 orderHash = _computeOrderHash(swapConfig.swapData);
        return (ROUTER, abi.encodeWithSignature("cancelOrder(uint256,bytes32)", order.makerTraits, orderHash));
    }

    //============================== Internal ===============================

    function _computeOrderHash(bytes memory swapData) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, swapData));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }
}
