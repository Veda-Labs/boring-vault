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
    error PriceValidator__ZeroOracleRate();

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
    ) internal view returns (bool, uint256[] memory values) {
        address[] memory rateProviders;
        address[] memory intermediaries;

        // Scoped so `skip` is dropped before the fill phase.
        {
            bool skip;
            (rateProviders, intermediaries, skip) = swapper.getBaseAssetOracle(token, quoteAsset);
            if (skip) return (true, values);
            if (rateProviders.length == 0) revert PriceValidator__OracleNotConfigured();
            if (rateProviders.length != intermediaries.length) revert PriceValidator__OracleLengthMismatch();
        }

        // Count phase — totalValues and loop vars dropped after this block.
        {
            uint256 totalValues;
            for (uint256 i; i < rateProviders.length;) {
                if (rateProviders[i] == address(0)) revert PriceValidator__OracleNotConfigured();
                if (intermediaries[i] != address(0)) {
                    uint256 intLen = swapper.baseOracleLength(ERC20(intermediaries[i]), quoteAsset);
                    if (intLen == 0) revert PriceValidator__OracleNotConfigured();
                    totalValues += intLen;
                } else {
                    totalValues += 1;
                }
                unchecked { i++; }
            }
            values = new uint256[](totalValues);
        }

        // Fill phase — `rate` scoped inside loop body to stay off the stack at the inner call site.
        uint256 decimals = token.decimals();
        uint256 idx;
        for (uint256 i; i < rateProviders.length;) {
            uint256 primaryValue;
            {
                uint256 rate = IRateProvider(rateProviders[i]).getRate();
                if (rate == 0) revert PriceValidator__ZeroOracleRate();
                primaryValue = amount.mulDivDown(rate, 10 ** decimals);
            }
            if (intermediaries[i] != address(0)) {
                idx = _fillIntermediaryValues(swapper, intermediaries[i], quoteAsset, primaryValue, values, idx);
            } else {
                values[idx] = primaryValue;
                unchecked { idx++; }
            }
            unchecked { i++; }
        }
    }

    function _fillIntermediaryValues(
        ISwapper swapper,
        address intermediary,
        address quoteAsset,
        uint256 primaryValue,
        uint256[] memory values,
        uint256 idx
    ) internal view returns (uint256) {
        uint256 intLen = swapper.baseOracleLength(ERC20(intermediary), quoteAsset);
        for (uint256 k; k < intLen;) {
            address baseRateProvider = swapper.oracles(ERC20(intermediary), quoteAsset, k);
            if (baseRateProvider == address(0)) revert PriceValidator__OracleNotConfigured();
            uint256 baseRate = IRateProvider(baseRateProvider).getRate();
            if (baseRate == 0) revert PriceValidator__ZeroOracleRate();
            values[idx] = primaryValue.mulDivDown(baseRate, 1e18);
            unchecked { idx++; k++; }
        }
        return idx;
    }
}
