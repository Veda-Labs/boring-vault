// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
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
 * @dev IMPORTANT: OUTPUT DECIMALS must be in QUOTE asset NOT the vault deicmals. Ie if the token we are pricing is in 18 decimals (mfONE) output must be 18 
 */
contract DeployGenericRateProviderWithDecimalScaling is Script, ContractNames, Test {
    uint256 public privateKey;
    
    address target = 0xCB568C33EA2B0B81852655d722E3a52d9D44e7De; 
    bytes4 selector = 0x50d25bcd; 
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d); 

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("katana");
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
        address createdAddress = deployer.deployContract("mFONE Rate Provider V0.0", creationCode, constructorArgs, 0); 
        require (GenericRateProvider(createdAddress).outputDecimals() == ERC20(targetToken).decimals()); 
        console.log("DEPLOYED ADDRESS: ", createdAddress); 
    }
}
