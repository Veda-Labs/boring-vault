// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

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
}

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

/*
 * source .env && forge script script/utils/Mainnet/DebugUniswapPool.s.sol:DebugUniswapPool --rpc-url mainnet -vvvv
 */

contract DebugUniswapPool is Script {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    function run() external view {
        console2.log("=== Checking Uniswap V3 Pool ===");
        console2.log("USDC:", USDC);
        console2.log("sUSDE:", SUSDE);
        console2.log("");

        // Check for pool with 1 bps fee (0.01%)
        IUniswapV3Factory factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);
        address pool = factory.getPool(SUSDE, USDC, 100);

        console2.log("Pool address (100 bps):", pool);

        if (pool == address(0)) {
            console2.log("WARNING: Pool does not exist!");

            // Try other fee tiers
            console2.log("");
            console2.log("Checking other fee tiers:");
            address pool500 = factory.getPool(SUSDE, USDC, 500);
            console2.log("Pool (500 bps / 0.05%):", pool500);

            address pool3000 = factory.getPool(SUSDE, USDC, 3000);
            console2.log("Pool (3000 bps / 0.3%):", pool3000);

            address pool10000 = factory.getPool(SUSDE, USDC, 10000);
            console2.log("Pool (10000 bps / 1%):", pool10000);
            return;
        }

        IUniswapV3Pool poolContract = IUniswapV3Pool(pool);

        console2.log("");
        console2.log("--- Pool Details ---");
        address token0 = poolContract.token0();
        address token1 = poolContract.token1();
        console2.log("token0:", token0);
        console2.log("token1:", token1);
        console2.log("fee:", poolContract.fee());
        console2.log("liquidity:", poolContract.liquidity());

        (uint160 sqrtPriceX96, int24 tick,,,,,bool unlocked) = poolContract.slot0();
        console2.log("sqrtPriceX96:", sqrtPriceX96);
        console2.log("tick:", tick);
        console2.log("unlocked:", unlocked);

        console2.log("");
        if (token0 == SUSDE) {
            console2.log("sUSDE is token0, USDC is token1");
            console2.log("For swapping sUSDE -> USDC, zeroForOne = true");
        } else {
            console2.log("USDC is token0, sUSDE is token1");
            console2.log("For swapping sUSDE -> USDC, zeroForOne = false");
        }
    }
}
