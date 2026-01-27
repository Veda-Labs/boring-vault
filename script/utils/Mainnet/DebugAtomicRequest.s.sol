// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

// source .env && forge script script/utils/Mainnet/DebugAtomicRequest.s.sol:DebugAtomicRequest --rpc-url $MAINNET_RPC_URL -vvvv --broadcast

contract DebugAtomicRequest is Script {
    address constant BORING_SOLVER = 0x7fF7348e4908654fdF7a465356CB7E4Fa09C4963;
    address constant TELLER = 0x744C20d4F96667a38C4375B16aC88141257169F0; // iPrvlUSDC Teller (from webhook)

    // Real withdrawal request from webhook data
    // Request ID: 0x99ba48632d6e5145cace3457b7a068522fe87e9d3226ee62fb5fad59f54fff68
    uint96 constant NONCE = 2;
    address constant USER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40;
    address constant ASSET_OUT = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    uint128 constant AMOUNT_OF_SHARES = 1;
    uint128 constant AMOUNT_OF_ASSETS = 1;
    uint40 constant CREATION_TIME = 1760328071;
    uint24 constant SECONDS_TO_MATURITY = 0;
    uint24 constant SECONDS_TO_DEADLINE = 9000000;

    bool constant COVER_DEFICIT = true;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console2.log("=== Boring Redeem Solve Debug ===");
        console2.log("Boring Solver:", BORING_SOLVER);
        console2.log("Teller:", TELLER);
        console2.log("User:", USER);
        console2.log("Asset Out (USDC):", ASSET_OUT);
        console2.log("Nonce:", uint256(NONCE));
        console2.log("Amount of Shares:", uint256(AMOUNT_OF_SHARES));
        console2.log("Amount of Assets:", uint256(AMOUNT_OF_ASSETS));
        console2.log("Creation Time:", uint256(CREATION_TIME));
        console2.log("Seconds to Maturity:", uint256(SECONDS_TO_MATURITY));
        console2.log("Seconds to Deadline:", uint256(SECONDS_TO_DEADLINE));
        console2.log("Cover Deficit:", COVER_DEFICIT);

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

        BoringSolver solver = BoringSolver(BORING_SOLVER);

        // Approve BoringSolver to spend USDC
        console2.log("\nApproving BoringSolver to spend USDC...");
        ERC20(ASSET_OUT).approve(BORING_SOLVER, type(uint256).max);
        console2.log("Approval granted");

        console2.log("\nCalling boringRedeemSolve...");
        try solver.boringRedeemSolve(requests, TELLER, COVER_DEFICIT) {
            console2.log("\nSuccessfully executed boringRedeemSolve!");
        } catch Error(string memory reason) {
            console2.log("\nFailed with reason:", reason);
        } catch (bytes memory returnData) {
            console2.log("\nFailed with data:");
            console2.logBytes(returnData);
        }

        vm.stopBroadcast();
    }
}
