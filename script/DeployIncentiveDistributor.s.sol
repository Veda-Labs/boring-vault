// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {IncentiveDistributor} from "src/helper/IncentiveDistributor.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/DeployIncentiveDistributor.s.sol:DeployIncentiveDistributorScript --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployIncentiveDistributorScript is Script {
    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer;

    address public owner = 0xf8553c8552f906C19286F21711721E206EE4909E;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);

        constructorArgs = abi.encode(owner, address(0));
        creationCode = type(IncentiveDistributor).creationCode;
        IncentiveDistributor(deployer.deployContract("Incentive Distributor V0.0", creationCode, constructorArgs, 0));

        vm.stopBroadcast();
    }
}
