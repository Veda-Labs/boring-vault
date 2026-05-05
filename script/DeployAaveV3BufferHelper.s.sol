// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {AaveV3BufferHelper} from "src/base/Roles/AaveV3BufferHelper.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployAaveV3BufferHelper.s.sol:DeployAaveV3BufferHelperScript --ledger --sender $LEDGER_ADDRESS --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Set `vaultAddress` below to the target BoringVault before running.
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployAaveV3BufferHelperScript is Script, ContractNames, MainnetAddresses {
    Deployer public deployer = Deployer(deployerAddress);

    // TODO: set to the target vault before deploying
    address public vaultAddress = 0x4831c227C70eAd0E5a4151777171Dbfd13879d62;

    function setUp() external {
        vm.createSelectFork("mainnet");
    }

    function run() external {
        require(vaultAddress != address(0), "DeployAaveV3BufferHelper: vaultAddress not set");

        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast();

        creationCode = type(AaveV3BufferHelper).creationCode;
        constructorArgs = abi.encode(v3Pool, vaultAddress);
        AaveV3BufferHelper bufferHelper = AaveV3BufferHelper(
            deployer.deployContract(
                "testOrb Aave V3 Buffer Helper V0.0", creationCode, constructorArgs, 0
            )
        );

        vm.stopBroadcast();
    }
}
