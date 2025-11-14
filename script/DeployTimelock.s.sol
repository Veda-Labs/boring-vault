// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {TimelockController, AccessControl} from "@openzeppelin/contracts/governance/TimelockController.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTimelock.s.sol:DeployTimelockScript --with-gas-price 15000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployTimelockScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    Deployer public deployer;
    TimelockController public timelock;

    address public canceller = 0xD48b7e87fDCCaCa7ea93F347755c799eBE0fD35F;
    address public executor = 0xD48b7e87fDCCaCa7ea93F347755c799eBE0fD35F;
    address public proposer = 0xD48b7e87fDCCaCa7ea93F347755c799eBE0fD35F;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("plasma");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);
        creationCode = type(TimelockController).creationCode;

        uint256 minDelay = 0;
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        address[] memory executors = new address[](1);
        executors[0] = executor;
    
        address tempAdmin = 0x1cdF47387358A1733968df92f7cC14546D9E1047;
    
        constructorArgs = abi.encode(minDelay, proposers, executors, tempAdmin);
        timelock =
            TimelockController(payable(deployer.deployContract("Golden Goose Timelock V0.1", creationCode, constructorArgs, 0)));


        timelock.grantRole(timelock.CANCELLER_ROLE(), canceller);
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), tempAdmin);
        console.log("Timelock deployed to", address(timelock));
        vm.stopBroadcast();
    }
}
