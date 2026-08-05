// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployQueueOnly.s.sol:DeployQueueOnly --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployQueueOnly is Script, ContractNames, Test {
    uint256 public privateKey;
    
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);
    address txBundler = 0x633ccAFEF3F42F87a457c44ffF826a5b6fc99706; //base txBundler

    address owner = txBundler;
    address auth = 0xF3E03eF7df97511a52f31ea7a22329619db2bdF4;
    address payable boringVault = payable(0x5401b8620E5FB570064CA9114fd1e135fd77D57c);
    address accountant = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE;

    function setUp() external {
        //privateKey = vm.envUint();
        vm.createSelectFork("base");
    }


    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast();

        creationCode = type(BoringOnChainQueue).creationCode;

        constructorArgs = abi.encode(owner, auth, boringVault, accountant);
        address queue = deployer.deployContract("LBTCv Boring Queue 0.1", creationCode, constructorArgs, 0);

        creationCode = type(BoringSolver).creationCode;
        constructorArgs = abi.encode(owner, auth, queue, true);
        
        address solver = deployer.deployContract("LBTCv Boring Solver V0.1", creationCode, constructorArgs, 0);
            
    }
}
