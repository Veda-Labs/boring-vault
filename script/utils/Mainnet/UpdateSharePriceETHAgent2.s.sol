// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

/**
 *  source .env && forge script script/utils/Mainnet/UpdateSharePriceETHAgent2.s.sol:UpdateSharePrice --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */

contract UpdateSharePrice is Script {
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 public constant PAUSER_ROLE = 5;
    AccountantWithRateProviders constant ACCOUNTANT_AGENT2 = AccountantWithRateProviders(0x6c0EAFB69D8F858397077f900edEc01345Aa0FFF);
    uint96 public constant NEW_EXCHANGE_RATE = 1e18;

    function run() external {
        // MoveFundsUSDC
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        address admin = vm.envAddress("MAINNET_DEPLOYER_ADDRESS");

        RolesAuthority rolesAuthorityETHAgent2 = RolesAuthority(
            0x0951A4fa55DD8F20B1eab2021cD8693D32f410B5
        );
        /*
        if (
            !rolesAuthorityETHAgent2.doesUserHaveRole(
                admin,
                UPDATE_EXCHANGE_RATE_ROLE
            )
        ) {
            rolesAuthorityETHAgent2.setUserRole(
                admin,
                UPDATE_EXCHANGE_RATE_ROLE,
                true
            );
            console.log("Granted UPDATE_EXCHANGE_RATE_ROLE to", admin);
        } else {
            console.log("Address already has UPDATE_EXCHANGE_RATE_ROLE");
        }

        // 21600 standard delay
        //ACCOUNTANT_AGENT2.updateDelay(0);
        ACCOUNTANT_AGENT2.updateExchangeRate(NEW_EXCHANGE_RATE);
        //ACCOUNTANT_AGENT2.updateDelay(21600);

         if (
            rolesAuthorityETHAgent2.doesUserHaveRole(
                admin,
                UPDATE_EXCHANGE_RATE_ROLE
            )
        ) {
            rolesAuthorityETHAgent2.setUserRole(
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
            !rolesAuthorityETHAgent2.doesUserHaveRole(
                admin,
                PAUSER_ROLE
            )
        ) {
            rolesAuthorityETHAgent2.setUserRole(
                admin,
                PAUSER_ROLE,
                true
            );
            console.log("Granted PAUSER_ROLE to", admin);
        } else {
            console.log("Address already has PAUSER_ROLE");
        }


        ACCOUNTANT_AGENT2.unpause();

         if (
            rolesAuthorityETHAgent2.doesUserHaveRole(
                admin,
                PAUSER_ROLE
            )
        ) {
            rolesAuthorityETHAgent2.setUserRole(
                admin,
                PAUSER_ROLE,
                false
            );
            console.log("Revoked PAUSER_ROLE from", admin);
        } else {
            console.log("Address already Revoked PAUSER_ROLE");
        }       
    


        vm.stopBroadcast();
    }


    
}
