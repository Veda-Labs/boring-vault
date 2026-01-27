// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface ICurveRegistry {
    function find_pool_for_coins(address _from, address _to) external view returns (address);
    function find_pool_for_coins(address _from, address _to, uint256 i) external view returns (address);
}

/*
 * source .env && forge script script/utils/Mainnet/CheckCurvePools.s.sol:CheckCurvePools --rpc-url mainnet -vvvv
 */

contract CheckCurvePools is Script {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // Curve registry addresses
    address constant CURVE_REGISTRY = 0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d7f5;
    address constant CURVE_METAREGISTRY = 0xF98B45FA17DE75FB1aD0e7aFD971b0ca00e379fC;

    function run() external view {
        console2.log("=== Checking Curve Pools ===");
        console2.log("");

        console2.log("Note: Curve might have better liquidity for stablecoin/stablecoin swaps");
        console2.log("This is just a check - full Curve integration would need more work");
        console2.log("");

        // Try to find sUSDE/USDC pool
        console2.log("Looking for sUSDE/USDC on Curve Registry...");
        try ICurveRegistry(CURVE_REGISTRY).find_pool_for_coins(SUSDE, USDC) returns (address pool) {
            if (pool != address(0)) {
                console2.log("Found pool:", pool);
            } else {
                console2.log("No pool found");
            }
        } catch {
            console2.log("Registry query failed");
        }

        console2.log("");
        console2.log("Looking for sUSDE/USDe on Curve Registry...");
        try ICurveRegistry(CURVE_REGISTRY).find_pool_for_coins(SUSDE, USDE) returns (address pool) {
            if (pool != address(0)) {
                console2.log("Found pool:", pool);
            } else {
                console2.log("No pool found");
            }
        } catch {
            console2.log("Registry query failed");
        }

        console2.log("");
        console2.log("=== Recommendation ===");
        console2.log("For sUSDE -> USDC swaps:");
        console2.log("1. Use Uniswap V3 multi-hop: sUSDE -> USDT -> USDC");
        console2.log("   (sUSDE/USDT has 1.4M liquidity on Uniswap V3)");
        console2.log("2. Check Curve Finance for better rates");
        console2.log("3. Use 1inch/CoWSwap aggregator for best execution");
    }
}
