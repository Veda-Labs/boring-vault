// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import "forge-std/Script.sol";

contract SetPermissionsSepoliaUSDC is Script {
    /**
     * @dev This contract is used to deploy the Arctic architecture with a specific configuration.
     * It inherits from DeployArcticArchitectureWithConfigScript to utilize its deployment logic.
     * source .env && forge script script/Permissions/SetPrvlAgentPermisionsSepoliaUSDC.s.sol:SetPermissionsSepoliaUSDC --sig "run(string)" Sepolia/PrvlClientVaultUSDC.json --with-gas-price 3000000000 --broadcast --etherscan-api-key $SEPOLIASCAN_KEY --verify -vvvv --slow
     */

    uint256 internal privateKey;

    function setUp() external {
        privateKey = vm.envUint("PARAVEL_SEPOLIA_DEPLOYER");
        vm.createSelectFork("sepolia");
    }

    function run() external {
        vm.startBroadcast(privateKey);
        // Additional deployment agent logic
        /*
        * @dev Setup agent specific permissions for withdraws and deposits.
        */
        address DEPOSITOR_VAULT_ROLE_ADDRESS = 0x8e8452FbAC00D369D6691A82bfCf05174AD082DA;
        address AGENT_TELLER = 0xe078f23C21e130a630EA305355457e2CEBb61bff;
        RolesAuthority ROLES_AUTHORITY = RolesAuthority(0x1c7e8219d720a3C8125E12Db1D08863325D5a2F1);

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