// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {RolesAuthority, Auth, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/DeployIncentiveHandler.s.sol:DeployIncentiveHandlerScript --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployIncentiveHandlerScript is Script {
    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer;

    address public devOwner = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public owner = 0xf8553c8552f906C19286F21711721E206EE4909E;
    // Roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        deployer = Deployer(0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d);

        creationCode = type(RolesAuthority).creationCode;
        constructorArgs = abi.encode(devOwner, address(0));

        RolesAuthority rolesAuthority = RolesAuthority(
            deployer.deployContract("Incentive Handler RolesAuthority V0.0", creationCode, constructorArgs, 0)
        );

        creationCode = type(BoringVault).creationCode;
        constructorArgs = abi.encode(devOwner, "Incentive Handler", "IHB", 18);

        BoringVault vault = BoringVault(
            payable(deployer.deployContract("Incentive Handler Boring Vault V0.0", creationCode, constructorArgs, 0))
        );

        creationCode = type(ManagerWithMerkleVerification).creationCode;
        constructorArgs = abi.encode(devOwner, address(vault), address(0));

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(
            deployer.deployContract("Incentive Handler Manager V0.0", creationCode, constructorArgs, 0)
        );

        // Add roles
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE, address(vault), bytes4(abi.encodeWithSignature("manage(address,bytes,uint256)")), true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE, address(vault), bytes4(abi.encodeWithSignature("manage(address[],bytes[],uint256[])")), true
        );
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(vault), BoringVault.setBeforeTransferHook.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(vault), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(vault), Auth.transferOwnership.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(manager), Auth.setAuthority.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(manager), Auth.transferOwnership.selector, true);
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MULTISIG_ROLE, address(manager), ManagerWithMerkleVerification.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            OWNER_ROLE, address(manager), ManagerWithMerkleVerification.unpause.selector, true
        );

        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);

        vault.setAuthority(rolesAuthority);
        vault.transferOwnership(owner);
        manager.setAuthority(rolesAuthority);
        manager.transferOwnership(owner);
        rolesAuthority.transferOwnership(owner);

        vm.stopBroadcast();
    }
}
