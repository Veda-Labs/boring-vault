// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { Deployer } from "src/helper/Deployer.sol";
import { RolesAuthority, Authority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { ContractNames } from "resources/ContractNames.sol";
import { MainnetAddresses } from "test/resources/MainnetAddresses.sol";
import { BoringOnChainQueue } from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployQueueOnly.s.sol:DeployQueueOnly --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployQueueOnly is Script, ContractNames, Test {
    uint256 public privateKey;

    Deployer deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);

    address owner = 0x1cdF47387358A1733968df92f7cC14546D9E1047;
    address auth = 0xecE2222D3ac4b21316b6E5F4208A452BB96A8Cb4;
    address payable boringVault = payable(0xA802bccD14F7e78e48FfE0C9cF9AD0273C77D4b0);
    address accountant = 0x0EA727A89faD61F73423f7E7D0EE37F8A7295B74;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("sepolia");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        creationCode = type(BoringOnChainQueue).creationCode;

        constructorArgs = abi.encode(owner, auth, boringVault, accountant);
        deployer.deployContract("Ink Sepolia Boring Queue 0.1", creationCode, constructorArgs, 0);
    }
}
