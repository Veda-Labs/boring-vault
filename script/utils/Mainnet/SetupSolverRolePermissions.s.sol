// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {console2} from "forge-std/console2.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";

/**
 * @title SetupSolverRolePermissions
 * @dev Run with: source .env && forge script script/utils/Mainnet/SetupSolverRolePermissions.s.sol:SetupSolverRolePermissions --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */
contract SetupSolverRolePermissions is Script {
    // Role constants
    uint8 public constant SOLVER_ORIGIN_ROLE = 33;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;

    address public constant ADMIN = 0xdDEbf1BCC0597415089475c78125E2A6ec481b1C;

    // Contract addresses
    address constant USDC_ROLES_AUTHORITY = 0x5fac892A947296eDf36f6dBe199F2689e9bEc9D2;
    address constant USDC_BORING_SOLVER = 0x7fF7348e4908654fdF7a465356CB7E4Fa09C4963;
    address constant USDC_BORING_ON_CHAIN_QUEUE = 0x7D2b993CfC4048b85EC44B95Dc01a4C6B4E47b25;
    address constant ETH_ROLES_AUTHORITY = 0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446;
    address constant ETH_BORING_SOLVER = 0x4e98f2d2DC317076De218947A5f540BE64f0cB3B;
    address constant ETH_BORING_ON_CHAIN_QUEUE = 0x66Afbd5b2558B34af02c9Cbe61bfc409C909F375;

    function run() external {
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        RolesAuthority USDCrolesAuthority = RolesAuthority(USDC_ROLES_AUTHORITY);
        RolesAuthority ETHrolesAuthority = RolesAuthority(ETH_ROLES_AUTHORITY);

   

        // Grant SOLVER_ROLE to the admin if not already granted
        if (!USDCrolesAuthority.doesUserHaveRole(ADMIN, SOLVER_ORIGIN_ROLE)) {
            USDCrolesAuthority.setUserRole(ADMIN, SOLVER_ORIGIN_ROLE, true);
            console2.log("Granted SOLVER_ROLE to", ADMIN);
        } else {
            console2.log("Admin already has SOLVER_ROLE");
        }

        // Grant SOLVER_ROLE to the admin if not already granted
        if (!ETHrolesAuthority.doesUserHaveRole(ADMIN, SOLVER_ORIGIN_ROLE)) {
            ETHrolesAuthority.setUserRole(ADMIN, SOLVER_ORIGIN_ROLE, true);
            console2.log("Granted SOLVER_ROLE to", ADMIN);
        } else {
            console2.log("Admin already has SOLVER_ROLE");
        }
        // Add cancel permission for BoringSolver on USDC RolesAuthority

        


        USDCrolesAuthority.doesRoleHaveCapability(
            STRATEGIST_MULTISIG_ROLE,
            USDC_BORING_ON_CHAIN_QUEUE,
            BoringOnChainQueue.cancelUserWithdraws.selector
        );

        ETHrolesAuthority.doesRoleHaveCapability(
            STRATEGIST_MULTISIG_ROLE,
            ETH_BORING_ON_CHAIN_QUEUE,
            BoringOnChainQueue.cancelUserWithdraws.selector
        );

        if (!USDCrolesAuthority.doesUserHaveRole(ADMIN, STRATEGIST_MULTISIG_ROLE)) {
            USDCrolesAuthority.setUserRole(ADMIN, STRATEGIST_MULTISIG_ROLE, true);
            console2.log("Granted STRATEGIST_MULTISIG_ROLE to", ADMIN);
        } else {
            console2.log("Admin already has STRATEGIST_MULTISIG_ROLE");
        }

        if (!ETHrolesAuthority.doesUserHaveRole(ADMIN, STRATEGIST_MULTISIG_ROLE)) {
            ETHrolesAuthority.setUserRole(ADMIN, STRATEGIST_MULTISIG_ROLE, true);
            console2.log("Granted STRATEGIST_MULTISIG_ROLE to", ADMIN);
        } else {
            console2.log("Admin already has STRATEGIST_MULTISIG_ROLE");
        }


        vm.stopBroadcast();
    }
}
