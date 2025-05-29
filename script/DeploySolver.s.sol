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

    address owner = 0x1cdF47387358A1733968df92f7cC14546D9E1047;
    address auth =  0xFa5b3E35F961229b25Caa108C3D42cEEb20d0122;
    address queue = 0x7C0eC8751f6Fa02e1a28B53Cc9dA1277829923fB;
    bool excessToSolverNonSelfSolve = false;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("sonicMainnet");
    }


    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(BoringSolver).creationCode;

        constructorArgs = abi.encode(owner, auth, queue, excessToSolverNonSelfSolve);
        deployer.deployContract("Staked Sonic USD Boring Solver V1.0", creationCode, constructorArgs, 0);
    }
}
