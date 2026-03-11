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

    constructor(address _cowSettlement) {
        cowSettlement = _cowSettlement;
    }
    
    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address swapper) external view returns (address, address, address, uint256, uint256) {
         //decode cowswap data

         DecoderCustomTypes.GPv2OrderData memory order = abi.decode(swapConfig.swapData, (DecoderCustomTypes.GPv2OrderData));

         if (ERC20(order.sellToken) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
         if (ERC20(order.buyToken) != swapConfig.tokenRoute.tokenOut) revert("token mismatch");
         if (order.receiver != (address(swapConfig.receiver))) revert("receiver mismatch");

         return (cowSettlement, order.sellToken, order.buyToken, order.sellAmount, order.buyAmount);
    } 

    function version() external view returns (uint256) {
         return 1; 
    }
}
