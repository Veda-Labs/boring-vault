// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {MockERC20} from "src/helper/MockERC20.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import "forge-std/Test.sol";

/**
 *  forge script script/DeployDeployer.s.sol:DeployDeployerScript --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDeployerScript is Script, ContractNames, Test {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;

    address public deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    //address public deployerAddress = 0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0;
    //address public dev0Address = 0x4AB9A68D93271EFF863fFc3F5091d6F050f48eDA; //bob deployer account (dead)
    
    address public troglobyte  = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public dev0Address = 0x32E97eACfb62Ae1cC4d73CF702361292C761f8c4;
    address public dev1Address = 0x3c1F21c8DF616D7Ab065a8A2724aC44A7439E201;
    address public dev2Address = 0x60730d712AD2b12540ea4cE79a0222d73B0Ce4B8;
    address public dev3Address = 0x7917Bef76908908631C38345394fe9D99ADb9340;
    address public dev4Address = 0xBacacbdc7d88Ba1F4b6ac49A28Ef1322a1E7FCb2;
    address public dev5Address = 0xE8fBB28619281002212442AB9f2Ac0416C27DbA3;

    uint8 public DEPLOYER_ROLE = 1;

    function setUp() external {

        //privateKey = vm.envUint("BORING_DEVELOPER");
        //vm.createSelectFork("mainnet");
        privateKey = vm.envUint("TROGLOBYTE");
        vm.createSelectFork("xlayer");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        deployer = new Deployer(troglobyte, Authority(address(0)));
        require(address(deployer) == deployerAddress);
        console.log("deployer address:", address(deployer));

        require(address(deployer) == deployerAddress, "Deployer address mismatch");
        console.log(address(deployer)); 

        creationCode = type(RolesAuthority).creationCode;
        constructorArgs = abi.encode(troglobyte, address(0));
        rolesAuthority = RolesAuthority(
            deployer.deployContract("Seven Seas RolesAuthority Version 0.1", creationCode, constructorArgs, 0)
        );

        require(rolesAuthority.owner() == address(troglobyte));

        deployer.setAuthority(rolesAuthority);

        //rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.deployContract.selector, true);
        //rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.bundleTxs.selector, true);
        //rolesAuthority.setUserRole(dev0Address, DEPLOYER_ROLE, true);
        //rolesAuthority.setUserRole(dev1Address, DEPLOYER_ROLE, true);
        //rolesAuthority.setUserRole(address(deployer), DEPLOYER_ROLE, true);

        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.deployContract.selector, true);
        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.bundleTxs.selector, true);
        rolesAuthority.setUserRole(dev0Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev1Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev2Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev3Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev4Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev5Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(address(deployer), DEPLOYER_ROLE, true);


        // deployer = Deployer(deployerAddress);

        // constructorArgs = abi.encode("Crispy Coin", "CC", 18);
        // creationCode = type(MockERC20).creationCode;
        // MockERC20(deployer.deployContract("CrispyCoin V0.0", creationCode, constructorArgs, 0));

        vm.stopBroadcast();
    }
}
