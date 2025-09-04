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
    address auth = 0xecE2222D3ac4b21316b6E5F4208A452BB96A8Cb4;
    address queue = 0xC07A42fF77694e6530091175643aABDC923FA29b;
    bool excessToSolverNonSelfSolve = true;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("sepolia");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(BoringSolver).creationCode;

        constructorArgs = abi.encode(owner, auth, queue, excessToSolverNonSelfSolve);
        deployer.deployContract("Ink Sepolia Boring Solver 0.1", creationCode, constructorArgs, 0);
    }
}
