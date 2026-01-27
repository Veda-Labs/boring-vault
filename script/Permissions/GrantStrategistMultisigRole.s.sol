// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";

/*
 * source .env && forge script script/Permissions/GrantStrategistMultisigRole.s.sol --broadcast
 */


contract GrantStrategistMultisigRole is Script {
    uint8 constant STRATEGIST_MULTISIG_ROLE = 10;
    address constant TARGET_ADDRESS = 0x98e46e0B009269CB6Fc0B4CD13C6E1247B8b00b8;
    address constant SOLVER_ADDRESS = 0x081ec05c0258c38664cb4eA5FFda76120200f693;
    address constant QUEUE_ADDRESS = 0x502404B51C7f3a1802C4F344BDC606A8AeC06c80;

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
        address rolesAuthorityAddress = 0xc21aB537EC3c121F936ea6E643aE0EAAd7AdEC6E;
        RolesAuthority rolesAuthority = RolesAuthority(rolesAuthorityAddress);

        // Grant STRATEGIST_MULTISIG_ROLE to the target address
        if (!rolesAuthority.doesUserHaveRole(TARGET_ADDRESS, STRATEGIST_MULTISIG_ROLE)) {
            rolesAuthority.setUserRole(TARGET_ADDRESS, STRATEGIST_MULTISIG_ROLE, true);
            console.log("Granted STRATEGIST_MULTISIG_ROLE to", TARGET_ADDRESS);
        } else {
            console.log("Address already has STRATEGIST_MULTISIG_ROLE");
        }

        // Grant capability to call boringRedeemSolve in the solver
        if (!rolesAuthority.doesRoleHaveCapability(
            STRATEGIST_MULTISIG_ROLE, 
            SOLVER_ADDRESS, 
            BoringSolver.boringRedeemSolve.selector
        )) {
            rolesAuthority.setRoleCapability(
                STRATEGIST_MULTISIG_ROLE, 
                SOLVER_ADDRESS, 
                BoringSolver.boringRedeemSolve.selector, 
                true
            );
            console.log("Granted boringRedeemSolve capability to STRATEGIST_MULTISIG_ROLE for solver", SOLVER_ADDRESS);
        } else {
            console.log("STRATEGIST_MULTISIG_ROLE already has boringRedeemSolve capability");
        }

        // Grant capability to call cancelUserWithdraws in the queue
        if (!rolesAuthority.doesRoleHaveCapability(
            STRATEGIST_MULTISIG_ROLE, 
            QUEUE_ADDRESS, 
            BoringOnChainQueue.cancelUserWithdraws.selector
        )) {
            rolesAuthority.setRoleCapability(
                STRATEGIST_MULTISIG_ROLE, 
                QUEUE_ADDRESS, 
                BoringOnChainQueue.cancelUserWithdraws.selector, 
                true
            );
            console.log("Granted cancelUserWithdraws capability to STRATEGIST_MULTISIG_ROLE for queue", QUEUE_ADDRESS);
        } else {
            console.log("STRATEGIST_MULTISIG_ROLE already has cancelUserWithdraws capability");
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