// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

//IAdapter does what exactly? TBD. 
contract CowswapAdapter is IAdapter {
    
   function swap(bytes calldata data, address swapper) external view returns (bool success, uint256 sellAmount, uint256 buyAmount) {
        //decode cowswap data

        DecoderCustomTypes.GPv2OrderData memory order = abi.decode(data, (DecoderCustomTypes.GPv2OrderData));

        //handle verification here?
        //check the token router, etc.

        bytes32 route = ISwapper(swapper).getRouteId(order.sellToken, order.buyToken);
        if (!ISwapper(swapper).approvedRoutes(route)) revert("bad route");
        if (order.receiver != swapper) revert("swapper not receiver");

        return (true, order.sellAmount, order.buyAmount);
   } 

   function version() external view returns (uint256) {
        return 1; 
   }
}
