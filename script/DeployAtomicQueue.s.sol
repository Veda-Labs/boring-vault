// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {MockERC20} from "src/helper/MockERC20.sol";
import {AtomicQueue} from "src/atomic-queue/AtomicQueue.sol";
import {AtomicSolverV3} from "src/atomic-queue/AtomicSolverV3.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/DeployAtomicQueue.s.sol:DeployAtomicQueueScript --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployAtomicQueueScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;

    uint8 public DEPLOYER_ROLE = 1;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);
        address authority = 0x4df6b73328B639073db150C4584196c4d97053b7;

        constructorArgs = abi.encode(dev1Address, authority);
        creationCode = type(AtomicQueue).creationCode;
        deployer.deployContract("AtomicQueue V1.0", creationCode, constructorArgs, 0);

        constructorArgs = abi.encode(dev1Address, authority);
        creationCode = type(AtomicSolverV3).creationCode;
        deployer.deployContract("AtomicSolverV3 V1.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
