// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {Pauser} from "src/base/Roles/Pauser.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import "forge-std/Script.sol";

/**
 *
 * Usage (Trezor):
 *   forge script script/DeployMultiplePausers.s.sol:DeployMultiplePausers --trezor --broadcast -vvvv
 */
contract DeployMultiplePausers is Script, ChainValues, MainnetAddresses {
    string[] vaults = [
        "liquidBTC",
        "liquidETH",
        "liquidUSD",
        "sETHFI"
        // "weETHk",
        // "weETHs"
    ];

    string public sourceChain;

    Deployer public deployer = Deployer(deployerAddress);

    uint256 constant DESIRED_NUMBER_OF_DEPLOYMENT_TXS = 1;

    Deployer.Tx[] internal txs;

    // ──────────────────────────────────────────────────────────────────────────

    function setSourceChainName(string memory _chain) internal {
        sourceChain = _chain;
    }

    function getTxs() public view returns (Deployer.Tx[] memory) {
        return txs;
    }

    function _addTx(address target, bytes memory data, uint256 value) internal {
        txs.push(Deployer.Tx(target, data, value));
    }

    function setUp() external {
        setSourceChainName("optimism");
        vm.createSelectFork(sourceChain);
    }

    function run() external {
        bytes memory creationCode = type(Pauser).creationCode;
        bytes memory constructorArgs;

        IPausable[] memory pausables = new IPausable[](0);

        for (uint256 i = 0; i < vaults.length; i++) {
            address vault = getAddress("mainnet", vaults[i]); // mainnet because address should be same across chains
            Authority rolesAuthority = Auth(vault).authority();
            string memory name = BoringVault(payable(vault)).name();

            string memory deploymentName = string.concat(name, " Pauser V0.2");
            address _contract = deployer.getAddress(deploymentName);
            if (_contract.code.length > 0) {
                console.log(deploymentName, "already deployed at", _contract);
                continue;
            }

            constructorArgs = abi.encode(address(0), rolesAuthority, pausables);
            _addTx(
                address(deployer),
                abi.encodeWithSelector(deployer.deployContract.selector, deploymentName, creationCode, constructorArgs, 0),
                0
            );
            console.log(string.concat(unicode"✅", deploymentName, " deployment to"), _contract, ": TX added");
        }

        _bundleTxs();
    }

    function _bundleTxs() internal {
        Deployer.Tx[] memory txsToSend = getTxs();
        uint256 txsLength = txsToSend.length;

        if (txsLength == 0) {
            console.log("No txs to bundle");
            return;
        }

        // Determine how many txs to send
        uint256 desiredNumberOfDeploymentTxs = DESIRED_NUMBER_OF_DEPLOYMENT_TXS;
        if (desiredNumberOfDeploymentTxs == 0) {
            console.log("Desired number of deployment txs is 0");
            return;
        }
        desiredNumberOfDeploymentTxs =
            desiredNumberOfDeploymentTxs > txsLength ? txsLength : desiredNumberOfDeploymentTxs;
        uint256 txsPerBundle = txsLength / desiredNumberOfDeploymentTxs;
        uint256 lastIndexDeployed;
        Deployer.Tx[][] memory txBundles = new Deployer.Tx[][](desiredNumberOfDeploymentTxs);

        console.log(string.concat("Tx bundles to send: ", vm.toString(desiredNumberOfDeploymentTxs)));
        console.log(string.concat("Total txs: ", vm.toString(txsLength)));

        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            uint256 txsInBundle;
            if (i == desiredNumberOfDeploymentTxs - 1) {
                // Last bundle always collects all remaining transactions
                txsInBundle = txsLength - lastIndexDeployed;
            } else {
                txsInBundle = txsPerBundle;
            }
            txBundles[i] = new Deployer.Tx[](txsInBundle);
            for (uint256 j; j < txBundles[i].length; j++) {
                txBundles[i][j] = txsToSend[lastIndexDeployed + j];
            }
            lastIndexDeployed += txsInBundle;
        }

        // Read tx bundler address from configuration file.
        address txBundler = getAddress(sourceChain, "txBundlerAddress");

        vm.startBroadcast();
        for (uint256 i; i < desiredNumberOfDeploymentTxs; i++) {
            console.log(string.concat("Sending bundle: ", vm.toString(i)));
            Deployer(txBundler).bundleTxs(txBundles[i]);
        }
        vm.stopBroadcast();
    }
}
