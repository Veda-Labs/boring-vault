// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeploySolver.s.sol:DeploySolver --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeploySolver is Script, ContractNames, Test {
    uint256 public privateKey;

    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);

    address owner = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address auth = 0xED8C9A514eB81124e370015878ea1fB3fEF18158;
    address queue = 0x84D988bA2f2838f6ccF61fDE77fe3EB70dFE284f;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(BoringSolver).creationCode;

        constructorArgs = abi.encode(owner, auth, queue);
        deployer.deployContract("HyperUSD Boring Solver 0.1", creationCode, constructorArgs, 0);
    }
}
