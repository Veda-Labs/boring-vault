// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {ISwapper, OracleConfig} from "src/interfaces/ISwapper.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract PriceValidator is IPriceValidator {
    using FixedPointMathLib for uint256;

    error PriceValidator__OracleNotConfigured();
    error PriceValidator__ExceedsMaxSlippage();
    error PriceValidator__ExceedsRouteMaxSlippage();

    function validate(
        ERC20 tokenIn,
        ERC20 tokenOut,
        uint256 inputAmount,
        uint256 outputAmount,
        address quoteAsset,
        uint256 slippageBps
    ) external view {
        ISwapper swapper = ISwapper(msg.sender);

        bytes32 key = swapper.getRouteId(tokenIn, tokenOut);
        uint256 maxSlippageBps = swapper.maxSlippageBpsPerRoute(key);
        if (slippageBps > maxSlippageBps) revert PriceValidator__ExceedsRouteMaxSlippage();

        uint256 valueIn = _resolvePrice(swapper, address(tokenIn), quoteAsset, inputAmount, tokenIn.decimals());
        uint256 valueOut = _resolvePrice(swapper, address(tokenOut), quoteAsset, outputAmount, tokenOut.decimals());

        // if either side skipped validation, no slippage check
        if (valueIn == 0 || valueOut == 0) return;

        uint256 minValueOut = valueIn.mulDivDown((10_000 - slippageBps), 10_000);
        if (valueOut < minValueOut) revert PriceValidator__ExceedsMaxSlippage();
    }

    /// @notice Resolves the price of a token amount in the final quote asset by walking the price path.
    ///         At each hop, ALL oracles must independently pass. Returns 0 if skipValidation is set.
    function _resolvePrice(
        ISwapper swapper,
        address token,
        address quoteAsset,
        uint256 amount,
        uint8 decimals
    ) internal view returns (uint256) {
        address[] memory path = swapper.getPricePath(ERC20(token), quoteAsset);
        if (path.length == 0) revert PriceValidator__OracleNotConfigured();

        // Walk the path: token -> path[0] -> path[1] -> ... -> quoteAsset
        // At each hop, check all oracles and use the first oracle's rate for the price calculation
        address currentBase = token;
        uint256 price = amount;

        for (uint256 i = 0; i < path.length; i++) {
            OracleConfig[] memory configs = swapper.getOracles(currentBase, path[i]);
            if (configs.length == 0) revert PriceValidator__OracleNotConfigured();

            // if any config has skipValidation, skip the entire token's price resolution
            if (configs[0].skipValidation) return 0;

            // use first oracle's rate for price calculation
            uint256 baseRate = IRateProvider(configs[0].rateProvider).getRate();
            price = price.mulDivDown(baseRate, 10 ** decimals);
            // after first hop, rates are 18 decimal normalized
            decimals = 18;

            // check all remaining oracles also produce an acceptable rate
            for (uint256 j = 1; j < configs.length; j++) {
                if (configs[j].skipValidation) return 0;
                IRateProvider(configs[j].rateProvider).getRate();
            }

            currentBase = path[i];
        }

        return price;
    }
}
