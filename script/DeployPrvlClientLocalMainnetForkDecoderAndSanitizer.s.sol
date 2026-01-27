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
 *  source .env && forge script script/DeployPrvlClientLocalMainnetForkDecoderAndSanitizer.s.sol:Deploy  --broadcast
 */
contract Deploy is Script, Test, ContractNames, SepoliaAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x2A09312aE47190E1f068bc24e20bDDD63b79CA18);

    //Agent Vault
    address boringVault = 0xECE86117b965561642ac69f6bF0606fb80De1B76;

    function setUp() external {
        vm.createSelectFork("local");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // Deploy PrvlAgentVaultDecoderAndSanitizer
        creationCode = type(PrvlClientVaultDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(boringVault);

        deployer.deployContract("Prvl Client Vault Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
