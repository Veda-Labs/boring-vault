// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeploySolver.s.sol:DeploySolver --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeploySolver is Script, ContractNames, Test {
    uint256 public privateKey;
    
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);

    address owner = 0x1cdF47387358A1733968df92f7cC14546D9E1047;
    address auth = 0x9778D78495cBbfce0B1F6194526a8c3D4b9C3AAF;
    address queue = 0xE32cEB767d187F1d3c81949657CABc50c655f40A;
    bool excessToSolverNonSelfSolve = false;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("unichain");
    }


    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(BoringSolver).creationCode;

        constructorArgs = abi.encode(owner, auth, queue, excessToSolverNonSelfSolve);
        deployer.deployContract("Golden Goose Boring Solver 1.1", creationCode, constructorArgs, 0);
    }
}
