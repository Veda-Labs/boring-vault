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

    address public accountant = 0x1b293DC39F94157fA0D1D36d7e0090C8B8B8c13F;
    address public teller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;
    address public manager = 0x382d0106F308864D5462332D9D3bB54a60384B70;
    address public rolesAuthority = 0x6889E57BcA038C28520C0B047a75e567502ea5F6;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);
        creationCode = type(Pauser).creationCode;
        address[] memory pausables = new address[](3);
        pausables[0] = accountant;
        pausables[1] = teller;
        pausables[2] = manager;
        constructorArgs = abi.encode(dev1Address, rolesAuthority, pausables);
        pauser = Pauser(deployer.deployContract("ether.fi BTC Pauser V0.0", creationCode, constructorArgs, 0));
        vm.stopBroadcast();
    }
}
