// SPDX-base-Identifier: SEL-1.0
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
 *  forge script script/DeployGenericRateProvider.s.sol:DeployGenericRateProvider --broadcast --verify --fork-url https://arbitrum.gateway.tenderly.co/7mchvW1CEXBoWfGVWn13j1
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployGenericRateProvider is Script, ContractNames, Test {
    uint256 public privateKey;
    
    //address target = 0x43a5C292A453A3bF3606fa856197f09D7B74251a; 
    //address target = 0xb523AE262D20A936BC152e6023996e46FDC2A95D; // Arbitrum
    address target = 0x524299Ab0987a7c4B3c8022a35669DdcdC715a10; // OP
    bytes4 selector = 0x50d25bcd; 
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d); 

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("optimism");
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
        address createdAddress = deployer.deployContract("wstETH Rate Provider V0.1", creationCode, constructorArgs, 0); 
        console.log("DEPLOYED ADDRESS: ", createdAddress); 
        //require(createdAddress == 0x983dC32F0F022F1e114Bf54c280B3575A512BF4f, "not premined"); 
        //require(GenericRateProvider(createdAddress).getRate() == 1038891179797110067, "bad price"); 

    }

}
