// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {SepoliaAddresses} from "test/resources/SepoliaAddresses.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployPrvlMainnetForkDeployer.s.sol:Deploy --broadcast --etherscan-api-key $SEPOLIASCAN_KEY --verify --slow
 */
contract Deploy is Script, ContractNames, SepoliaAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;
    address public dev0address = vm.envAddress("LOCAL_DEPLOYER_ADDRESS");

    uint8 public DEPLOYER_ROLE = 1;

    function setUp() external {
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
        vm.createSelectFork("local");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = new Deployer(dev0address, Authority(address(0)));
        require(address(deployer) == 0x2A09312aE47190E1f068bc24e20bDDD63b79CA18, "Deployer deployment failed: DeployPrvlMainnetForkDeployer.s.sol:36");
        creationCode = type(RolesAuthority).creationCode;
        constructorArgs = abi.encode(dev0address, Authority(address(0)));
        rolesAuthority =
            RolesAuthority(deployer.deployContract("Paravel USDC Test Deployer RolesAuthority V0.0", creationCode, constructorArgs, 0));

        deployer.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.deployContract.selector, true);
        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(deployer), Deployer.bundleTxs.selector, true);
        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(rolesAuthority), RolesAuthority.setRoleCapability.selector, true);
        rolesAuthority.setRoleCapability(DEPLOYER_ROLE, address(rolesAuthority), RolesAuthority.setUserRole.selector, true);
        rolesAuthority.setUserRole(dev0address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(dev0address, DEPLOYER_ROLE, true);
        rolesAuthority.setUserRole(address(deployer), DEPLOYER_ROLE, true);

        vm.stopBroadcast();
    }
}
