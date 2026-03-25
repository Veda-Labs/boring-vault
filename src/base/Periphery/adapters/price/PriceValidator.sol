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
    error PriceValidator__OracleLengthMismatch();

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

        (bool skipIn, uint256[] memory valuesIn) = _getPrices(swapper, tokenIn, quoteAsset, inputAmount);
        (bool skipOut, uint256[] memory valuesOut) = _getPrices(swapper, tokenOut, quoteAsset, outputAmount);

        // if either side skipped validation, no slippage check
        if (skipIn || skipOut) return;

        for (uint256 i; i < valuesIn.length;) {
            for (uint256 j; j < valuesOut.length;) {
                uint256 minValueOut = valuesIn[i].mulDivDown((10_000 - slippageBps), 10_000);
                if (valuesOut[j] < minValueOut) revert PriceValidator__ExceedsMaxSlippage();
                unchecked { j++; }
            }
            unchecked { i++; }
        }
    }

    function _getPrices(
        ISwapper swapper,
        ERC20 token,
        address quoteAsset,
        uint256 amount
    ) internal view returns (bool skipValidation, uint256[] memory values) {
        (address[] memory rateProviders, address[] memory intermediaries, bool skip) = swapper.getBaseAssetOracle(token, quoteAsset);
        if (skip) return (true, values);

        uint256 rateProviderLength = rateProviders.length;
        if (rateProviderLength != intermediaries.length) revert PriceValidator__OracleLengthMismatch();

        values = new uint256[](rateProviderLength);
        uint256 decimals = token.decimals();

        for (uint256 i; i < rateProviderLength;) {
            if (rateProviders[i] == address(0)) revert PriceValidator__OracleNotConfigured();

            values[i] = amount.mulDivDown(IRateProvider(rateProviders[i]).getRate(), 10 ** decimals);

            if (intermediaries[i] != address(0)) {
                address baseRateProvider = swapper.oracles(ERC20(intermediaries[i]), quoteAsset, 0);
                if (baseRateProvider == address(0)) revert PriceValidator__OracleNotConfigured();
                values[i] = values[i].mulDivDown(IRateProvider(baseRateProvider).getRate(), 1e18);
            }

            unchecked {
                i++;
            }
        }

        return (false, values);
    }
}
