// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  forge script script/DeployManagerWithMerkleVerification.s.sol:DeployManagerWithMerkleVerification --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployManagerWithMerkleVerification is Script, ContractNames, Test {
    uint256 public privateKey;

    //liquidETH
    address boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);

    address tempOwner = 0x7E97CaFdd8772706dbC3c83d36322f7BfC0f63C7;
    address balancerVaultAddress = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address existingRolesAuthority = 0x485Bde66Bb668a51f2372E34e45B1c6226798122;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(ManagerWithMerkleVerification).creationCode;
        constructorArgs = abi.encode(tempOwner, boringVault, balancerVaultAddress);
        ManagerWithMerkleVerification newManager = ManagerWithMerkleVerification(
            deployer.deployContract(
                "EtherFi Liquid ETH Manager With Merkle Verification V0.2", creationCode, constructorArgs, 0
            )
        );

        newManager.setAuthority(RolesAuthority(existingRolesAuthority));
        newManager.transferOwnership(address(0));

        vm.stopBroadcast();
    }
}
