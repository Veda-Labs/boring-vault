// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";

import {PrvlAgentVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Paravel/PrvlAgentVaultDecoderAndSanitizer.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployPrvlAgentDecoderAndSanitizerMainnetFork.s.sol:DeployPrvlAgentDecoderAndSanitizerMainnetFork --rpc-url localhost:8545 --broadcast
 */
contract DeployPrvlAgentDecoderAndSanitizerMainnetFork is Script, Test, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x2A09312aE47190E1f068bc24e20bDDD63b79CA18);

    // Agent Vault - using actual deployed address from Local fork
    address boringVault = 0x3A29E2a5Ddb20C56D62a9D9Fa29b606833C4bf1d;

    function setUp() external {
        // This will connect to the mainnet fork
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // Deploy PrvlAgentVaultDecoderAndSanitizer
        creationCode = type(PrvlAgentVaultDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(boringVault);

        address deployedDecoder = deployer.deployContract("Prvl Agent Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);
        
        console.log("PrvlAgentVaultDecoderAndSanitizer deployed at:", deployedDecoder);

        vm.stopBroadcast();
    }
}