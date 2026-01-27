// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import "forge-std/Script.sol";

/*
 *  source .env && forge script script/Permissions/SetPrvlPermisionsMainnetUSDC.s.sol:SetPermissionsMainnetUSDC --sig "run()" --broadcast  -vvvv --slow
 */

contract SetPermissionsMainnetUSDC is Script {

    uint256 internal privateKey;

    // iPrvlUSDC
    address internal constant _iPrvlUSDCRoleAuthority = 0x5fac892A947296eDf36f6dBe199F2689e9bEc9D2;
    address internal constant iPrvlUSDCVault = 0xA9dA417025B427cE8519F989BBD5d89F3E322a20;
    RolesAuthority iPrvlUSDCRoleAuthority  = RolesAuthority(_iPrvlUSDCRoleAuthority);

    // iPrvlUSDCAgent1
    address internal constant _iPrvlAgent1USDCRoleAuthority = 0x58b25D1D07C5DB365a1686f6d824B585808b8dA2;
    address internal constant iPrvlAgent1USDCVault = 0x7e68c279EA86FA49A49Eef2Cbb79B9cBfBc48025;
    address internal constant iPrvlAgent1USDCTeller= 0xe03544247540E32A51DD2fa1B8d5D30fc4E20AEa;
    RolesAuthority iPrvlAgent1USDCRolesAuthority  = RolesAuthority(_iPrvlAgent1USDCRoleAuthority);

    // iPrvlUSDCAgent2
    address internal constant _iPrvlAgent2USDCRoleAuthority =0xf84B1eF921D7aA21609C5f09E65C8067a048793C;
    address internal constant iPrvlAgent2USDCVault= 0x6638968ACBA85A6445D3909F4d0520F7D2501061;
    address internal constant iPrvlAgent2USDCTeller = 0x5078e98b06f5aebC81095fCACBb9c6ED5e7276E6;
    RolesAuthority iPrvlAgent2USDCRolesAuthority = RolesAuthority(_iPrvlAgent2USDCRoleAuthority);



    function setUp() external {
        privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        /*
        * @dev Setup agent roles to move funds between vaults.
        */
        uint8 DEPOSITOR_VAULT_ROLE = 34; // custome role moving funds between vaults

        //set role to move from client vault to agent 1 vault
        if (!iPrvlAgent1USDCRolesAuthority.doesUserHaveRole(iPrvlUSDCVault, DEPOSITOR_VAULT_ROLE)) {
            iPrvlAgent1USDCRolesAuthority.setUserRole(iPrvlUSDCVault, DEPOSITOR_VAULT_ROLE, true);
        }
        if (
            !iPrvlAgent1USDCRolesAuthority.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent1USDCTeller, TellerWithMultiAssetSupport.bulkDeposit.selector
            )
        ) {
            iPrvlAgent1USDCRolesAuthority.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent1USDCTeller, TellerWithMultiAssetSupport.bulkDeposit.selector, true
            );
        }
        if (
            !iPrvlAgent1USDCRolesAuthority.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent1USDCTeller, TellerWithMultiAssetSupport.bulkWithdraw.selector
            )
        ) {
            iPrvlAgent1USDCRolesAuthority.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent1USDCTeller, TellerWithMultiAssetSupport.bulkWithdraw.selector, true
            );
        }

        //set role to move from client vault to agent 2 vault
        if (!iPrvlAgent2USDCRolesAuthority.doesUserHaveRole(iPrvlUSDCVault, DEPOSITOR_VAULT_ROLE)) {
            iPrvlAgent2USDCRolesAuthority.setUserRole(iPrvlUSDCVault, DEPOSITOR_VAULT_ROLE, true);
        }
        if (
            !iPrvlAgent2USDCRolesAuthority.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent2USDCTeller, TellerWithMultiAssetSupport.bulkDeposit.selector
            )
        ) {
            iPrvlAgent2USDCRolesAuthority.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent2USDCTeller, TellerWithMultiAssetSupport.bulkDeposit.selector, true
            );
        }
        if (
            !iPrvlAgent2USDCRolesAuthority.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent2USDCTeller, TellerWithMultiAssetSupport.bulkWithdraw.selector
            )
        ) {
            iPrvlAgent2USDCRolesAuthority.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent2USDCTeller, TellerWithMultiAssetSupport.bulkWithdraw.selector, true
            );
        }


        /* 
        * @dev Setup system owner roles for agent vaults.
        */
        address VAULT_SYSTEM_OWNER_ROLE_ADDRESS = 0xE42C03CB1999E345fdE8465CAAf4B4379143375F;
        address COMPLETE_WITHDRAWALS_ADDRESS = 0x13517C59714869483908289969C69eD5593c1704;
        address EXCHANGE_RATE_UPDATER_ADDRESS = 0x4f979bD3afAa9FAead2269d78ea8477996dB114D;
        uint8 OWNER_ROLE = 8;
        uint8 MULTISIG_ROLE = 9;
        uint8 STRATEGIST_MULTISIG_ROLE = 10;
        uint8 UPDATE_EXCHANGE_RATE_ROLE = 11;
        uint8 SOLVER_ORIGIN_ROLE = 33;

        // set for iPrvlUSDC
        if (!iPrvlUSDCRoleAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE)) {
            iPrvlUSDCRoleAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE, true);
        }
        if (!iPrvlUSDCRoleAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE)) {
            iPrvlUSDCRoleAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE, true);
        }
        if (!iPrvlUSDCRoleAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE)) {
            iPrvlUSDCRoleAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE, true);
        }
        if (!iPrvlUSDCRoleAuthority.doesUserHaveRole(address(EXCHANGE_RATE_UPDATER_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE)) {
            iPrvlUSDCRoleAuthority.setUserRole(address(EXCHANGE_RATE_UPDATER_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE, true);
        }
        if (!iPrvlUSDCRoleAuthority.doesUserHaveRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE)) {
            iPrvlUSDCRoleAuthority.setUserRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE, true);
        }

        // set for iPrvlAgent1USDC
        if (!iPrvlAgent1USDCRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE)) {
            iPrvlAgent1USDCRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE, true);
        }
        if (!iPrvlAgent1USDCRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE)) {
            iPrvlAgent1USDCRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE, true);
        }
        if (!iPrvlAgent1USDCRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE)) {
            iPrvlAgent1USDCRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE, true);
        }
        if (!iPrvlAgent1USDCRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE)) {
            iPrvlAgent1USDCRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE, true);
        }
        if (!iPrvlAgent1USDCRolesAuthority.doesUserHaveRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE)) {
            iPrvlAgent1USDCRolesAuthority.setUserRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE, true);
        }

        // set for iPrvlAgent2USDC
           if (!iPrvlAgent2USDCRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE)) {
            iPrvlAgent2USDCRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE, true);
        }
        if (!iPrvlAgent2USDCRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE)) {
            iPrvlAgent2USDCRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE, true);
        }
        if (!iPrvlAgent2USDCRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE)) {
            iPrvlAgent2USDCRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE, true);
        }
        if (!iPrvlAgent2USDCRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE)) {
            iPrvlAgent2USDCRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE, true);
        }
        if (!iPrvlAgent2USDCRolesAuthority.doesUserHaveRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE)) {
            iPrvlAgent2USDCRolesAuthority.setUserRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE, true);
        }

        /*
        * @dev Grant BoringOnChainQueue the ONLY_QUEUE_ROLE so it can call BoringSolver.boringSolve
        * Note: The ONLY_QUEUE_ROLE already has the capability to call boringSolve, we just need to grant the role
        */
        uint8 ONLY_QUEUE_ROLE = 32;
        address boringOnChainQueue = 0x7D2b993CfC4048b85EC44B95Dc01a4C6B4E47b25;
        
        // Grant ONLY_QUEUE_ROLE to BoringOnChainQueue for iPrvlUSDC
        if (!iPrvlUSDCRoleAuthority.doesUserHaveRole(boringOnChainQueue, ONLY_QUEUE_ROLE)) {
            iPrvlUSDCRoleAuthority.setUserRole(boringOnChainQueue, ONLY_QUEUE_ROLE, true);
        }

        vm.stopBroadcast();
    }
}