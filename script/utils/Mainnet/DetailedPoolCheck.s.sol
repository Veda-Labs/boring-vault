// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

// source .env && forge script script/utils/Mainnet/DetailedPoolCheck.s.sol:DetailedPoolCheck --rpc-url $MAINNET_RPC_URL -vvvv

interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function liquidity() external view returns (uint128);
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/*
 * source .env && forge script script/utils/Mainnet/DetailedPoolCheck.s.sol:DetailedPoolCheck --rpc-url mainnet -vvvv
 */

contract DetailedPoolCheck is Script {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant POOL_100 = 0x64cF83e9554A99aCA4e23515908b706e1013071F;

    function run() external view {
        console2.log("=== Detailed sUSDE/USDC Pool Analysis ===");
        console2.log("Pool Address:", POOL_100);
        console2.log("");

        IUniswapV3Pool pool = IUniswapV3Pool(POOL_100);

        // Check basic info
        console2.log("--- Basic Info ---");
        console2.log("token0:", pool.token0());
        console2.log("token1:", pool.token1());
        console2.log("fee:", pool.fee());

        // Check current liquidity
        uint128 liquidity = pool.liquidity();
        console2.log("");
        console2.log("--- Liquidity ---");
        console2.log("Current liquidity:", liquidity);

        // Check slot0
        (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality,,,bool unlocked) = pool.slot0();
        console2.log("");
        console2.log("--- Slot0 ---");
        console2.log("sqrtPriceX96:", sqrtPriceX96);
        console2.log("tick:", tick);
        console2.log("observationIndex:", observationIndex);
        console2.log("observationCardinality:", observationCardinality);
        console2.log("unlocked:", unlocked);

        // Check token balances in pool
        console2.log("");
        console2.log("--- Token Balances in Pool ---");
        uint256 susdeBalance = IERC20(SUSDE).balanceOf(POOL_100);
        uint256 usdcBalance = IERC20(USDC).balanceOf(POOL_100);
        console2.log("sUSDE balance:", susdeBalance);
        console2.log("USDC balance:", usdcBalance);

        // Try to get recent observations
        console2.log("");
        console2.log("--- Recent Activity ---");
        if (observationCardinality > 0) {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = 0;      // now
            secondsAgos[1] = 3600;   // 1 hour ago

            try pool.observe(secondsAgos) returns (int56[] memory tickCumulatives, uint160[] memory) {
                console2.log("Tick cumulative now:", uint256(uint56(tickCumulatives[0])));
                console2.log("Tick cumulative 1h ago:", uint256(uint56(tickCumulatives[1])));
                if (tickCumulatives[0] == tickCumulatives[1]) {
                    console2.log("WARNING: No price changes in last hour (possibly no trades)");
                }
            } catch {
                console2.log("Could not fetch observations");
            }
        }

        console2.log("");
        console2.log("=== Analysis ===");
        if (liquidity == 0) {
            console2.log("CONFIRMED: Pool has ZERO liquidity");
            console2.log("This pool cannot be used for swaps");
        } else {
            console2.log("Pool has liquidity:", liquidity);
        }

        if (susdeBalance == 0 && usdcBalance == 0) {
            console2.log("Pool has no token reserves - definitely empty");
        } else {
            console2.log("Pool has token reserves:");
            console2.log("  sUSDE:", susdeBalance);
            console2.log("  USDC:", usdcBalance);
        }
    }
}
