// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function liquidity() external view returns (uint128);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/*
 * source .env && forge script script/utils/Mainnet/CheckFactoryPool.s.sol:CheckFactoryPool --rpc-url mainnet -vvvv
 */

contract CheckFactoryPool is Script {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    function run() external view {
        console2.log("=== Getting Pool from Factory ===");
        console2.log("Factory:", UNISWAP_V3_FACTORY);
        console2.log("Token A (sUSDE):", SUSDE);
        console2.log("Token B (USDC):", USDC);
        console2.log("");

        IUniswapV3Factory factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);

        // Try both orderings and all fee tiers
        uint24[4] memory fees = [uint24(100), uint24(500), uint24(3000), uint24(10000)];

        for (uint256 i = 0; i < fees.length; i++) {
            console2.log("--- Fee tier:", fees[i], "bps ---");

            // Try sUSDE, USDC
            address pool1 = factory.getPool(SUSDE, USDC, fees[i]);
            console2.log("getPool(sUSDE, USDC, fee):", pool1);

            // Try USDC, sUSDE (reverse order)
            address pool2 = factory.getPool(USDC, SUSDE, fees[i]);
            console2.log("getPool(USDC, sUSDE, fee):", pool2);

            if (pool1 == pool2) {
                console2.log("Same pool returned (order doesn't matter)");
            }

            if (pool1 != address(0)) {
                IUniswapV3Pool pool = IUniswapV3Pool(pool1);
                uint128 liquidity = pool.liquidity();
                address token0 = pool.token0();
                address token1 = pool.token1();

                console2.log("Pool exists!");
                console2.log("  token0:", token0);
                console2.log("  token1:", token1);
                console2.log("  liquidity:", liquidity);

                uint256 token0Balance = IERC20(token0).balanceOf(pool1);
                uint256 token1Balance = IERC20(token1).balanceOf(pool1);
                console2.log("  token0 balance:", token0Balance);
                console2.log("  token1 balance:", token1Balance);

                if (liquidity > 0) {
                    console2.log("  STATUS: USABLE");
                } else {
                    console2.log("  STATUS: EXISTS BUT NO LIQUIDITY");
                }
            } else {
                console2.log("Pool does not exist");
            }
            console2.log("");
        }
    }
}
