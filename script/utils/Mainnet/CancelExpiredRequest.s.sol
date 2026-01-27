// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";

/**
 * @title CancelExpiredRequest
 * @notice Script to cancel expired withdrawal requests from the BoringOnChainQueue
 * @dev Usage: forge script script/CancelExpiredRequest.s.sol:CancelExpiredRequest --rpc-url $RPC_URL --broadcast
 * source .env && forge script script/utils/Mainnet/CancelExpiredRequest.s.sol:CancelExpiredRequest --rpc-url $MAINNET_RPC_URL --broadcast -vv
 
 */
contract CancelExpiredRequest is Script {
    // Contract addresses
    address constant BORING_QUEUE = 0x66Afbd5b2558B34af02c9Cbe61bfc409C909F375;
    RolesAuthority rolesAuthorityETH = RolesAuthority(0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446);
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;

    
    // Request data from the expired OnChainWithdrawRequested event
    bytes32 constant REQUEST_ID = 0x5ed5126b4ef1adfa8adc116583ae0533e7e342d095225e38a104e780272a3995;
    address constant USER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40;
    address constant ASSET_OUT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
    uint96 constant NONCE = 9;
    uint128 constant AMOUNT_OF_SHARES = 20000000000000000;
    uint128 constant AMOUNT_OF_ASSETS = 19980947739754237;
    uint40 constant CREATION_TIME = 1763040011;
    uint24 constant SECONDS_TO_MATURITY = 0;
    uint24 constant SECONDS_TO_DEADLINE = 259200; // 3 days
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address admin = vm.envAddress("MAINNET_DEPLOYER_ADDRESS");
        
        console2.log("Canceling expired withdrawal request:");
        console2.log("Request ID:");
        console2.logBytes32(REQUEST_ID);
        console2.log("User:", USER);
        console2.log("Asset Out (WETH):", ASSET_OUT);
        console2.log("Shares:", uint256(AMOUNT_OF_SHARES));
        
        // Calculate deadline
        uint256 deadline = CREATION_TIME + SECONDS_TO_MATURITY + SECONDS_TO_DEADLINE;
        console2.log("Deadline timestamp:", deadline);
        console2.log("Current timestamp:", block.timestamp);
        
        if (block.timestamp > deadline) {
            console2.log("Request has expired (deadline passed)");
        }

        if(!rolesAuthorityETH.doesUserHaveRole(admin, STRATEGIST_MULTISIG_ROLE)) {
            rolesAuthorityETH.setUserRole(admin, STRATEGIST_MULTISIG_ROLE, true);
        } 
        // Create the request to cancel
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
        
        // Get the queue contract
        BoringOnChainQueue queue = BoringOnChainQueue(BORING_QUEUE);
        
        // Cancel the expired request
        console2.log("\nCanceling expired request...");
        
        try queue.cancelUserWithdraws(requests) {
            console2.log("Successfully canceled expired withdrawal request!");
            console2.log("Shares returned to user:", USER);
        } catch Error(string memory reason) {
            console2.log("Failed to cancel request:", reason);
        } catch (bytes memory returnData) {
            console2.log("Failed to cancel request with data:");
            console2.logBytes(returnData);
        }
        if(rolesAuthorityETH.doesUserHaveRole(msg.sender, STRATEGIST_MULTISIG_ROLE)) {
            rolesAuthorityETH.setUserRole(msg.sender, STRATEGIST_MULTISIG_ROLE, false);
        } 
        
        vm.stopBroadcast();
        
    }
    
    /**
     * @notice Check if the request is still in the queue after cancellation
     */
    function checkRequestAfterCancel() external view {
        BoringOnChainQueue queue = BoringOnChainQueue(BORING_QUEUE);
        
        bytes32[] memory requestIds = queue.getRequestIds();
        
        console2.log("Total requests in queue after cancel:", requestIds.length);
        
        bool found = false;
        for (uint256 i = 0; i < requestIds.length; i++) {
            if (requestIds[i] == REQUEST_ID) {
                found = true;
                console2.log("Request still found at index:", i);
                break;
            }
        }
        
        if (!found) {
            console2.log("Request successfully removed from queue");
        }
    }
    
    /**
     * @notice Cancel as the user directly (if msg.sender is the user)
     */
    function cancelAsUser() external {
        // This function should be called by the actual user who made the request
        vm.startBroadcast();
        
        console2.log("Canceling withdrawal request as user:", msg.sender);
        
        if (msg.sender != USER) {
            console2.log("WARNING: You are not the original user of this request");
            console2.log("Expected user:", USER);
            console2.log("Current sender:", msg.sender);
        }
        
        // Create the request to cancel
        BoringOnChainQueue.OnChainWithdraw memory request = BoringOnChainQueue.OnChainWithdraw({
            nonce: NONCE,
            user: USER,
            assetOut: ASSET_OUT,
            amountOfShares: AMOUNT_OF_SHARES,
            amountOfAssets: AMOUNT_OF_ASSETS,
            creationTime: CREATION_TIME,
            secondsToMaturity: SECONDS_TO_MATURITY,
            secondsToDeadline: SECONDS_TO_DEADLINE
        });
        
        // Get the queue contract
        BoringOnChainQueue queue = BoringOnChainQueue(BORING_QUEUE);
        
        // User can cancel their own request
        console2.log("\nUser canceling their own request...");
        
        queue.cancelOnChainWithdraw(request);
        console2.log("Successfully canceled withdrawal request!");
        console2.log("Shares returned to:", USER);
        
        vm.stopBroadcast();
    }
}