// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IUniswapV3Pool {
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
 * source .env && forge script script/utils/Mainnet/CheckAllFeeTiers.s.sol:CheckAllFeeTiers --rpc-url mainnet -vvvv
 */

contract CheckAllFeeTiers is Script {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    function run() external view {
        console2.log("=== Checking All Uniswap V3 Fee Tiers ===");
        console2.log("sUSDE -> USDC");
        console2.log("");

        IUniswapV3Factory factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);

        uint24[4] memory fees = [uint24(100), uint24(500), uint24(3000), uint24(10000)];
        string[4] memory feeLabels = ["0.01%", "0.05%", "0.3%", "1%"];

        for (uint256 i = 0; i < fees.length; i++) {
            address pool = factory.getPool(SUSDE, USDC, fees[i]);
            console2.log("--- Fee Tier (bps):", fees[i]);

            if (pool == address(0)) {
                console2.log("Pool: DOES NOT EXIST");
                console2.log("");
                continue;
            }

            console2.log("Pool:", pool);

            IUniswapV3Pool poolContract = IUniswapV3Pool(pool);
            uint128 liquidity = poolContract.liquidity();
            console2.log("Liquidity:", liquidity);

            if (liquidity > 0) {
                (uint160 sqrtPriceX96, int24 tick,,,,,) = poolContract.slot0();
                console2.log("sqrtPriceX96:", sqrtPriceX96);
                console2.log("tick:", tick);
                console2.log("STATUS: USABLE - Has liquidity!");
            } else {
                console2.log("STATUS: NOT USABLE - No liquidity");
            }
            console2.log("");
        }
    }
}
