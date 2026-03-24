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

        uint256 valueIn = _getPrice(swapper, tokenIn, quoteAsset, inputAmount);
        uint256 valueOut = _getPrice(swapper, tokenOut, quoteAsset, outputAmount);

        // if either side skipped validation, no slippage check
        if (valueIn == 0 || valueOut == 0) return;

        uint256 minValueOut = valueIn.mulDivDown((10_000 - slippageBps), 10_000);
        if (valueOut < minValueOut) revert PriceValidator__ExceedsMaxSlippage();
    }

    function _getPrice(
        ISwapper swapper,
        ERC20 token,
        address quoteAsset,
        uint256 amount
    ) internal view returns (uint256) {
        (address rateProvider, address intermediary, bool skipValidation) = swapper.getBaseAssetOracle(token, quoteAsset);

        if (skipValidation) return 0;
        if (rateProvider == address(0)) revert PriceValidator__OracleNotConfigured();

        uint256 decimals = token.decimals();
        uint256 value = amount.mulDivDown(IRateProvider(rateProvider).getRate(), 10 ** decimals);

        if (intermediary != address(0)) {
            address baseRateProvider = swapper.oracles(intermediary, quoteAsset);
            if (baseRateProvider == address(0)) revert PriceValidator__OracleNotConfigured();
            value = value.mulDivDown(IRateProvider(baseRateProvider).getRate(), 1e18);
        }

        return value;
    }
}
