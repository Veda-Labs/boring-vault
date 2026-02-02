// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {PaymentSplitter} from "src/helper/PaymentSplitter.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployPaymentSplitter.s.sol:DeployPaymentSplitter --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployPaymentSplitter is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.creled to submit contract verification, payload:ateSelectFork("ink");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        PaymentSplitter.SplitInformation memory sentoraSplit = PaymentSplitter.SplitInformation(
            7143,
            0xbE6b7dCa8D5FCE23B07E0Da9b01d466b95b3EDF3 
        );

        PaymentSplitter.SplitInformation memory vedaSplit = PaymentSplitter.SplitInformation(
            2857,
            0x68eC1FdD4Bb202B2e07aE751CB5553644aA48cFA
        );

        PaymentSplitter.SplitInformation[] memory splits = new PaymentSplitter.SplitInformation[](2); 
        splits[0] = sentoraSplit;
        splits[1] = vedaSplit;

        creationCode = type(PaymentSplitter).creationCode;
        constructorArgs = abi.encode(
            0xBBc5569B0b32403037F37255f4ff50B8Bb825b2A,
            10000,
            splits 
        );
        PaymentSplitter splitter = PaymentSplitter(
            deployer.deployContract(
                "SentayUSDC Payment Splitter V0.0", creationCode, constructorArgs, 0
            )
        );

        //transfer to roles auth
        splitter.transferOwnership(0x0C5CBb9d0842e36D0865fFC1d78a3d7019Bb5c99); //sentayUSDC roles auth 

        vm.stopBroadcast();
    }
}
