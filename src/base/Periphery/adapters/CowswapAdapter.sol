// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";


interface IDomainSeparator {
    function domainSeparator() external view returns (bytes32);
}

contract CowswapAdapter is IAdapter {

    address immutable cowSettlement;
    address immutable vaultRelayer;

    bytes32 constant GPV2_ORDER_TYPE_HASH = keccak256(
        "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,string kind,bool partiallyFillable,string sellTokenBalance,string buyTokenBalance)"
    );

    constructor(address _cowSettlement, address _vaultRelayer) {
        cowSettlement = _cowSettlement;
        vaultRelayer = _vaultRelayer;
    }

    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address) external view returns (OrderInfo memory) {
         DecoderCustomTypes.GPv2OrderData memory order = abi.decode(swapConfig.swapData, (DecoderCustomTypes.GPv2OrderData));

         if (order.kind != keccak256("sell")) revert("only sell orders supported");
         if (ERC20(order.sellToken) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
         if (ERC20(order.buyToken) != swapConfig.tokenRoute.tokenOut) revert("token mismatch");
         if (order.receiver != (address(swapConfig.receiver))) revert("receiver mismatch");

         bytes32 orderHash = _computeOrderHash(swapConfig.swapData);

         return OrderInfo({
             approvalTarget: vaultRelayer,
             cancelTarget: cowSettlement,
             settlementCaller: cowSettlement,
             inputToken: order.sellToken,
             outputToken: order.buyToken,
             inputAmount: order.sellAmount,
             outputAmount: order.buyAmount,
             protocolHash: orderHash
         });
    }

    function cancelLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address swapper) external view returns (address, bytes memory) {
        DecoderCustomTypes.GPv2OrderData memory order = abi.decode(swapConfig.swapData, (DecoderCustomTypes.GPv2OrderData));
        bytes32 orderHash = _computeOrderHash(swapConfig.swapData);
        bytes memory orderUid = abi.encodePacked(orderHash, swapper, order.validTo);
        return (cowSettlement, abi.encodeWithSignature("invalidateOrder(bytes)", orderUid));
    }

    function version() external view returns (uint256) {
         return 1;
    }

    //============================== Internal ===============================

    function _computeOrderHash(bytes memory swapData) internal view returns (bytes32) {
        bytes32 domainSeparator = IDomainSeparator(cowSettlement).domainSeparator();
        bytes32 structHash = keccak256(abi.encodePacked(GPV2_ORDER_TYPE_HASH, swapData));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
