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
import {GenericRateProviderWithStalenessCheck} from "src/helper/GenericRateProviderWithStalenessCheck.sol"; 
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployGenericRateProviderWithStalenessCheck.s.sol:DeployGenericRateProviderWithStalenessCheck --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 * @dev IMPORTANT: OUTPUT DECIMALS must be in QUOTE asset NOT the vault deicmals. Ie if the token we are pricing is in 18 decimals (mfONE) output must be 18 
 */
contract DeployGenericRateProviderWithStalenessCheck is Script, ContractNames, Test {
    
    //address targetToken = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address target = 0xcE6538287B42D833f294662edad8B3dA070C6902;
    bytes4 selector = 0x50d25bcd;
    Deployer deployer = Deployer(0xe80F045fc6F551229f98FA21E0Db35784A590e05); //newDeployer

    function setUp() external {
        vm.createSelectFork("monad");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast();

        creationCode = type(GenericRateProviderWithStalenessCheck).creationCode;
        constructorArgs = abi.encode(GenericRateProviderWithStalenessCheck.ConstructorArgs(
            target, 
            selector,
            0, 0,
            0, 0,
            0, 0,
            0, 0,
            true,
            18,
            18,
            21600,
            0x8205bf6a, //latestTimestamp
            0
        ));
        address createdAddress = deployer.deployContract("WETH USD Rate Provider V0.0", creationCode, constructorArgs, 0); 
        //require (GenericRateProviderWithStalenessCheck(createdAddress).outputDecimals() == ERC20(targetToken).decimals()); 
        console.log("DEPLOYED ADDRESS: ", createdAddress); 
    }
}
