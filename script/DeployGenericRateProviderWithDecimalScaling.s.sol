// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {GenericRateProviderWithDecimalScaling} from "src/helper/GenericRateProviderWithDecimalScaling.sol"; 
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployGenericRateProviderWithDecimalScaling.s.sol:DeployGenericRateProviderWithDecimalScaling --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployGenericRateProviderWithDecimalScaling is Script, ContractNames, Test {
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

        creationCode = type(GenericRateProviderWithDecimalScaling).creationCode;
        constructorArgs = abi.encode(GenericRateProviderWithDecimalScaling.ConstructorArgs(
            target, 
            selector,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            true,
            8,
            18
        ));
        address createdAddress = deployer.deployContract("WeETH Rate Provider V0.1", creationCode, constructorArgs, 0); 
        console.log("DEPLOYED ADDRESS: ", createdAddress); 
    }

}
