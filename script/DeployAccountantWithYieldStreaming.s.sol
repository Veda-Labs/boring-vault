// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployAccountantWithYieldStreaming.s.sol:DeployAccountantWithYieldStreamingScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployAccountantWithYieldStreamingScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);
    address public boringVault = 0xA802bccD14F7e78e48FfE0C9cF9AD0273C77D4b0;
    address public payoutAddress = 0x1cdF47387358A1733968df92f7cC14546D9E1047;
    address public USDTsepolia = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
    address public tempOwner = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("sepolia");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(AccountantWithYieldStreaming).creationCode;
        constructorArgs = abi.encode(tempOwner, boringVault, payoutAddress, 1e6, USDTsepolia, 1.001e4, 0.999e4, 1, 0.1e4, 0.1e4);
        AccountantWithYieldStreaming accountant = AccountantWithYieldStreaming(
            deployer.deployContract(
                "InkedUSDT Accountant With Yield Streaming V0.0", creationCode, constructorArgs, 0
            )
        );

        accountant.setAuthority(Authority(0xecE2222D3ac4b21316b6E5F4208A452BB96A8Cb4));
        accountant.transferOwnership(address(0));

        vm.stopBroadcast();
    }
}