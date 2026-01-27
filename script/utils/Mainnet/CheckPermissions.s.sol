// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";

contract CheckPermissions is Script {
    address constant ROLES_AUTHORITY = 0x5fac892A947296eDf36f6dBe199F2689e9bEc9D2;
    address constant BORING_QUEUE = 0x7D2b993CfC4048b85EC44B95Dc01a4C6B4E47b25;
    address constant BORING_SOLVER = 0x7fF7348e4908654fdF7a465356CB7E4Fa09C4963;
    
    uint8 constant ONLY_QUEUE_ROLE = 32;
    
    function run() external {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);
        
        RolesAuthority rolesAuthority = RolesAuthority(ROLES_AUTHORITY);
        
        console2.log("=== Checking Permissions ===");
        console2.log("RolesAuthority:", ROLES_AUTHORITY);
        console2.log("BoringQueue:", BORING_QUEUE);
        console2.log("BoringSolver:", BORING_SOLVER);
        console2.log("");
        
        // Check if queue has ONLY_QUEUE_ROLE
        bool queueHasRole = rolesAuthority.doesUserHaveRole(BORING_QUEUE, ONLY_QUEUE_ROLE);
        console2.log("Does BoringQueue have ONLY_QUEUE_ROLE?", queueHasRole);
        
        // Check if ONLY_QUEUE_ROLE has capability to call boringSolve
        bytes4 boringSolveSelector = BoringSolver.boringSolve.selector;
        bool roleHasCapability = rolesAuthority.doesRoleHaveCapability(
            ONLY_QUEUE_ROLE, 
            BORING_SOLVER, 
            boringSolveSelector
        );
        console2.log("Does ONLY_QUEUE_ROLE have capability to call boringSolve?", roleHasCapability);
        
        // Direct check if queue can call boringSolve
        bool canCall = rolesAuthority.canCall(BORING_QUEUE, BORING_SOLVER, boringSolveSelector);
        console2.log("Can BoringQueue directly call boringSolve?", canCall);
        
        // Check what roles the queue has
        console2.log("\n=== Checking all roles for BoringQueue ===");
        for (uint8 i = 0; i < 40; i++) {
            if (rolesAuthority.doesUserHaveRole(BORING_QUEUE, i)) {
                console2.log("BoringQueue has role:", i);
                
                // Check if this role can call boringSolve
                if (rolesAuthority.doesRoleHaveCapability(i, BORING_SOLVER, boringSolveSelector)) {
                    console2.log("  -> Role", i, "CAN call boringSolve");
                }
            }
        }
        
        // Check if boringSolve is public
        bool isPublic = rolesAuthority.isCapabilityPublic(BORING_SOLVER, boringSolveSelector);
        console2.log("\nIs boringSolve public?", isPublic);
    }
}