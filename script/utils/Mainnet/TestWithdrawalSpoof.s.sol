// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";

contract TestWithdrawalSpoof is Script {
    // ETH System addresses
    address constant BORING_SOLVER = 0x4e98f2d2DC317076De218947A5f540BE64f0cB3B; // ETH BoringSolver
    address constant BORING_QUEUE = 0x66Afbd5b2558B34af02c9Cbe61bfc409C909F375; // ETH BoringQueue
    address constant SPOOF_SENDER = 0xdDEbf1BCC0597415089475c78125E2A6ec481b1C;
    address constant TELLER = 0x68044594BC73722AC6D9Be0d8FfA918a6D50854c; // iPrvlETH Teller
    bytes32 constant WITHDRAWAL_ID = 0x5ed5126b4ef1adfa8adc116583ae0533e7e342d095225e38a104e780272a3995;

    // Actual values from OnChainWithdrawRequested event:
    address constant ACTUAL_USER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    function run() external {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        
        console2.log("Spoofing address:", SPOOF_SENDER);
        console2.log("BoringSolver:", BORING_SOLVER);
        console2.log("BoringQueue:", BORING_QUEUE);
        console2.log("Teller address:", TELLER);
        console2.log("Withdrawal ID:");
        console2.logBytes32(WITHDRAWAL_ID);

        vm.startPrank(SPOOF_SENDER);

        BoringSolver solver = BoringSolver(BORING_SOLVER);

        // Create withdrawal request array with actual event data
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);

        requests[0] = BoringOnChainQueue.OnChainWithdraw({
            nonce: 9,
            user: ACTUAL_USER,
            assetOut: WETH,
            amountOfShares: 20000000000000000,
            amountOfAssets: 19980947739754237,
            creationTime: 1763040011,
            secondsToMaturity: 0,
            secondsToDeadline: 259200
        });

        console2.log("Calling boringRedeemSolve...");
        console2.log("User:", ACTUAL_USER);
        console2.log("Asset Out (WETH):", WETH);
        console2.log("Amount of Shares:", uint256(20000000000000000));
        console2.log("Amount of Assets:", uint256(19980947739754237));
        
        try solver.boringRedeemSolve(requests, TELLER, false) {
            console2.log("Transaction successful!");
        } catch Error(string memory reason) {
            console2.log("Transaction failed with reason:", reason);
        } catch (bytes memory returnData) {
            console2.log("Transaction failed");
            console2.logBytes(returnData);
        }
        
        vm.stopPrank();
    }
}