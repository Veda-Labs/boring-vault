// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  forge script script/DeployManagerWithMerkleVerification.s.sol:DeployManagerWithMerkleVerification --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployManagerWithMerkleVerification is Script, ContractNames, Test {
    uint256 public privateKey;
    
    //liquidUSD
    address boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C; 
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d); 

    address dev1Address = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address balancerVaultAddress = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }


    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(ManagerWithMerkleVerification).creationCode;
        constructorArgs = abi.encode(dev1Address, boringVault, balancerVaultAddress);
        deployer.deployContract("liquidUSD ManagerWithMerkleVerification V0.1", creationCode, constructorArgs, 0); 
    }

}
