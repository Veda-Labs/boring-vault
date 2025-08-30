// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTellerWithYieldStreaming.s.sol:DeployTellerWithYieldStreamingScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTellerWithYieldStreamingScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);
    //address public bufferHelper = ; //for now set to address(0) aka vault itself
    address public accountant = ;
    address public boringVault = 0xA802bccD14F7e78e48FfE0C9cF9AD0273C77D4b0;
    address public WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public USDT = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("sepolia");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(TellerWithYieldStreaming).creationCode;
        constructorArgs = abi.encode(msg.sender, boringVault, accountant, WETH);
        TellerWithYieldStreaming teller = TellerWithYieldStreaming(
            deployer.deployContract(
                "Kraken Test Teller With Yield Streaming 0.0", creationCode, constructorArgs, 0
            )
        );
        teller.updateAssetData(USDT, true, true, 0);
        //teller.allowBufferHelper(USDT, bufferHelper); for now set to address(0) aka vault itself
        //teller.setBufferHelper(bufferHelper); for now set to address(0) aka vault itself
        teller.setAuthority(Authority(0xecE2222D3ac4b21316b6E5F4208A452BB96A8Cb4));
        teller.transferOwnership(address(0));

        vm.stopBroadcast();
    }
}
