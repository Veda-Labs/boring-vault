// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

/*//////////////////////////////////////////////////////////////
                        UNISWAP IMPORTS
//////////////////////////////////////////////////////////////*/

// import {INonfungiblePositionManager} 
//     from "../../lib/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

// import {IUniswapV3Pool} 
//     from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// import {TickMath} 
//     from "../../lib/v3-core/contracts/libraries/TickMath.sol";

// import {LiquidityAmounts} 
//     from "../../lib/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
    

// import {AggregatorV3Interface, ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";

// /*//////////////////////////////////////////////////////////////
//                         ADAPTER
// //////////////////////////////////////////////////////////////*/

// contract UniV3PositionTvlAdapter {
//     /*//////////////////////////////////////////////////////////////
//                             CONSTANTS
//     //////////////////////////////////////////////////////////////*/
//     using ChainlinkDataFeedLib for AggregatorV3Interface;
//     uint256 public immutable token_id;
//     uint8 private immutable TARGET_DECIMALS;

//     address public constant POSITION_MANAGER =
//         0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

//     // address public constant POOL =
//     //     0x2f5e87C9312fa29aed5c179E456625D79015299c;

//     address public constant WETH =
//         0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

//     address public constant WBTC =
//         0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;


//     address public constant BTC_ETH_ORACLE =
//         0xc5a90A6d7e4Af242dA238FFe279e9f2BA0c64B2e;

//     /*//////////////////////////////////////////////////////////////
//                             STORAGE
//     //////////////////////////////////////////////////////////////*/

//     INonfungiblePositionManager private immutable npm;
//     IUniswapV3Pool private immutable pool;
//     AggregatorV3Interface private immutable btcEthOracle;

//     constructor(address pool,uint256 token_id,uint256 targetDecimal) {
//         pool = IUniswapV3Pool(pool);
//         token_id = token_id;
//         TARGET_DECIMALS = uint8(targetDecimal);
//         npm = INonfungiblePositionManager(POSITION_MANAGER);
//         btcEthOracle = AggregatorV3Interface(BTC_ETH_ORACLE);
//     }

//     /*//////////////////////////////////////////////////////////////
//                         EXTERNAL API
//     //////////////////////////////////////////////////////////////*/

//     /// @dev returns total value locked in USDC terms (6 decimals)
//     function getUserTvl(address user)
//         external
//         view
//         returns (uint256 tvl)
//     {
//         (uint256 value,,) = getUserPositionValues(user);
//         tvl = value;
//     }

//     /// @dev mirrors Morpho adapter structure
//     function getUserPositionValues(address user)
//         public
//         view
//         returns (
//             uint256 collateral,
//             uint256 debt,
//             uint256 supplied
//         )
//     {
//         (
//             ,
//             ,
//             address token0,
//             address token1,
//             ,
//             int24 tickLower,
//             int24 tickUpper,
//             uint128 liquidity,
//             ,
//             ,
//             uint128 tokensOwed0,
//             uint128 tokensOwed1
//         ) = npm.positions(token_id);

//         (uint160 sqrtPriceX96,,,,,,) = pool.slot0();

//         (uint256 amount0, uint256 amount1) =
//             LiquidityAmounts.getAmountsForLiquidity(
//                 sqrtPriceX96,
//                 TickMath.getSqrtRatioAtTick(tickLower),
//                 TickMath.getSqrtRatioAtTick(tickUpper),
//                 liquidity
//             );

//         amount0 += tokensOwed0;
//         amount1 += tokensOwed1;

//         uint256 valuesInEth = 0;
//         if (token0 == WETH) {
//             valuesInEth += amount0;
//         } else if (token0 == WBTC) {
//             valuesInEth += _btcToEth(amount0);
//         }
//         if (token1 == WETH) {
//             valuesInEth += amount1;
//         } else if (token1 == WBTC) {
//             valuesInEth += _btcToEth(amount1);
//         }
//     }

//     /*//////////////////////////////////////////////////////////////
//                         PRICE HELPERS
//     //////////////////////////////////////////////////////////////*/

//     function _btcToEth(uint256 amount) internal view returns (uint256) {
//         uint256 price = btcEthOracle.getPrice();
//         uint256 decimals = btcEthOracle.decimals();

//         unchecked {
//             if (decimals < TARGET_DECIMALS) {
//                 return price * (10 ** (TARGET_DECIMALS - decimals));
//             } else if (decimals > TARGET_DECIMALS) {
//                 return price / (10 ** (decimals - TARGET_DECIMALS));
//             }
//             return (price * amount)/1e8;
//         }
        
//     }
// }
