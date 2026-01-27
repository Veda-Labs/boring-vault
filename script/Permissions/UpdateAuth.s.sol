// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/Permissions/UpdateAuth.s.sol:Deploy --fork-url  $MAINNET_RPC_URL --verify --slow  -vvvv --broadcast
 */
contract Deploy is Script {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;
    address public vaultSystemOwner = 0xE42C03CB1999E345fdE8465CAAf4B4379143375F;

    uint8 public DEPLOYER_ROLE = 1;

    function run() external {



        privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        rolesAuthority = RolesAuthority(0x62ABF7b5937a18cEc64EA59e09eE36fF1f8172C6);
        rolesAuthority.setUserRole(vaultSystemOwner, DEPLOYER_ROLE, true);

        vm.stopBroadcast();
    }
}
