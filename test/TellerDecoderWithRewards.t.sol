// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {RewardData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

// Validates that TellerDecoderAndSanitizer correctly decodes withdrawWithRewards and claimRewards
// through the full ManagerWithMerkleVerification path.
//
// Merkle verification flow:
//   1. Admin publishes a merkle root where each leaf = keccak256(decoder, target, canSendValue, selector, addr0, addr1, ...)
//   2. Strategist submits a manage() call with a merkle proof
//   3. Manager forwards the raw calldata to the decoder via staticcall (same selector, same param types)
//   4. Decoder returns abi.encodePacked(addr0, addr1, ...) -- the "sanitized" addresses it extracted
//   5. Manager reconstructs the leaf from (decoder, target, value!=0, selector, extractedAddresses)
//      and verifies it against the merkle root + proof
//   6. If valid, vault.manage() executes the call on the target
//
// For these decoders the extracted addresses are:
//   withdrawWithRewards: [withdrawAsset, to, rewards[0].pool, rewards[1].pool, ...]
//   claimRewards:        [rewards[0].pool, rewards[1].pool, ...]
//
// The merkle leaf's argumentAddresses must list the SAME addresses in the SAME order that the
// decoder will extract at runtime. Any mismatch (wrong pool, extra pool, different order) causes
// the proof to fail, preventing unauthorized calls.

contract MockTellerTarget {
    function withdrawWithRewards(address, uint256, uint256, address, RewardData[] calldata)
        external
        pure
        returns (uint256)
    {
        return 1e18;
    }

    function claimRewards(RewardData[] calldata) external pure {}
}

contract TellerDecoderWithRewardsTest is Test, MerkleTreeHelper {
    BoringVault public vault;
    ManagerWithMerkleVerification public manager;
    TellerDecoderAndSanitizer public decoder;
    MockTellerTarget public mockTeller;
    RolesAuthority public rolesAuthority;

    uint8 constant MANAGER_ROLE = 1;
    uint8 constant STRATEGIST_ROLE = 2;
    uint8 constant ADMIN_ROLE = 4;

    function setUp() external {
        setSourceChainName("test");

        vault = new BoringVault(address(this), "Test Vault", "TV", 18);
        manager = new ManagerWithMerkleVerification(address(this), address(vault), address(0));
        decoder = new TellerDecoderAndSanitizer();
        mockTeller = new MockTellerTarget();

        setAddress(false, sourceChain, "boringVault", address(vault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", address(decoder));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        vault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE, address(vault), bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))), true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );

        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
    }

    function testWithdrawWithRewardsThroughManage() external {
        address withdrawAsset = vm.addr(1);
        address to = vm.addr(2);
        address pool0 = vm.addr(3);
        address pool1 = vm.addr(4);

        // Step 1: Build the merkle leaf.
        // argumentAddresses must list addresses in the exact order the decoder will extract them:
        //   [withdrawAsset, to, pool0, pool1]
        // The leaf hash = keccak256(decoder | mockTeller | false | selector | withdrawAsset | to | pool0 | pool1)
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(
            address(mockTeller),
            false,
            "withdrawWithRewards(address,uint256,uint256,address,(address,uint256,uint256,bytes)[])",
            new address[](4),
            "",
            address(decoder)
        );
        leafs[0].argumentAddresses[0] = withdrawAsset;
        leafs[0].argumentAddresses[1] = to;
        leafs[0].argumentAddresses[2] = pool0;
        leafs[0].argumentAddresses[3] = pool1;

        leafs[1] = ManageLeaf(address(0), false, "", new address[](0), "", address(decoder)); // padding leaf

        // Step 2: Generate the merkle tree and set the root on the manager.
        bytes32[][] memory tree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), tree[tree.length - 1][0]);

        // Step 3: Build the actual calldata that will be sent to the target.
        // The pool addresses in the RewardData[] MUST match what the leaf whitelisted,
        // because the decoder will extract them and the manager will recompute the leaf hash.
        RewardData[] memory rewards = new RewardData[](2);
        rewards[0] = RewardData(pool0, 100e18, block.timestamp + 1 hours, "");
        rewards[1] = RewardData(pool1, 50e18, block.timestamp + 1 hours, "");

        // Step 4: Get the merkle proof for our leaf.
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        bytes32[][] memory proofs = _getProofsUsingTree(manageLeafs, tree);

        address[] memory targets = new address[](1);
        targets[0] = address(mockTeller);

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            abi.encodeWithSelector(MockTellerTarget.withdrawWithRewards.selector, withdrawAsset, 1e18, 0, to, rewards);

        address[] memory decoders = new address[](1);
        decoders[0] = address(decoder);

        uint256[] memory values = new uint256[](1);

        // Step 5: Execute. Under the hood:
        //   a) Manager sends targetData to decoder via staticcall -> decoder returns packed [withdrawAsset, to, pool0, pool1]
        //   b) Manager recomputes leaf = keccak256(decoder | target | false | selector | packedAddresses)
        //   c) Manager verifies leaf against merkle root + proof
        //   d) On success, vault.manage(target, targetData, 0) calls the mock teller
        manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);
    }

    function testClaimRewardsThroughManage() external {
        address pool0 = vm.addr(5);
        address pool1 = vm.addr(6);

        // For claimRewards the only addresses to whitelist are the pool addresses.
        // Leaf hash = keccak256(decoder | mockTeller | false | selector | pool0 | pool1)
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(
            address(mockTeller),
            false,
            "claimRewards((address,uint256,uint256,bytes)[])",
            new address[](2),
            "",
            address(decoder)
        );
        leafs[0].argumentAddresses[0] = pool0;
        leafs[0].argumentAddresses[1] = pool1;

        leafs[1] = ManageLeaf(address(0), false, "", new address[](0), "", address(decoder));

        bytes32[][] memory tree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), tree[tree.length - 1][0]);

        // Pool addresses in calldata must match what the leaf whitelisted.
        RewardData[] memory rewards = new RewardData[](2);
        rewards[0] = RewardData(pool0, 100e18, block.timestamp + 1 hours, "");
        rewards[1] = RewardData(pool1, 50e18, block.timestamp + 1 hours, "");

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        bytes32[][] memory proofs = _getProofsUsingTree(manageLeafs, tree);

        address[] memory targets = new address[](1);
        targets[0] = address(mockTeller);

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSelector(MockTellerTarget.claimRewards.selector, rewards);

        address[] memory decoders = new address[](1);
        decoders[0] = address(decoder);

        uint256[] memory values = new uint256[](1);

        // Decoder extracts [pool0, pool1] from the RewardData array, manager verifies against merkle root.
        manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);
    }
}
