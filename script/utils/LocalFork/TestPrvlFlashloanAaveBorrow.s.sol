// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrow} from "src/micro-managers/PrvlFlashloanAaveBorrow.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/*
 * source .env && forge script script/utils/LocalFork/TestPrvlFlashloanAaveBorrow.s.sol:TestPrvlFlashloanAaveBorrow --fork-url local --broadcast -vv
 */

contract TestPrvlFlashloanAaveBorrow is Script {
    uint256 public privateKey;
    
    address constant MICRO_MANAGER = 0x3d118E4e4263418E0D63de57A5498CC4254B383f;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant AWETH = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address constant BORING_VAULT = 0x3A29E2a5Ddb20C56D62a9D9Fa29b606833C4bf1d;

    function setUp() external {
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        PrvlFlashloanAaveBorrow microManager = PrvlFlashloanAaveBorrow(MICRO_MANAGER);

        uint256 collateralAmount = 1000e6; // 1000 USDC collateral  
        uint256 borrowAmount = 4000e6;     // 4000 USDC borrow (5x leverage total)

        console.log("=== Before Borrow ===");
        console.log("Vault USDC balance:", ERC20(USDC).balanceOf(BORING_VAULT));
        console.log("Vault WETH balance:", ERC20(WETH).balanceOf(BORING_VAULT));
        console.log("Vault aWETH balance:", ERC20(AWETH).balanceOf(BORING_VAULT));

        console.log("Executing 5x leverage borrow...");
        console.log("Collateral:", collateralAmount);
        console.log("Borrow amount:", borrowAmount);
        
        microManager.borrow(collateralAmount, borrowAmount);

        console.log("=== After Borrow ===");
        console.log("Vault USDC balance:", ERC20(USDC).balanceOf(BORING_VAULT));
        console.log("Vault WETH balance:", ERC20(WETH).balanceOf(BORING_VAULT));
        console.log("Vault aWETH balance:", ERC20(AWETH).balanceOf(BORING_VAULT));

        // Test partial repay first (repay half the debt)
        uint256 partialRepayAmount = borrowAmount / 2; // 2000 USDC
        uint256 partialWithdrawAmount = ERC20(AWETH).balanceOf(BORING_VAULT) / 2; // Half the collateral
        
        console.log("=== Testing Partial Repay ===");
        console.log("Partial repay amount:", partialRepayAmount);
        console.log("Partial withdraw amount:", partialWithdrawAmount);
        
        microManager.repay(partialRepayAmount, partialWithdrawAmount);

        console.log("=== After Partial Repay ===");
        console.log("Vault USDC balance:", ERC20(USDC).balanceOf(BORING_VAULT));
        console.log("Vault WETH balance:", ERC20(WETH).balanceOf(BORING_VAULT));
        console.log("Vault aWETH balance:", ERC20(AWETH).balanceOf(BORING_VAULT));

        // Now settle the rest
        console.log("=== Testing Full Settle ===");
        microManager.settle();

        console.log("=== After Settle (Final) ===");
        console.log("Vault USDC balance:", ERC20(USDC).balanceOf(BORING_VAULT));
        console.log("Vault WETH balance:", ERC20(WETH).balanceOf(BORING_VAULT));
        console.log("Vault aWETH balance:", ERC20(AWETH).balanceOf(BORING_VAULT));

        vm.stopBroadcast();
    }
}