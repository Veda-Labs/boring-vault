// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

/*
 * source .env && forge script script/Permissions/GrantAgentAuthorityRole.s.sol --broadcast
 */


contract GrantAgentAuthorityRole is Script {
    uint8 constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    address constant TARGET_ADDRESS = 0x98e46e0B009269CB6Fc0B4CD13C6E1247B8b00b8;
    address constant ACCOUNTANT_ADDRESS = 0x3462A05eDf94494E3e0d288606e194FC7e433a70;

    uint256 privateKey;

    function setUp() external {
        // Choose the appropriate network and key
        string memory network = "sepolia";
        
        if (keccak256(bytes(network)) == keccak256(bytes("sepolia"))) {
            privateKey = vm.envUint("DEPOSITOR_PRIVATE_KEY");
            vm.createSelectFork("sepolia");
        } else if (keccak256(bytes(network)) == keccak256(bytes("local"))) {
            privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
            vm.createSelectFork("local");
        } else if (keccak256(bytes(network)) == keccak256(bytes("mainnet"))) {
            privateKey = vm.envUint("MAINNET_DEPLOYER_PRIVATE_KEY");
            vm.createSelectFork("mainnet");
        } else {
            revert("Unsupported network");
        }
    }

    function run() public {
        vm.startBroadcast(privateKey);

        // Get the appropriate RolesAuthority address based on network
        // This is the authority that the accountant contract uses
        address rolesAuthorityAddress = 0x843a304b6ea56667B327C03cd5Df87eDe2825AFc;
        RolesAuthority rolesAuthority = RolesAuthority(rolesAuthorityAddress);

        // Grant UPDATE_EXCHANGE_RATE_ROLE to the target address
        if (!rolesAuthority.doesUserHaveRole(TARGET_ADDRESS, UPDATE_EXCHANGE_RATE_ROLE)) {
            rolesAuthority.setUserRole(TARGET_ADDRESS, UPDATE_EXCHANGE_RATE_ROLE, true);
            console.log("Granted UPDATE_EXCHANGE_RATE_ROLE to", TARGET_ADDRESS);
        } else {
            console.log("Address already has UPDATE_EXCHANGE_RATE_ROLE");
        }

        // Grant capability to call updateExchangeRate in the accountant
        if (!rolesAuthority.doesRoleHaveCapability(
            UPDATE_EXCHANGE_RATE_ROLE, 
            ACCOUNTANT_ADDRESS, 
            AccountantWithRateProviders.updateExchangeRate.selector
        )) {
            rolesAuthority.setRoleCapability(
                UPDATE_EXCHANGE_RATE_ROLE, 
                ACCOUNTANT_ADDRESS, 
                AccountantWithRateProviders.updateExchangeRate.selector, 
                true
            );
            console.log("Granted updateExchangeRate capability to UPDATE_EXCHANGE_RATE_ROLE for accountant", ACCOUNTANT_ADDRESS);
        } else {
            console.log("UPDATE_EXCHANGE_RATE_ROLE already has updateExchangeRate capability");
        }

        vm.stopBroadcast();
    }

    function getRolesAuthorityAddress() internal view returns (address) {
        string memory network = "sepolia"; // Change this as needed
        
        if (keccak256(bytes(network)) == keccak256(bytes("sepolia"))) {
            // Sepolia RolesAuthority for client vault
            return 0x1c7e8219d720a3C8125E12Db1D08863325D5a2F1;
        } else if (keccak256(bytes(network)) == keccak256(bytes("local"))) {
            // Local fork RolesAuthority for agent vault
            return 0x85aa8590E3f076aF23AF2cc29a743c481354A8cf;
        } else if (keccak256(bytes(network)) == keccak256(bytes("mainnet"))) {
            // You'll need to add the mainnet RolesAuthority address here
            revert("Please add mainnet RolesAuthority address");
        } else {
            revert("Unsupported network");
        }
    }

}