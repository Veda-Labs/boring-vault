// SPDX-License-Identifier: UNLICENSED
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
    
    address target = 0x8D51DBC85cEef637c97D02bdaAbb5E274850e68C; 
    bytes4 selector = 0xbb23ae25; 
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d); 

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
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
            6
        ));
        address createdAddress = deployer.deployContract("mFONE Rate Provider V0.0", creationCode, constructorArgs, 0); 
        console.log("DEPLOYED ADDRESS: ", createdAddress); 
    }
}
