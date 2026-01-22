// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { MainnetAddresses } from "test/resources/MainnetAddresses.sol";
import { ContractNames } from "resources/ContractNames.sol";
import { Deployer } from "src/helper/Deployer.sol";
import { RolesAuthority, Authority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { TellerWithMultiAssetSupport } from "src/base/Roles/TellerWithMultiAssetSupport.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployTeller.s.sol:DeployTellerScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract AssignRoles is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);

    function setUp() external {
        privateKey = vm.envUint("TROGLOBYTE");
        vm.createSelectFork("mainnet");

        //TODO how to run this through all the chains 1 by 1? maybe we have this in a bash script or something
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        address rolesAuthForDeployer = 0x4df6b73328B639073db150C4584196c4d97053b7;
        
        //get all the addresses
        address[] memory hardwareWallets = new address()[5]; 
        hardwareWallets[0] = 0x7917Bef76908908631C38345394fe9D99ADb9340; 
        hardwareWallets[1] = 0xbacacbdc7d88ba1f4b6ac49a28ef1322a1e7fcb2;
        hardwareWallets[2] = 0x32E97eACfb62Ae1cC4d73CF702361292C761f8c4;
        hardwareWallets[3] = 0xE8fBB28619281002212442AB9f2Ac0416C27DbA3;
        hardwareWallets[4] = 0x60730d712AD2b12540ea4cE79a0222d73B0Ce4B8;
        
        for (uint256 i; i < hardwareWallets.length; i++) {
            RolesAuthority(rolesAuthForDeployer).setUserRole(hardwareWallets[i], 1, true); 
        }

        //remove ryan
        address ryan = 0x1cdF47387358A1733968df92f7cC14546D9E1047;
        RolesAuthority(rolesAuthForDeployer).setUserRole(hardwareWallets[i], 1, false);  

        vm.stopBroadcast();
    }
}
