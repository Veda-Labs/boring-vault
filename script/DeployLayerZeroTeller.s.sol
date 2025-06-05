// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {LayerZeroTeller} from
    "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {LayerZeroTellerWithRateLimiting} from
    "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerWithRateLimiting.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployLayerZeroTeller.s.sol:DeployLayerZeroTellerScript --with-gas-price 15000000000 --broadcast --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLayerZeroTellerScript is Script, ContractNames {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;
    LayerZeroTeller public layerZeroTeller;
    address internal deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address internal dev1Address = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address internal weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal boringVault = 0x83599937c2C9bEA0E0E8ac096c6f32e86486b410;
    address internal accountant = 0x04B8136820598A4e50bEe21b8b6a23fE25Df9Bd8;
    address internal lzEndPoint = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal delegate = dev1Address; // I do not think we need this functionality, but for future use, setDelegate has a requires auth modifier so it can be changed.

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);
        creationCode = type(LayerZeroTellerWithRateLimiting).creationCode;
        constructorArgs = abi.encode(dev1Address, boringVault, accountant, weth, lzEndPoint, delegate, address(0));
        layerZeroTeller = LayerZeroTeller(
            deployer.deployContract("liquidBeraETH LayerZero Teller V0.1", creationCode, constructorArgs, 0)
        );

        vm.stopBroadcast();
    }
}
