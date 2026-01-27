// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

/**
 *  source .env && forge script script/utils/Mainnet/setCompleteWithdrawPermissions.s.sol:set --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */

contract set is Script {
    uint8 public constant SOLVER_ORIGIN_ROLE = 33;
    //BoringSolver public constant SOLVER = BoringSolver(0x4e98f2d2DC317076De218947A5f540BE64f0cB3B);
   

    function run() external {
        // MoveFundsUSDC
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        address admin = vm.envAddress("MAINNET_DEPLOYER_ADDRESS");

        RolesAuthority rolesAuthorityETHAgent = RolesAuthority(
            0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446
        );
        
        if (
            !rolesAuthorityETHAgent.doesUserHaveRole(
                admin,
                SOLVER_ORIGIN_ROLE
            )
        ) {
            rolesAuthorityETHAgent.setUserRole(
                admin,
                SOLVER_ORIGIN_ROLE,
                true
            );
            console.log("Granted SOLVER_ORIGIN_ROLE to", admin);
        } else {
            console.log("Address already has SOLVER_ORIGIN_ROLE");
        }

       /*

         if (
            rolesAuthorityETHAgent.doesUserHaveRole(
                admin,
                SOLVER_ORIGIN_ROLE
            )
        ) {
            rolesAuthorityETHAgent.setUserRole(
                admin,
                SOLVER_ORIGIN_ROLE,
                false
            );
            console.log("Revoked SOLVER_ORIGIN_ROLE from", admin);
        } else {
            console.log("Address already Revoked SOLVER_ORIGIN_ROLE");
        }
    */

        vm.stopBroadcast();
    }


    
}
