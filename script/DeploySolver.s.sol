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

    Deployer deployer = Deployer(0x00bF0B30655a43Af93c1b371Be021Bd4567c51d5);

    address owner = 0x0000000000000000000000000000000000000000;
    address auth = 0x2B9A752B7407D37A16A089c2A28d39d08EdB108D;
    address queue = 0x6F226E8a684e8d8b70C938BE2aB3087fFeAFd8EA;
    bool excessToSolverNonSelfSolve = true;

    function setUp() external {
        privateKey = vm.envUint("PLASMA_DEPLOYER_KEY");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(BoringSolver).creationCode;

        constructorArgs = abi.encode(owner, auth, queue, excessToSolverNonSelfSolve);
        deployer.deployContract("Plasma USD Vault Boring Solver V0.2", creationCode, constructorArgs, 0);
    }
}
