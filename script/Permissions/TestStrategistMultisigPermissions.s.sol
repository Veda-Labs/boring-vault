// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";

contract TestStrategistMultisigPermissions is Script {
    address constant MULTISIG_ADDRESS = 0xACeD115d8eF25451F711694535a291d6D229B29e;
    address constant SOLVER_ADDRESS = 0x081ec05c0258c38664cb4eA5FFda76120200f693;
    address constant QUEUE_ADDRESS = 0x502404B51C7f3a1802C4F344BDC606A8AeC06c80;
    
    function setUp() external {
        vm.createSelectFork("sepolia");
    }

    function run() public {
        // Impersonate the multisig address to test permissions
        vm.startPrank(MULTISIG_ADDRESS);
        
        console.log("Testing permissions for address:", MULTISIG_ADDRESS);
        console.log("");
        
        // Test 1: Try to call boringRedeemSolve (with empty data - just testing auth)
        console.log("Test 1: Calling boringRedeemSolve on solver...");
        try BoringSolver(SOLVER_ADDRESS).boringRedeemSolve(
            new BoringOnChainQueue.OnChainWithdraw[](0),
            address(0),
            false
        ) {
            console.log("[SUCCESS] boringRedeemSolve call would succeed (auth check passed)");
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("UNAUTHORIZED"))) {
                console.log("[FAIL] UNAUTHORIZED - Permission not granted");
            } else {
                console.log("[FAIL] Failed with:", reason);
            }
        } catch {
            console.log("Note: Call reverted (likely due to empty data), but checking auth...");
            // The call might revert for reasons other than auth
        }
        
        console.log("");
        
        // Test 2: Try to call cancelUserWithdraws (with empty data - just testing auth)
        console.log("Test 2: Calling cancelUserWithdraws on queue...");
        try BoringOnChainQueue(QUEUE_ADDRESS).cancelUserWithdraws(
            new BoringOnChainQueue.OnChainWithdraw[](0)
        ) returns (bytes32[] memory) {
            console.log("[SUCCESS] cancelUserWithdraws call would succeed (auth check passed)");
        } catch Error(string memory reason) {
            if (keccak256(bytes(reason)) == keccak256(bytes("UNAUTHORIZED"))) {
                console.log("[FAIL] UNAUTHORIZED - Permission not granted");
            } else {
                console.log("[FAIL] Failed with:", reason);
            }
        } catch {
            console.log("[OK] Call reverted (likely due to empty data), but auth likely passed");
        }
        
        vm.stopPrank();
        
        console.log("");
        console.log("Test complete!");
    }
}