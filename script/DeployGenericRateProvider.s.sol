// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol"; 
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  forge script script/DeployGenericRateProvider.s.sol:DeployGenericRateProvider --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployGenericRateProvider is Script, ContractNames, Test {
    uint256 public privateKey;
    
    address target = 0x65eD6a4ac085620eE943c0B15525C4428D23e4Db; 
    bytes4 selector = 0x50d25bcd; 
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d); 

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("berachain");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(GenericRateProvider).creationCode;
        constructorArgs = abi.encode(
            target, 
            selector,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            true
        );
        address createdAddress = deployer.deployContract("WeETH Rate Provider V0.0", creationCode, constructorArgs, 0); 
        console.log("DEPLOYED ADDRESS: ", createdAddress); 
        //require(createdAddress == 0x983dC32F0F022F1e114Bf54c280B3575A512BF4f, "not premined"); 
        //require(GenericRateProvider(createdAddress).getRate() == 1038891179797110067, "bad price"); 

    }

}
