// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
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

    address owner = 0x1cdF47387358A1733968df92f7cC14546D9E1047;
    address auth = 0x9778D78495cBbfce0B1F6194526a8c3D4b9C3AAF;
    address payable boringVault = payable(0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09);
    address accountant = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("unichain");
    }


    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(BoringOnChainQueue).creationCode;

        constructorArgs = abi.encode(owner, auth, boringVault, accountant);
        deployer.deployContract("Golden Goose Boring Queue 1.1", creationCode, constructorArgs, 0);
    }
}
