// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";

contract SetPermissionsMainnetForkUSDC is Script {
    /**
     * @dev This contract is used to deploy the Arctic architecture with a specific configuration.
     * It inherits from DeployArcticArchitectureWithConfigScript to utilize its deployment logic.
     * source .env && forge script script/Permissions/SetPrvlAgentPermisionsSepoliaUSDC.s.sol:SetPermissionsSepoliaUSDC --broadcast-vvvv
     */

    uint256 internal privateKey;

    function setUp() external {
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
        vm.createSelectFork("local");
    }

    function run() external {
        vm.startBroadcast(privateKey);
        // Additional deployment agent logic
        /*
        * @dev Setup agent specific permissions for withdraws and deposits.
        */
        address DEPOSITOR_VAULT_ROLE_ADDRESS = 0x018F1c44D2628e66060382B66EE42c5EE485615f;
        address AGENT_TELLER = 0x5915964B4441930F5FfD13EcCA0A7D2f48e1d1A8;
        RolesAuthority ROLES_AUTHORITY = RolesAuthority(0x85aa8590E3f076aF23AF2cc29a743c481354A8cf);

        uint8 DEPOSITOR_VAULT_ROLE = 34;

        if (!ROLES_AUTHORITY.doesUserHaveRole(address(DEPOSITOR_VAULT_ROLE_ADDRESS), DEPOSITOR_VAULT_ROLE)) {
            ROLES_AUTHORITY.setUserRole(address(DEPOSITOR_VAULT_ROLE_ADDRESS), DEPOSITOR_VAULT_ROLE, true);
        }
        if (
            !ROLES_AUTHORITY.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, AGENT_TELLER, TellerWithMultiAssetSupport.bulkDeposit.selector
            )
        ) {
            ROLES_AUTHORITY.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, AGENT_TELLER, TellerWithMultiAssetSupport.bulkDeposit.selector, true
            );
        }
        if (
            !ROLES_AUTHORITY.doesRoleHaveCapability(
                DEPOSITOR_VAULT_ROLE, AGENT_TELLER, TellerWithMultiAssetSupport.bulkWithdraw.selector
            )
        ) {
            ROLES_AUTHORITY.setRoleCapability(
                DEPOSITOR_VAULT_ROLE, AGENT_TELLER, TellerWithMultiAssetSupport.bulkWithdraw.selector, true
            );
        }

        vm.stopBroadcast();
    }
}