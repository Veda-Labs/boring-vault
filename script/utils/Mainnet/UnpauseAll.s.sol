// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

/*
 *  source .env && forge script script/utils/Mainnet/UnpauseAll.s.sol:UnpauseAll --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */

contract UnpauseAll is Script {
 
    uint8 public constant PAUSER_ROLE = 5;


    AccountantWithRateProviders constant ACCOUNTANT_iPrvlUSDC = AccountantWithRateProviders(0xDA1B54c28c32187C51e961e8B6ba9eFAFd1AD98e);
    AccountantWithRateProviders constant ACCOUNTANT_iPrvlUSDCAgent1 = AccountantWithRateProviders(0xc8C3fAc6d267002868Dd5D528dA15b72Dbb681A5);
    AccountantWithRateProviders constant ACCOUNTANT_iPrvlUSDCAgent2 = AccountantWithRateProviders(0x5b27200CCFE7662b539EEE51844DA25f1297F30f);
    AccountantWithRateProviders constant ACCOUNTANT_iPrvlETH = AccountantWithRateProviders(0x5c4FBdA6bEc35DEeAD2bC54e7EeFC88a483a89B6);
    AccountantWithRateProviders constant ACCOUNTANT_iPrvlETHAgent1 = AccountantWithRateProviders(0x6520E0A84176573913d8EE07f2dceE7955c76f90);
    AccountantWithRateProviders constant ACCOUNTANT_iPrvlETHAgent2 = AccountantWithRateProviders(0x6c0EAFB69D8F858397077f900edEc01345Aa0FFF);

    RolesAuthority constant ROLES_AUTHORITY_iPrvlUSDC = RolesAuthority(0x5fac892A947296eDf36f6dBe199F2689e9bEc9D2);
    RolesAuthority constant ROLES_AUTHORITY_iPrvlUSDCAgent1 = RolesAuthority(0x58b25D1D07C5DB365a1686f6d824B585808b8dA2);
    RolesAuthority constant ROLES_AUTHORITY_iPrvlUSDCAgent2 = RolesAuthority(0xf84B1eF921D7aA21609C5f09E65C8067a048793C);
    RolesAuthority constant ROLES_AUTHORITY_iPrvlETH = RolesAuthority(0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446);      
    RolesAuthority constant ROLES_AUTHORITY_iPrvlETHAgent1 = RolesAuthority(0x3282A25B08a775FBa2FC6dE3fEe7cB635dC6671e);
    RolesAuthority constant ROLES_AUTHORITY_iPrvlETHAgent2 = RolesAuthority(0x0951A4fa55DD8F20B1eab2021cD8693D32f410B5);

    struct AccountantWithRoles {
        AccountantWithRateProviders accountant;
        RolesAuthority rolesAuthority;
    }

     struct AccountantState {
        address payoutAddress;
        uint96 highwaterMark;
        uint128 feesOwedInBase;
        uint128 totalSharesLastUpdate;
        uint96 exchangeRate;
        uint16 allowedExchangeRateChangeUpper;
        uint16 allowedExchangeRateChangeLower;
        uint64 lastUpdateTimestamp;
        bool isPaused;
        uint24 minimumUpdateDelayInSeconds;
        uint16 platformFee;
        uint16 performanceFee;
    }

    function run() external {

        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        address admin = vm.envAddress("MAINNET_DEPLOYER_ADDRESS");

        AccountantWithRoles[] memory accountantsWithRoles = new AccountantWithRoles[](6);
        accountantsWithRoles[0] = AccountantWithRoles(ACCOUNTANT_iPrvlUSDC, ROLES_AUTHORITY_iPrvlUSDC);
        accountantsWithRoles[1] = AccountantWithRoles(ACCOUNTANT_iPrvlUSDCAgent1, ROLES_AUTHORITY_iPrvlUSDCAgent1);
        accountantsWithRoles[2] = AccountantWithRoles(ACCOUNTANT_iPrvlUSDCAgent2, ROLES_AUTHORITY_iPrvlUSDCAgent2);
        accountantsWithRoles[3] = AccountantWithRoles(ACCOUNTANT_iPrvlETH, ROLES_AUTHORITY_iPrvlETH);
        accountantsWithRoles[4] = AccountantWithRoles(ACCOUNTANT_iPrvlETHAgent1, ROLES_AUTHORITY_iPrvlETHAgent1);
        accountantsWithRoles[5] = AccountantWithRoles(ACCOUNTANT_iPrvlETHAgent2, ROLES_AUTHORITY_iPrvlETHAgent2);

        //for each of the 6 accountants and role authorities
        for (uint256 i = 0; i < accountantsWithRoles.length; i++) {
            AccountantWithRoles memory awr = accountantsWithRoles[i];
            RolesAuthority AUTH = awr.rolesAuthority;
            AccountantWithRateProviders ACCOUNTANT = awr.accountant;

            (
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                ,
                bool isPaused,
                ,
                ,
            ) = ACCOUNTANT.accountantState();


            if (isPaused) {
                console2.log("Unpausing accountant at address:", address(ACCOUNTANT));
                if (
                    !AUTH.doesUserHaveRole(
                        admin,
                        PAUSER_ROLE
                    )
                ) {
                    AUTH.setUserRole(
                        admin,
                        PAUSER_ROLE,
                        true
                    );
                    console2.log("Granted PAUSER_ROLE to", admin);
                } else {
                    console2.log("Address already has PAUSER_ROLE");
                }
                ACCOUNTANT.unpause();
            } else {
                console2.log("Accountant at address is already unpaused:", address(ACCOUNTANT));
            }
        }   

        vm.stopBroadcast();
    }


    
}
