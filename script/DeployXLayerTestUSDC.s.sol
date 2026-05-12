// SPDX-License-Identifier: SEL-1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import "forge-std/Script.sol";

/**
 * Self-contained fork deploy for xlayer (chain id 196).
 *
 *   anvil --fork-url https://xlayer-mainnet.g.alchemy.com/v2/<KEY> -p 8545
 *   forge script script/DeployXLayerTestUSDC.s.sol --rpc-url http://localhost:8545 --broadcast --unlocked
 *
 * Deploys BoringVault + Manager + BaseDecoder + RolesAuthority, wires roles, sets a
 * 2-leaf merkle root (Approve USDC + Transfer USDC) for the dev1 strategist.
 */
contract DeployXLayerTestUSDCScript is Script {
    // xlayer mainnet
    address constant USDC = 0x74b7F16337b8972027F6196A17a631aC6dE26d22;

    // Anvil default account 0 (well-known) — used as owner/admin/deployer
    address constant OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Strategist address (matches veda-ds dev1)
    address constant DEV1 = 0xf8553c8552f906C19286F21711721E206EE4909E;

    // Recipient allow-listed in leaves
    address constant RECIPIENT = 0x000000000000000000000000000000000000dEaD;

    uint8 constant MANAGER_ROLE = 1;
    uint8 constant STRATEGIST_ROLE = 2;
    uint8 constant MANGER_INTERNAL_ROLE = 3;
    uint8 constant ADMIN_ROLE = 4;

    function run() external {
        vm.startBroadcast(OWNER);

        BoringVault vault = new BoringVault(OWNER, "Test xLayer USDC Vault", "testvUSDC", 6);
        ManagerWithMerkleVerification manager =
            new ManagerWithMerkleVerification(OWNER, address(vault), address(0));
        BaseDecoderAndSanitizer decoder = new BaseDecoderAndSanitizer();
        RolesAuthority auth = new RolesAuthority(OWNER, Authority(address(0)));

        vault.setAuthority(auth);
        manager.setAuthority(auth);

        // Capability wiring (mirrors test/ManagerWithMerkleVerification.t.sol)
        auth.setRoleCapability(
            MANAGER_ROLE,
            address(vault),
            bytes4(keccak256("manage(address,bytes,uint256)")),
            true
        );
        auth.setRoleCapability(
            MANAGER_ROLE,
            address(vault),
            bytes4(keccak256("manage(address[],bytes[],uint256[])")),
            true
        );
        auth.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        auth.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        auth.setRoleCapability(
            ADMIN_ROLE,
            address(manager),
            ManagerWithMerkleVerification.setManageRoot.selector,
            true
        );

        auth.setUserRole(address(manager), MANAGER_ROLE, true);
        auth.setUserRole(DEV1, STRATEGIST_ROLE, true);
        auth.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        auth.setUserRole(OWNER, ADMIN_ROLE, true);

        // Two leaves: approve + transfer of USDC, recipient hard-pinned
        // Digest layout: keccak256(decoder | target | canSendValue(1) | selector(4) | packedAddrArgs)
        bytes32 leafApprove = keccak256(
            abi.encodePacked(
                address(decoder),
                USDC,
                false,
                bytes4(keccak256("approve(address,uint256)")),
                RECIPIENT
            )
        );
        bytes32 leafTransfer = keccak256(
            abi.encodePacked(
                address(decoder),
                USDC,
                false,
                bytes4(keccak256("transfer(address,uint256)")),
                RECIPIENT
            )
        );

        // 2-leaf tree: root = keccak256(sorted_pair(leafA, leafB))
        bytes32 root = leafApprove < leafTransfer
            ? keccak256(abi.encodePacked(leafApprove, leafTransfer))
            : keccak256(abi.encodePacked(leafTransfer, leafApprove));

        manager.setManageRoot(DEV1, root);

        vm.stopBroadcast();

        console.log("=== xLayer testvUSDC deploy ===");
        console.log("BoringVault:    ", address(vault));
        console.log("Manager:        ", address(manager));
        console.log("Decoder:        ", address(decoder));
        console.log("RolesAuthority: ", address(auth));
        console.log("USDC (xlayer):  ", USDC);
        console.log("Strategist:     ", DEV1);
        console.log("Recipient:      ", RECIPIENT);
        console.log("ManageRoot:     ");
        console.logBytes32(root);
        console.log("leafApprove:    ");
        console.logBytes32(leafApprove);
        console.log("leafTransfer:   ");
        console.logBytes32(leafTransfer);
    }
}
