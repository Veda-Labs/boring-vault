// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {TickMath} from "./libraries/TickMath.sol";

import {
    LiquidityAmounts
} from "./libraries/LiquidityAmounts.sol";

import {
    AggregatorV3Interface,
    ChainlinkDataFeedLib
} from "./libraries/ChainlinkDataFeedLib.sol";

// /*//////////////////////////////////////////////////////////////
//                         ADAPTER
// //////////////////////////////////////////////////////////////*/
interface INonfungiblePositionManager {
    function positions(
        uint256 tokenId
    )
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
}

contract UniV3PositionTvlAdapter {

    using ChainlinkDataFeedLib for AggregatorV3Interface;
    uint256 public immutable token_id;
    uint8 private immutable target_decimals;

    address public constant POSITION_MANAGER =
        0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    address public constant BTC_ETH_ORACLE =
        0xc5a90A6d7e4Af242dA238FFe279e9f2BA0c64B2e;

    /*//////////////////////////////////////////////////////////////
//                             STORAGE
//     //////////////////////////////////////////////////////////////*/

    INonfungiblePositionManager private immutable npm;
    IUniswapV3Pool private immutable pool;
    AggregatorV3Interface private immutable btcEthOracle;

    constructor(address _pool, uint256 _token_id, uint256 _targetDecimal) {
        pool = IUniswapV3Pool(_pool);
        token_id = _token_id;
        target_decimals = uint8(_targetDecimal);
        npm = INonfungiblePositionManager(POSITION_MANAGER);
        btcEthOracle = AggregatorV3Interface(BTC_ETH_ORACLE);
    }

    /*//////////////////////////////////////////////////////////////
//                         EXTERNAL API
//     //////////////////////////////////////////////////////////////*/

    /// @dev returns total value locked in USDC terms (6 decimals)
    function getUserTvl(address user) external view returns (uint256 tvl) {
        (uint256 value) = getUserPositionValues(user);
        tvl = value;
    }

    /// @dev mirrors Morpho adapter structure
    function getUserPositionValues(
        address user
    ) public view returns (uint256 totalValueInEth) {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = npm.positions(token_id);

        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                liquidity
            );

        amount0 += tokensOwed0;
        amount1 += tokensOwed1;

        uint256 valuesInEth = 0;
        if (token0 == WETH) {
            valuesInEth += amount0;
        } else if (token0 == WBTC) {
            valuesInEth += _btcToEth(amount0);
        }
        if (token1 == WETH) {
            valuesInEth += amount1;
        } else if (token1 == WBTC) {
            valuesInEth += _btcToEth(amount1);
        }
        totalValueInEth = valuesInEth;
    }

    /*//////////////////////////////////////////////////////////////
//                         PRICE HELPERS
//     //////////////////////////////////////////////////////////////*/

    function _btcToEth(uint256 amount) internal view returns (uint256) {
        uint256 price = btcEthOracle.getPrice();
        uint256 decimals = btcEthOracle.decimals();

        unchecked {
            if (decimals < target_decimals) {
                return price * (10 ** (target_decimals - decimals));
            } else if (decimals > target_decimals) {
                return price / (10 ** (decimals - target_decimals));
            }
            return (price * amount) / 1e8;
        }
    }
}
