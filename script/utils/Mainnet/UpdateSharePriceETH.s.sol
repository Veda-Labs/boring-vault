// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

/*
 *  source .env && forge script script/utils/Mainnet/UpdateSharePriceETH.s.sol:UpdateSharePrice --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */

contract UpdateSharePrice is Script {
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 public constant PAUSER_ROLE = 5;
    AccountantWithRateProviders constant ACCOUNTANT = AccountantWithRateProviders(0x5c4FBdA6bEc35DEeAD2bC54e7EeFC88a483a89B6);
    uint96 public constant NEW_EXCHANGE_RATE = 1e18; // 1 ETH

    function run() external {
        // MoveFundsUSDC
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        address admin = vm.envAddress("MAINNET_DEPLOYER_ADDRESS");

        RolesAuthority rolesAuthorityETHAgent1 = RolesAuthority(
            0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446
        );
   
        if (
            !rolesAuthorityETHAgent1.doesUserHaveRole(
                admin,
                UPDATE_EXCHANGE_RATE_ROLE
            )
        ) {
            rolesAuthorityETHAgent1.setUserRole(
                admin,
                UPDATE_EXCHANGE_RATE_ROLE,
                true
            );
            console.log("Granted UPDATE_EXCHANGE_RATE_ROLE to", admin);
        } else {
            console.log("Address already has UPDATE_EXCHANGE_RATE_ROLE");
        }

        // 21600 standard delay
        //ACCOUNTANT_AGENT1.updateDelay(0);

        //ACCOUNTANT.updateExchangeRate(NEW_EXCHANGE_RATE);
        //ACCOUNTANT_AGENT1.updateDelay(21600);
        /*
         if (
            rolesAuthorityETHAgent1.doesUserHaveRole(
                admin,
                UPDATE_EXCHANGE_RATE_ROLE
            )
        ) {
            rolesAuthorityETHAgent1.setUserRole(
                admin,
                UPDATE_EXCHANGE_RATE_ROLE,
                false
            );
            console.log("Revoked UPDATE_EXCHANGE_RATE_ROLE from", admin);
        } else {
            console.log("Address already Revoked UPDATE_EXCHANGE_RATE_ROLE");
        }
   
   */
        /// unpause all
         

         if (
            !rolesAuthorityETHAgent1.doesUserHaveRole(
                admin,
                PAUSER_ROLE
            )
        ) {
            rolesAuthorityETHAgent1.setUserRole(
                admin,
                PAUSER_ROLE,
                true
            );
            console.log("Granted PAUSER_ROLE to", admin);
        } else {
            console.log("Address already has PAUSER_ROLE");
        }


        ACCOUNTANT.unpause();
/*

         if (
            rolesAuthorityETHAgent1.doesUserHaveRole(
                admin,
                PAUSER_ROLE
            )
        ) {
            rolesAuthorityETHAgent1.setUserRole(
                admin,
                PAUSER_ROLE,
                false
            );
            console.log("Revoked PAUSER_ROLE from", admin);
        } else {
            console.log("Address already Revoked PAUSER_ROLE");
        }       
*/


    

        vm.stopBroadcast();
    }


    
}
