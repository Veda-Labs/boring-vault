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


contract CowswapAdapter is IAdapter {

    address immutable cowSettlement;

    bytes32 constant GPV2_ORDER_TYPE_HASH = keccak256(
        "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,bytes32 kind,bool partiallyFillable,bytes32 sellTokenBalance,bytes32 buyTokenBalance)"
    );

    bytes32 immutable DOMAIN_SEPARATOR;

    constructor(address _cowSettlement) {
        cowSettlement = _cowSettlement;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("Gnosis Protocol"),
            keccak256("v2"),
            block.chainid,
            _cowSettlement
        ));
    }

    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address) external view returns (OrderInfo memory) {
         DecoderCustomTypes.GPv2OrderData memory order = abi.decode(swapConfig.swapData, (DecoderCustomTypes.GPv2OrderData));

         if (order.kind != keccak256("sell")) revert("only sell orders supported");
         if (ERC20(order.sellToken) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
         if (ERC20(order.buyToken) != swapConfig.tokenRoute.tokenOut) revert("token mismatch");
         if (order.receiver != (address(swapConfig.receiver))) revert("receiver mismatch");

         bytes32 structHash = keccak256(abi.encodePacked(GPV2_ORDER_TYPE_HASH, swapConfig.swapData));
         bytes32 orderHash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

         return OrderInfo({
             settlement: cowSettlement,
             inputToken: order.sellToken,
             outputToken: order.buyToken,
             inputAmount: order.sellAmount,
             outputAmount: order.buyAmount,
             protocolHash: orderHash
         });
    }

    function version() external view returns (uint256) {
         return 1;
    }
}
