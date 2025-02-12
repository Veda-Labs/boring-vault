// SPDX-License-Identifier: UNLICENSED
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

    //address public deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address public deployerAddress = 0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0; 
    //address public dev0Address = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public dev0Address = 0x4AB9A68D93271EFF863fFc3F5091d6F050f48eDA;
    address public dev1Address = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address public dev2Address = 0xBBc5569B0b32403037F37255f4ff50B8Bb825b2A;
    address public dev3Address = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;

    uint8 public DEPLOYER_ROLE = 1;

    function setUp() external {
        privateKey = vm.envUint("DEPLOYER_KEY");
        vm.createSelectFork("bob");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        deployer = new Deployer(dev0Address, Authority(address(0)));

        console.log("DEPLOYER ADDRESS ", address(deployer)); 

        require(address(deployer) == deployerAddress, "Deployer address mismatch");
        creationCode = type(RolesAuthority).creationCode;
        constructorArgs = abi.encode(dev0Address, address(0));
        rolesAuthority = RolesAuthority(
            deployer.deployContract("Seven Seas RolesAuthority Version 0.1", creationCode, constructorArgs, 0)
        );

        deployer.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.deployContract.selector, true);
        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.bundleTxs.selector, true);
        rolesAuthority.setUserRole(dev0Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev1Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev2Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev3Address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(address(deployer), DEPLOYER_ROLE, true);

        // deployer = Deployer(deployerAddress);

        // constructorArgs = abi.encode("Crispy Coin", "CC", 18);
        // creationCode = type(MockERC20).creationCode;
        // MockERC20(deployer.deployContract("CrispyCoin V0.0", creationCode, constructorArgs, 0));

        vm.stopBroadcast();
    }
}
