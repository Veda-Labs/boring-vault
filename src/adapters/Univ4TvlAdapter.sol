// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {TickMath} from "./libraries/TickMath.sol";

import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";

import {AggregatorV3Interface, ChainlinkDataFeedLib} from "./libraries/ChainlinkDataFeedLib.sol";

// /*//////////////////////////////////////////////////////////////
//                         ADAPTER
// //////////////////////////////////////////////////////////////*/
interface IStateViewer {
    function getSlot0(bytes32 poolId)
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpfee);
}

interface IPositionManager {
    function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity);
}

contract UniV4PositionTvlAdapter {
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    address public constant STATE_VIEWER = 0x77395F3b2E73aE90843717371294fa97cC419D64;

    address public constant USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;

    address public constant MON_USDC_ORACLE = 0xBcD78f76005B7515837af6b50c7C52BCf73822fb;

    address public constant POSITION_MANAGER = 0x5b7eC4a94fF9beDb700fb82aB09d5846972F4016;

    /*//////////////////////////////////////////////////////////////
    //                             STORAGE
    //     //////////////////////////////////////////////////////////////*/
    bytes32 public immutable pool_id;
    uint8 private immutable target_decimals;
    uint256 tokenId;
    int24 lowerTick;
    int24 upperTick;
    IStateViewer private immutable stateViewer;
    IPositionManager private immutable positionManager;
    AggregatorV3Interface private immutable monUsdcOracle;

    constructor(bytes32 _pool_id, uint256 _tokenId, int24 _lowerTick, int24 _upperTick, uint8 _targetDecimals) {
        pool_id = _pool_id;
        stateViewer = IStateViewer(STATE_VIEWER);
        positionManager = IPositionManager(POSITION_MANAGER);
        monUsdcOracle = AggregatorV3Interface(MON_USDC_ORACLE);
        target_decimals = _targetDecimals;
        lowerTick = _lowerTick;
        upperTick = _upperTick;
        tokenId = _tokenId;
    }

    /*//////////////////////////////////////////////////////////////
    //                         EXTERNAL API
    ////////////////////////////////////////////////////////////////*/

    /// @dev returns total value locked in USDC terms (6 decimals)
    function getUserTvl(address user) external view returns (uint256 tvl) {
        (uint256 value) = getUserPositionValues(user);
        tvl = value;
    }

    /// @dev mirrors Morpho adapter structure
    function getUserPositionValues(address user) public view returns (uint256 totalValueInUSDC) {
        (uint160 sqrtPriceX96,,,) = stateViewer.getSlot0(pool_id);
        uint128 liquidity = positionManager.getPositionLiquidity(tokenId);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(lowerTick), TickMath.getSqrtRatioAtTick(upperTick), liquidity
        );

        // token0 is MON, token1 is USDC
        uint256 valuesInUSDC = 0;
        valuesInUSDC += amount1;
        valuesInUSDC += _montoUsdc(amount0);
        totalValueInUSDC = valuesInUSDC;
    }

    /*//////////////////////////////////////////////////////////////
    //                         PRICE HELPERS
    //     //////////////////////////////////////////////////////////////*/

    function _montoUsdc(uint256 amount) internal view returns (uint256) {
        uint256 price = monUsdcOracle.getPrice();
        uint256 decimals = monUsdcOracle.decimals();

        unchecked {
            if (decimals < target_decimals) {
                price = price * (10 ** (target_decimals - decimals));
            } else if (decimals > target_decimals) {
                price = price / (10 ** (decimals - target_decimals));
            }
            return (price * amount) / 1e18;
        }
    }
}
