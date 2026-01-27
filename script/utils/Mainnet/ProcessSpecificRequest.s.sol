// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";

/**
 * @title ProcessSpecificRequest
 * @notice Script to process a specific withdrawal request from the BoringOnChainQueue
 * @dev Usage: forge script script/ProcessSpecificRequest.s.sol:ProcessSpecificRequest --rpc-url $RPC_URL --broadcast
 */
contract ProcessSpecificRequest is Script {
    // Contract addresses
    address constant BORING_QUEUE = 0x66Afbd5b2558B34af02c9Cbe61bfc409C909F375;
    address constant BORING_SOLVER = 0x4e98f2d2DC317076De218947A5f540BE64f0cB3B;
    address constant TELLER = 0x68044594BC73722AC6D9Be0d8FfA918a6D50854c; // iPrvlETH Teller
    // Request data from the OnChainWithdrawRequested event (NEW REQUEST)
    bytes32 constant REQUEST_ID = 0x9c365d96c1efcca4919477dc39dc4f973d9ae73d55485f4f889cb9b0ac6f0321;
    address constant USER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40; // This is the deployer address
    address constant ASSET_OUT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    uint96 constant NONCE = 2;
    uint128 constant AMOUNT_OF_SHARES = 1000000001000000000000000000;
    uint128 constant AMOUNT_OF_ASSETS = 1000000001000000;
    uint40 constant CREATION_TIME = 1760514479;
    uint24 constant SECONDS_TO_MATURITY = 0;
    uint24 constant SECONDS_TO_DEADLINE = 999999; // ~11.5 days
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Processing specific withdrawal request:");
        console2.log("Request ID:");
        console2.logBytes32(REQUEST_ID);
        console2.log("User:", USER);
        console2.log("Asset Out (WETH):", ASSET_OUT);
        console2.log("Shares:", uint256(AMOUNT_OF_SHARES));
        console2.log("Assets:", uint256(AMOUNT_OF_ASSETS));
        console2.log("Creation Time:", uint256(CREATION_TIME));
        console2.log("Seconds to Maturity:", uint256(SECONDS_TO_MATURITY));
        console2.log("Seconds to Deadline:", uint256(SECONDS_TO_DEADLINE));
        
        // Create the request array
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
        
        // Get the solver contract
        BoringSolver solver = BoringSolver(BORING_SOLVER);
        
        // Process the request
        console2.log("\nProcessing request through solver...");
        console2.log("Using teller:", TELLER);
        console2.log("Cover deficit: false");
        
        try solver.boringRedeemSolve(requests, TELLER, false) {
            console2.log("\nSuccessfully processed withdrawal request!");
        } catch Error(string memory reason) {
            console2.log("\nFailed to process request:", reason);
        } catch (bytes memory returnData) {
            console2.log("\nFailed to process request with data:");
            console2.logBytes(returnData);
        }
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Alternative function to process with coverDeficit = true
     */
    function runWithoutCoverDeficit() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console2.log("Processing specific withdrawal request (with deficit coverage):");
        console2.log("Request ID:");
        console2.logBytes32(REQUEST_ID);
        console2.log("User:", USER);
        console2.log("Asset Out (WETH):", ASSET_OUT);
        console2.log("Shares:", uint256(AMOUNT_OF_SHARES));
        
        // Create the request array
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
        
        // Get the solver contract
        BoringSolver solver = BoringSolver(BORING_SOLVER);
        
        // Process the request with coverDeficit = true
        console2.log("\nProcessing request through solver...");
        console2.log("Using teller:", TELLER);
        console2.log("Cover deficit: true");
        
        solver.boringRedeemSolve(requests, TELLER, false);
        console2.log("\nSuccessfully processed withdrawal request with deficit coverage!");
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Check if the request is still in the queue
     */
    function checkRequest() external view {
        BoringOnChainQueue queue = BoringOnChainQueue(BORING_QUEUE);
        
        bytes32[] memory requestIds = queue.getRequestIds();
        
        console2.log("Total requests in queue:", requestIds.length);
        
        bool found = false;
        for (uint256 i = 0; i < requestIds.length; i++) {
            if (requestIds[i] == REQUEST_ID) {
                found = true;
                console2.log("Request found at index:", i);
                console2.logBytes32(requestIds[i]);
                break;
            }
        }
        
        if (!found) {
            console2.log("Request not found in queue (may have been processed already)");
        }
    }
}