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
 *   forge script script/DeployMultiplePausers.s.sol:DeployMultiplePausers --rpc-url <RPC_URL> --trezor --broadcast --slow -vvvv
 */
contract DeployMultiplePausers is Script, ChainValues, MainnetAddresses {
    string[] vaults = [
        "eBTC",
        "eUSD",
        "liquidBTC",
        "liquidETH",
        "liquidUSD",
        "sETHFI",
        "weETHk",
        "weETHs"
    ];

    // ──────────────────────────────────────────────────────────────────────────

    function run() external {
        bytes memory creationCode = type(Pauser).creationCode;
        bytes memory constructorArgs;
        Deployer deployer = Deployer(deployerAddress);

        IPausable[] memory pausables = new IPausable[](0);

        vm.startBroadcast();

        for (uint256 i = 0; i < vaults.length; i++) {
            address vault = getAddress("mainnet", vaults[i]);
            Authority rolesAuthority = Auth(vault).authority();
            string memory name = BoringVault(payable(vault)).name();
            
            constructorArgs = abi.encode(address(0), rolesAuthority, pausables);
            deployer.deployContract(string.concat(name, " Pauser V0.2"), creationCode, constructorArgs, 0);
        }

        vm.stopBroadcast();
    }
}
