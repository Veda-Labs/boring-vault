// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

// source .env && forge script script/utils/Mainnet/SolveWithdrawalWithDeficit.s.sol:SolveWithdrawalWithDeficit --rpc-url $MAINNET_RPC_URL --broadcast

contract SolveWithdrawalWithDeficit is Script {
    // iPrvlClientVaultUSDC contracts
    address constant BORING_SOLVER = 0x7fF7348e4908654fdF7a465356CB7E4Fa09C4963;
    address constant TELLER = 0x744C20d4F96667a38C4375B16aC88141257169F0;
    address constant ASSET_OUT = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC

    // Withdrawal request details
    uint96 constant NONCE = 11;
    address constant USER = 0xdDEbf1BCC0597415089475c78125E2A6ec481b1C;
    uint128 constant AMOUNT_OF_SHARES = 4584500;
    uint128 constant AMOUNT_OF_ASSETS = 4571246;
    uint40 constant CREATION_TIME = 1763067947;
    uint24 constant SECONDS_TO_MATURITY = 0;
    uint24 constant SECONDS_TO_DEADLINE = 259200;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console2.log("=== Solving Withdrawal with Deficit ===");
        console2.log("Solver (deployer):", deployer);
        console2.log("BoringSolver:", BORING_SOLVER);
        console2.log("Teller:", TELLER);
        console2.log("");

        ERC20 usdc = ERC20(ASSET_OUT);
        BoringSolver solver = BoringSolver(BORING_SOLVER);

        // Check current USDC balance and allowance
        uint256 balance = usdc.balanceOf(deployer);
        uint256 currentAllowance = usdc.allowance(deployer, BORING_SOLVER);

        console2.log("Deployer USDC balance:", balance);
        console2.log("Current allowance to BoringSolver:", currentAllowance);
        console2.log("");

        // Approve BoringSolver to spend EXACTLY the deficit amount
        uint256 approvalAmount = 2847; // Exact deficit amount
        console2.log("Approving BoringSolver to spend EXACTLY", approvalAmount, "USDC...");
        usdc.approve(BORING_SOLVER, approvalAmount);
        console2.log("Approval complete!");
        console2.log("");

        // Build withdrawal request
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = BoringOnChainQueue.OnChainWithdraw({
            nonce: NONCE,
            user: USER,
            assetOut: ASSET_OUT,
            amountOfShares: AMOUNT_OF_SHARES,
            amountOfAssets: AMOUNT_OF_ASSETS,
            creationTime: CREATION_TIME,
            secondsToMaturity: SECONDS_TO_MATURITY,
            secondsToDeadline: SECONDS_TO_DEADLINE
        });

        console2.log("Solving withdrawal request with coverDeficit=true...");
        console2.log("Request details:");
        console2.log("  - Nonce:", uint256(NONCE));
        console2.log("  - User:", USER);
        console2.log("  - Shares:", uint256(AMOUNT_OF_SHARES));
        console2.log("  - Assets:", uint256(AMOUNT_OF_ASSETS));
        console2.log("");

        try solver.boringRedeemSolve(requests, TELLER, true) { // coverDeficit = true
            console2.log("SUCCESS! Withdrawal solved.");
        } catch Error(string memory reason) {
            console2.log("FAILED with reason:", reason);
        } catch (bytes memory returnData) {
            console2.log("FAILED with data:");
            console2.logBytes(returnData);
        }

        vm.stopBroadcast();
    }
}
