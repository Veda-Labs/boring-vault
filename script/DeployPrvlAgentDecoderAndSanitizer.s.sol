// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {SepoliaAddresses} from "test/resources/SepoliaAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";

import {PrvlClientVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Paravel/PrvlClientVaultDecoderAndSanitizer.sol";
import {PrvlAgentVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Paravel/PrvlAgentVaultDecoderAndSanitizer.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployPrvlAgentDecoderAndSanitizer.s.sol:DeployPrvlAgentDecoderAndSanitizer --with-gas-price 30000000000 --broadcast --etherscan-api-key $SEPOLIASCAN_KEY --verify --slow
 */
contract DeployPrvlAgentDecoderAndSanitizer is Script, Test, ContractNames, SepoliaAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(prvlDeployer);

    //Agent Vault
    address boringVault = 0xfDf1AE0F6Eea711D74456E7D322E1ddFD4ab6b49;

    function setUp() external {
        vm.createSelectFork("sepolia");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        privateKey = vm.envUint("PARAVEL_SEPOLIA_DEPLOYER");
        vm.startBroadcast(privateKey);

        // Deploy PrvlAgentVaultDecoderAndSanitizer
        creationCode = type(PrvlAgentVaultDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(boringVault);

        deployer.deployContract("Prvl Agent Vault Decoder and Sanitizer V0.52", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
