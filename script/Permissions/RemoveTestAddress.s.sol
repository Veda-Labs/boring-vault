// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/Permissions/RemoveTestAddress.s.sol:Deploy --fork-url  $MAINNET_RPC_URL --verify --slow  -vvvv --broadcast
 */
contract Deploy is Script {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public iPrvlUSDCRolesAuthority =
        RolesAuthority(0x5fac892A947296eDf36f6dBe199F2689e9bEc9D2);
    RolesAuthority public iPrvlUSDCAgent1RolesAuthority =
        RolesAuthority(0x58b25D1D07C5DB365a1686f6d824B585808b8dA2);
    RolesAuthority public iPrvlUSDCAgent2RolesAuthority =
        RolesAuthority(0xf84B1eF921D7aA21609C5f09E65C8067a048793C);
    RolesAuthority public iPrvlETHRolesAuthority =
        RolesAuthority(0x5105361E4078F5d0AAce57B4e3539b7b1Cdee446);
    RolesAuthority public iPrvlETHAgent1RolesAuthority =
        RolesAuthority(0x3282A25B08a775FBa2FC6dE3fEe7cB635dC6671e);
    RolesAuthority public iPrvlETHAgent2RolesAuthority =
        RolesAuthority(0x0951A4fa55DD8F20B1eab2021cD8693D32f410B5);

    RolesAuthority[6] public rolesAuthority = [
        iPrvlUSDCRolesAuthority,
        iPrvlUSDCAgent1RolesAuthority,
        iPrvlUSDCAgent2RolesAuthority,
        iPrvlETHRolesAuthority,
        iPrvlETHAgent1RolesAuthority,
        iPrvlETHAgent2RolesAuthority
    ];

    address public vaultSystemOwner =
        0xE42C03CB1999E345fdE8465CAAf4B4379143375F;
    address public testAddress = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40;

    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant STRATEGIST_ROLE = 7;

    function run() external {
        privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        for (uint8 i = 0; i < rolesAuthority.length; i++) {
            RolesAuthority currentRolesAuthority = rolesAuthority[i];
            bytes32 userRoles = currentRolesAuthority.getUserRoles(testAddress);
            for (uint16 y = 0; y < 256; y++) {
                if ((uint256(userRoles) >> y) & 1 != 0) {
                    console.log("Removing role", y, "from", testAddress);
                    currentRolesAuthority.setUserRole(
                        testAddress,
                        uint8(y),
                        false
                    );
                }
            }
            bytes32 updatedUserRoles = currentRolesAuthority.getUserRoles(testAddress);
            console.log(
                "Removed all roles from",
                testAddress,
                "in RolesAuthority at",
                address(currentRolesAuthority)
            );
        }

        vm.stopBroadcast();
    }
}
