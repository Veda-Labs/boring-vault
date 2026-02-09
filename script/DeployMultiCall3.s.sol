// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {Multicall3} from "src/helper/MultiCall3.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

contract DeployMultiCall3Script is Script {
    function setUp() external {
        vm.createSelectFork("tacBuild");
    }

    function run() external {
        vm.startBroadcast(vm.envUint("BORING_OWNER"));
        new Multicall3();
        vm.stopBroadcast();
    }
}

