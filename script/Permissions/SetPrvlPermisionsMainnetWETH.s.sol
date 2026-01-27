// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";

/*
 *  source .env && forge script script/Permissions/SetPrvlPermisionsMainnetWETH.s.sol:SetPermissionsMainnetWETH --sig "run()" --broadcast  -vvvv --slow
 */

contract SetPermissionsMainnetWETH is Script {

    uint256 internal privateKey;

    // iPrvlWETH
    address internal constant _iPrvlWETHRoleAuthority = 0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446;
    address internal constant iPrvlWETHVault = 0x5C1c20F7ae77f7cD80Fa4D08e053124b946f6C47;
    RolesAuthority iPrvlWETHRoleAuthority  = RolesAuthority(_iPrvlWETHRoleAuthority);

    // iPrvlWETHAgent1
    address internal constant _iPrvlAgent1WETHRoleAuthority = 0x3282A25B08a775FBa2FC6dE3fEe7cB635dC6671e;
    address internal constant iPrvlAgent1WETHVault = 0x8503B18b279Fd0f1EC35303D8db834619A12250f;
    address internal constant iPrvlAgent1WETHTeller= 0x7c5257EA4f3577643Be6D9A33824E8E9245CDa01;
    RolesAuthority iPrvlAgent1WETHRolesAuthority  = RolesAuthority(_iPrvlAgent1WETHRoleAuthority);

    // iPrvlWETHAgent2
    address internal constant _iPrvlAgent2WETHRoleAuthority =0x0951A4fa55DD8F20B1eab2021cD8693D32f410B5;
    address internal constant iPrvlAgent2WETHVault= 0x951f36b2F8Fd8B213AE999E53dF1c77749A6cDed;
    address internal constant iPrvlAgent2WETHTeller = 0xB31d657fe51edAd5577af4D948c119C9895Ea757;
    RolesAuthority iPrvlAgent2WETHRolesAuthority = RolesAuthority(_iPrvlAgent2WETHRoleAuthority);



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
        if (!iPrvlAgent1WETHRolesAuthority.doesUserHaveRole(iPrvlWETHVault, DEPOSITOR_VAULT_ROLE)) {
            iPrvlAgent1WETHRolesAuthority.setUserRole(iPrvlWETHVault, DEPOSITOR_VAULT_ROLE, true);
        }
        if (
            !iPrvlAgent1WETHRolesAuthority.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent1WETHTeller, TellerWithMultiAssetSupport.bulkDeposit.selector
            )
        ) {
            iPrvlAgent1WETHRolesAuthority.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent1WETHTeller, TellerWithMultiAssetSupport.bulkDeposit.selector, true
            );
        }
        if (
            !iPrvlAgent1WETHRolesAuthority.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent1WETHTeller, TellerWithMultiAssetSupport.bulkWithdraw.selector
            )
        ) {
            iPrvlAgent1WETHRolesAuthority.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent1WETHTeller, TellerWithMultiAssetSupport.bulkWithdraw.selector, true
            );
        }

        //set role to move from client vault to agent 2 vault
        if (!iPrvlAgent2WETHRolesAuthority.doesUserHaveRole(iPrvlWETHVault, DEPOSITOR_VAULT_ROLE)) {
            iPrvlAgent2WETHRolesAuthority.setUserRole(iPrvlWETHVault, DEPOSITOR_VAULT_ROLE, true);
        }
        if (
            !iPrvlAgent2WETHRolesAuthority.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent2WETHTeller, TellerWithMultiAssetSupport.bulkDeposit.selector
            )
        ) {
            iPrvlAgent2WETHRolesAuthority.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent2WETHTeller, TellerWithMultiAssetSupport.bulkDeposit.selector, true
            );
        }
        if (
            !iPrvlAgent2WETHRolesAuthority.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent2WETHTeller, TellerWithMultiAssetSupport.bulkWithdraw.selector
            )
        ) {
            iPrvlAgent2WETHRolesAuthority.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, iPrvlAgent2WETHTeller, TellerWithMultiAssetSupport.bulkWithdraw.selector, true
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

        // set for iPrvlWETH
        if (!iPrvlWETHRoleAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE)) {
            iPrvlWETHRoleAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE, true);
        }
        if (!iPrvlWETHRoleAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE)) {
            iPrvlWETHRoleAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE, true);
        }
        if (!iPrvlWETHRoleAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE)) {
            iPrvlWETHRoleAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE, true);
        }
        if (!iPrvlWETHRoleAuthority.doesUserHaveRole(address(EXCHANGE_RATE_UPDATER_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE)) {
            iPrvlWETHRoleAuthority.setUserRole(address(EXCHANGE_RATE_UPDATER_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE, true);
        }
        if (!iPrvlWETHRoleAuthority.doesUserHaveRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE)) {
            iPrvlWETHRoleAuthority.setUserRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE, true);
        }

        // set for iPrvlAgent1WETH
        if (!iPrvlAgent1WETHRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE)) {
            iPrvlAgent1WETHRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE, true);
        }
        if (!iPrvlAgent1WETHRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE)) {
            iPrvlAgent1WETHRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE, true);
        }
        if (!iPrvlAgent1WETHRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE)) {
            iPrvlAgent1WETHRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE, true);
        }
        if (!iPrvlAgent1WETHRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE)) {
            iPrvlAgent1WETHRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE, true);
        }
        if (!iPrvlAgent1WETHRolesAuthority.doesUserHaveRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE)) {
            iPrvlAgent1WETHRolesAuthority.setUserRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE, true);
        }

        // set for iPrvlAgent2WETH
           if (!iPrvlAgent2WETHRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE)) {
            iPrvlAgent2WETHRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), OWNER_ROLE, true);
        }
        if (!iPrvlAgent2WETHRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE)) {
            iPrvlAgent2WETHRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), MULTISIG_ROLE, true);
        }
        if (!iPrvlAgent2WETHRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE)) {
            iPrvlAgent2WETHRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), STRATEGIST_MULTISIG_ROLE, true);
        }
        if (!iPrvlAgent2WETHRolesAuthority.doesUserHaveRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE)) {
            iPrvlAgent2WETHRolesAuthority.setUserRole(address(VAULT_SYSTEM_OWNER_ROLE_ADDRESS), UPDATE_EXCHANGE_RATE_ROLE, true);
        }
        if (!iPrvlAgent2WETHRolesAuthority.doesUserHaveRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE)) {
            iPrvlAgent2WETHRolesAuthority.setUserRole(address(COMPLETE_WITHDRAWALS_ADDRESS), SOLVER_ORIGIN_ROLE, true);
        }

        /*
        * @dev Grant BoringOnChainQueue the ONLY_QUEUE_ROLE so it can call BoringSolver.boringSolve
        * Note: The ONLY_QUEUE_ROLE already has the capability to call boringSolve, we just need to grant the role
        */
        uint8 ONLY_QUEUE_ROLE = 32;
        address boringOnChainQueue = 0x66Afbd5b2558B34af02c9Cbe61bfc409C909F375;
        
        // Grant ONLY_QUEUE_ROLE to BoringOnChainQueue for iPrvlUSDC
        if (!iPrvlWETHRoleAuthority.doesUserHaveRole(boringOnChainQueue, ONLY_QUEUE_ROLE)) {
            iPrvlWETHRoleAuthority.setUserRole(boringOnChainQueue, ONLY_QUEUE_ROLE, true);
        }

        vm.stopBroadcast();
    }
}