// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {console2} from "forge-std/console2.sol";

contract DebugBalances is Script {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant BORING_VAULT = 0x8503B18b279Fd0f1EC35303D8db834619A12250f;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant aWETH = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address constant aUSDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    function run() public {
        // Check WETH balance of BoringVault
        uint256 wethBalance = ERC20(WETH).balanceOf(BORING_VAULT);
        console2.log("BoringVault WETH balance:", wethBalance);
        
        // Check USDC balance of BoringVault
        uint256 usdcBalance = ERC20(USDC).balanceOf(BORING_VAULT);
        console2.log("BoringVault USDC balance:", usdcBalance);
        
        // Check WETH allowance from BoringVault to AAVE Pool
        uint256 wethAllowanceToAave = ERC20(WETH).allowance(BORING_VAULT, AAVE_POOL);
        console2.log("BoringVault WETH allowance to AAVE:", wethAllowanceToAave);
        
        // Check WETH allowance from BoringVault to aWETH
        uint256 wethAllowanceToAWeth = ERC20(WETH).allowance(BORING_VAULT, aWETH);
        console2.log("BoringVault WETH allowance to aWETH:", wethAllowanceToAWeth);
        
        // Check USDC allowance from BoringVault to AAVE Pool
        uint256 usdcAllowanceToAave = ERC20(USDC).allowance(BORING_VAULT, AAVE_POOL);
        console2.log("BoringVault USDC allowance to AAVE:", usdcAllowanceToAave);
        
        // Check aToken balances
        uint256 aWethBalance = ERC20(aWETH).balanceOf(BORING_VAULT);
        console2.log("BoringVault aWETH balance:", aWethBalance);
        
        uint256 aUsdcBalance = ERC20(aUSDC).balanceOf(BORING_VAULT);
        console2.log("BoringVault aUSDC balance:", aUsdcBalance);
    }
}