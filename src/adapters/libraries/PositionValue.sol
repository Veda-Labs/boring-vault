// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.8 <0.9.0;

import {TickMath} from "./TickMath.sol";
import {LiquidityAmounts} from "./LiquidityAmounts.sol";
import {FullMath} from "./FullMath.sol";

interface INonfungiblePositionManager {
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
    function feeGrowthGlobal0X128() external view returns (uint256);
    function feeGrowthGlobal1X128() external view returns (uint256);
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );
}

/// @title Returns information about the token value held in a Uniswap V3 NFT
library PositionValue {
    uint256 internal constant Q128 = 1 << 128;

    struct FeeParams {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0Last;
        uint256 feeGrowthInside1Last;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @notice principal + uncollected fees + tokensOwed, in token0/token1 terms
    function total(INonfungiblePositionManager npm, IUniswapV3Pool pool, uint256 tokenId)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 p0, uint256 p1) = _principal(npm, pool, tokenId);
        (uint256 f0, uint256 f1) = _feesWithOwed(npm, pool, tokenId);
        amount0 = p0 + f0;
        amount1 = p1 + f1;
    }

    function _principal(INonfungiblePositionManager npm, IUniswapV3Pool pool, uint256 tokenId)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        (,,,,, int24 tickLower, int24 tickUpper, uint128 liquidity,,,,) = npm.positions(tokenId);
        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    function _feesWithOwed(INonfungiblePositionManager npm, IUniswapV3Pool pool, uint256 tokenId)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        FeeParams memory p = _loadFeeParams(npm, tokenId);
        return _computeFees(pool, p);
    }

    function _loadFeeParams(INonfungiblePositionManager npm, uint256 tokenId)
        private
        view
        returns (FeeParams memory p)
    {
        (
            ,,,,,
            p.tickLower,
            p.tickUpper,
            p.liquidity,
            p.feeGrowthInside0Last,
            p.feeGrowthInside1Last,
            p.tokensOwed0,
            p.tokensOwed1
        ) = npm.positions(tokenId);
    }

    function _computeFees(IUniswapV3Pool pool, FeeParams memory p)
        private
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (, int24 tickCurrent,,,,,) = pool.slot0();
        (,, uint256 lowerOutside0, uint256 lowerOutside1,,,,) = pool.ticks(p.tickLower);
        (,, uint256 upperOutside0, uint256 upperOutside1,,,,) = pool.ticks(p.tickUpper);

        uint256 feeGrowthInside0;
        uint256 feeGrowthInside1;

        unchecked {
            if (tickCurrent < p.tickLower) {
                feeGrowthInside0 = lowerOutside0 - upperOutside0;
                feeGrowthInside1 = lowerOutside1 - upperOutside1;
            } else if (tickCurrent < p.tickUpper) {
                feeGrowthInside0 = pool.feeGrowthGlobal0X128() - lowerOutside0 - upperOutside0;
                feeGrowthInside1 = pool.feeGrowthGlobal1X128() - lowerOutside1 - upperOutside1;
            } else {
                feeGrowthInside0 = upperOutside0 - lowerOutside0;
                feeGrowthInside1 = upperOutside1 - lowerOutside1;
            }

            amount0 = FullMath.mulDiv(feeGrowthInside0 - p.feeGrowthInside0Last, p.liquidity, Q128) + p.tokensOwed0;
            amount1 = FullMath.mulDiv(feeGrowthInside1 - p.feeGrowthInside1Last, p.liquidity, Q128) + p.tokensOwed1;
        }
    }
}
