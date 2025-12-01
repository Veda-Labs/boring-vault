// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {Pauser} from "src/base/Roles/Pauser.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/DeployPauser.s.sol:DeployPauserScript --evm-version london --broadcast --slow --verify
 */
contract DeployPauserScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer;
    Pauser public pauser;

    address public accountant = 0x727929AF06Fa4f6E96cbC3fF7F4b60A65E168e23;
    address public teller = 0x1d8016AEdE8Bd0143C311Bb28CCdd8af8a245df9;
    address public manager = 0xA0e501F98A1B5d3d8e6Ffd161c76f92570E42931;
    address public queue = 0xF13d0670Ad2FD78e404a52Da45c6af1df7AD33DD;
    address public rolesAuthority = 0x3E8B0ee1D05267fE9F8d2b1f8CB48F2e23d69c6B;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("ink");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);
        creationCode = type(Pauser).creationCode;
        address[] memory pausables = new address[](4);
        pausables[0] = teller;
        pausables[1] = queue;
        pausables[2] = accountant;
        pausables[3] = manager;
        constructorArgs = abi.encode(dev1Address, rolesAuthority, pausables);
        pauser = Pauser(deployer.deployContract("Balanced Yield USDC Pauser V0.2", creationCode, constructorArgs, 0));
        vm.stopBroadcast();
    }
}
