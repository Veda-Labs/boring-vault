// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol"; 
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  forge script script/DeployDrone.s.sol:DeployDrone --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDrone is Script, ContractNames, Test {
    uint256 public privateKey;
    
    //sETHFI
    address boringVault = 0x86B5780b606940Eb59A062aA85a07959518c0161; 
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d); 

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }


    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(BoringDrone).creationCode;
        constructorArgs = abi.encode(boringVault, 0);
        deployer.deployContract("sETHFI Boring Drone 0", creationCode, constructorArgs, 0); 
        deployer.deployContract("sETHFI Boring Drone 1", creationCode, constructorArgs, 0); 
        deployer.deployContract("sETHFI Boring Drone 2", creationCode, constructorArgs, 0); 

    }

}
