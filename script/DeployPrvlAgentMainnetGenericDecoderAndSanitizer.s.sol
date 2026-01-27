// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {SepoliaAddresses} from "test/resources/SepoliaAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";

import {PrvlAgentVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Paravel/PrvlAgentVaultDecoderAndSanitizer.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  source .env && forge script script/DeployPrvlAgentMainnetGenericDecoderAndSanitizer.s.sol:Deploy --broadcast --verify -vvvv --slow
 */

contract Deploy is Script, Test, ContractNames, SepoliaAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(0x70A3d136472aB0bda4635D194543A2afBaD098c8);


    function setUp() external {
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        vm.startBroadcast(privateKey);

        // Deploy PrvlAgentVaultDecoderAndSanitizer
        creationCode = type(PrvlAgentVaultDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode();

        deployer.deployContract("iPrvlAgent Decoder and Sanitizer V0.2", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
