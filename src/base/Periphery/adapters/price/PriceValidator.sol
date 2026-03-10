// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";


contract PriceValidator is IPriceValidator {
    using FixedPointMathLib for uint256;

        //price the trade
        //IMPORTANT: oracles will need to account for different decimals -> this should happen at the RateProvider level
    //we can add some validation for this here tho?
    function validate(ERC20 tokenIn, ERC20 tokenOut, uint256 inputAmount, uint256 outputAmount, address quoteAsset, uint256 slippageBps) external view {
        address swapper = msg.sender;  
       
        bytes32 key = ISwapper(swapper).getRouteId(tokenIn, tokenOut);  

        uint256 priceBefore = IRateProvider(
            ISwapper(swapper).getOracle(tokenIn, quoteAsset)
        ).getRate();
        uint256 tradePrice = priceBefore.mulDivDown(inputAmount, 10 ** tokenIn.decimals());

        //price out
        uint256 priceAfter = IRateProvider(
            ISwapper(swapper).getOracle(tokenOut, quoteAsset)
        ).getRate();
        uint256 valueOut = priceAfter.mulDivDown(outputAmount, 10 ** tokenOut.decimals());
        
        uint256 maxSlippageBps = ISwapper(swapper).maxSlippageBpsPerRoute(key);
        if (slippageBps > maxSlippageBps) revert("exceeds max slippage for this token route"); 

        uint256 minValueOut = tradePrice.mulDivDown((10_000 - slippageBps), 10_000);
        if (valueOut < minValueOut) revert("exceeds max slippage for route");

    }
}
