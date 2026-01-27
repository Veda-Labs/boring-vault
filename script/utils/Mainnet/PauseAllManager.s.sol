// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

/*
 *  source .env && forge script script/utils/Mainnet/PauseAllManager.s.sol:PauseAll --rpc-url $MAINNET_RPC_URL -vvvv --broadcast
 */

contract PauseAll is Script {
 
    uint8 public constant PAUSER_ROLE = 5;

    ManagerWithMerkleVerification constant MANAGER_iPrvlUSDCAgent1 = ManagerWithMerkleVerification(0x28d0D9C4553c24aBf55CBd0680B03524eeC966Aa);
    ManagerWithMerkleVerification constant MANAGER_iPrvlUSDCAgent2 = ManagerWithMerkleVerification(0x8f15C3f376f53b3406c1640135204944baA9c00D);
    ManagerWithMerkleVerification constant MANAGER_iPrvlETHAgent1 = ManagerWithMerkleVerification(0xF93C04915f69e95D9b8777609f07c969Ff24ee48);
    ManagerWithMerkleVerification constant MANAGER_iPrvlETHAgent2 = ManagerWithMerkleVerification(0x618c13371DB671AdbCbA93e76f758E307E6A0871);      


    RolesAuthority constant ROLES_AUTHORITY_iPrvlUSDC = RolesAuthority(0x5fac892A947296eDf36f6dBe199F2689e9bEc9D2);
    RolesAuthority constant ROLES_AUTHORITY_iPrvlUSDCAgent1 = RolesAuthority(0x58b25D1D07C5DB365a1686f6d824B585808b8dA2);
    RolesAuthority constant ROLES_AUTHORITY_iPrvlUSDCAgent2 = RolesAuthority(0xf84B1eF921D7aA21609C5f09E65C8067a048793C);
    RolesAuthority constant ROLES_AUTHORITY_iPrvlETH = RolesAuthority(0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446);      
    RolesAuthority constant ROLES_AUTHORITY_iPrvlETHAgent1 = RolesAuthority(0x3282A25B08a775FBa2FC6dE3fEe7cB635dC6671e);
    RolesAuthority constant ROLES_AUTHORITY_iPrvlETHAgent2 = RolesAuthority(0x0951A4fa55DD8F20B1eab2021cD8693D32f410B5);

    struct ManagerWithRoles {
        ManagerWithMerkleVerification manager;
        RolesAuthority rolesAuthority;
    }

    function run() external {

        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        address admin = vm.envAddress("MAINNET_DEPLOYER_ADDRESS");

        ManagerWithRoles[] memory managersWithRoles = new ManagerWithRoles[](4);
        managersWithRoles[0] = ManagerWithRoles(MANAGER_iPrvlUSDCAgent1, ROLES_AUTHORITY_iPrvlUSDCAgent1);
        managersWithRoles[1] = ManagerWithRoles(MANAGER_iPrvlUSDCAgent2, ROLES_AUTHORITY_iPrvlUSDCAgent2);
        managersWithRoles[2] = ManagerWithRoles(MANAGER_iPrvlETHAgent1, ROLES_AUTHORITY_iPrvlETHAgent1);
        managersWithRoles[3] = ManagerWithRoles(MANAGER_iPrvlETHAgent2, ROLES_AUTHORITY_iPrvlETHAgent2);

        //for each of the 4 managers and role authorities
        for (uint256 i = 0; i < managersWithRoles.length; i++) {
            ManagerWithRoles memory awr = managersWithRoles[i];
            RolesAuthority AUTH = awr.rolesAuthority;
            ManagerWithMerkleVerification MAN = awr.manager;




                console2.log("Pausing manager at address:", address(MAN));
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

                //MAN.pause();
                //console2.log("Paused manager at address:", address(MAN));
                MAN.unpause();
                console2.log("Unpaused manager at address:", address(MAN));
            }
        

        vm.stopBroadcast();
    }


    
}
