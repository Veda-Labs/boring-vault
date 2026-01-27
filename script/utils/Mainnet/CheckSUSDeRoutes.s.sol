// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

interface IUniswapV3Pool {
    function liquidity() external view returns (uint128);
}

/*
 * source .env && forge script script/utils/Mainnet/CheckSUSDeRoutes.s.sol:CheckSUSDeRoutes --rpc-url mainnet -vvvv
 */

contract CheckSUSDeRoutes is Script {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDE = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    struct TokenInfo {
        string name;
        address addr;
    }

    function run() external view {
        console2.log("=== Checking sUSDE Liquidity Routes ===");
        console2.log("");

        TokenInfo[] memory tokens = new TokenInfo[](5);
        tokens[0] = TokenInfo("USDC", USDC);
        tokens[1] = TokenInfo("WETH", WETH);
        tokens[2] = TokenInfo("USDT", USDT);
        tokens[3] = TokenInfo("DAI", DAI);
        tokens[4] = TokenInfo("USDe", USDE);

        IUniswapV3Factory factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);
        uint24[3] memory fees = [uint24(100), uint24(500), uint24(3000)];

        for (uint256 i = 0; i < tokens.length; i++) {
            console2.log("--- sUSDE ->", tokens[i].name, "---");

            bool foundLiquidity = false;
            for (uint256 j = 0; j < fees.length; j++) {
                address pool = factory.getPool(SUSDE, tokens[i].addr, fees[j]);

                if (pool != address(0)) {
                    IUniswapV3Pool poolContract = IUniswapV3Pool(pool);
                    uint128 liquidity = poolContract.liquidity();

                    if (liquidity > 0) {
                        console2.log("  Fee (bps):", fees[j]);
                        console2.log("  Liquidity:", liquidity);
                        console2.log("  STATUS: USABLE");
                        foundLiquidity = true;
                    }
                }
            }

            if (!foundLiquidity) {
                console2.log("  No liquid pools found");
            }
            console2.log("");
        }
    }
}
