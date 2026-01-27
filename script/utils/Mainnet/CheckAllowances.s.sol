// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {console2} from "forge-std/console2.sol";

/*
 * source .env && forge script script/utils/Mainnet/CheckAllowances.s.sol:CheckAllowances --rpc-url mainnet -vvvv
 */

contract CheckAllowances is Script {
    // Agent vault addresses
    address constant BORING_VAULT = 0x6638968ACBA85A6445D3909F4d0520F7D2501061;

    // Token addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

    // Protocol addresses
    address constant SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant AAVE_V3_POOL = 0x4e033931ad43597d96D6bcc25c280717730B58B1;

    function run() external view {
        console2.log("=== Checking Token Allowances for BoringVault ===");
        console2.log("BoringVault:", BORING_VAULT);
        console2.log("");

        // Check SwapRouter02 allowances
        console2.log("--- SwapRouter02 Allowances ---");
        console2.log("SwapRouter02:", SWAP_ROUTER_02);
        uint256 usdcSwapAllowance = ERC20(USDC).allowance(BORING_VAULT, SWAP_ROUTER_02);
        uint256 susdeSwapAllowance = ERC20(SUSDE).allowance(BORING_VAULT, SWAP_ROUTER_02);
        console2.log("USDC allowance:", usdcSwapAllowance);
        console2.log("sUSDE allowance:", susdeSwapAllowance);
        console2.log("");

        // Check Aave V3 Pool allowances
        console2.log("--- Aave V3 Pool Allowances ---");
        console2.log("Aave V3 Pool:", AAVE_V3_POOL);
        uint256 usdcAaveAllowance = ERC20(USDC).allowance(BORING_VAULT, AAVE_V3_POOL);
        uint256 susdeAaveAllowance = ERC20(SUSDE).allowance(BORING_VAULT, AAVE_V3_POOL);
        console2.log("USDC allowance:", usdcAaveAllowance);
        console2.log("sUSDE allowance:", susdeAaveAllowance);
        console2.log("");

        // Check if any allowances are insufficient
        console2.log("=== Allowance Status ===");
        bool allGood = true;

        if (usdcSwapAllowance == 0) {
            console2.log("WARNING: USDC allowance for SwapRouter02 is 0");
            allGood = false;
        } else {
            console2.log("OK: USDC allowance for SwapRouter02");
        }

        if (susdeSwapAllowance == 0) {
            console2.log("WARNING: sUSDE allowance for SwapRouter02 is 0");
            allGood = false;
        } else {
            console2.log("OK: sUSDE allowance for SwapRouter02");
        }

        if (usdcAaveAllowance == 0) {
            console2.log("WARNING: USDC allowance for Aave V3 Pool is 0");
            allGood = false;
        } else {
            console2.log("OK: USDC allowance for Aave V3 Pool");
        }

        if (susdeAaveAllowance == 0) {
            console2.log("WARNING: sUSDE allowance for Aave V3 Pool is 0");
            allGood = false;
        } else {
            console2.log("OK: sUSDE allowance for Aave V3 Pool");
        }

        console2.log("");
        if (allGood) {
            console2.log("All allowances are set!");
        } else {
            console2.log("Run ApproveTokensUSDC.s.sol to set missing allowances");
        }
    }
}
