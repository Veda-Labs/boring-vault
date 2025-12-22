// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {
    KingClaimingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/KingClaimingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullKingClaimingDecoderAndSanitizer is KingClaimingDecoderAndSanitizer {}

contract KingRewardsClaimingIntegration is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 22282617);

        address kingDecoder = address(new FullKingClaimingDecoderAndSanitizer());

        _overrideDecoder(kingDecoder);
    }

    function testKingRewardsClaiming() external {
        _setUpMainnet();

        //starting with just the base assets
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        address[] memory depositTokens = new address[](2);
        depositTokens[0] = getAddress(sourceChain, "ETHFI");
        depositTokens[1] = getAddress(sourceChain, "EIGEN");
        address claimFor = 0x09CdfF26536BCfd97E14FB06880B21b7bb9e729A;

        _addKingRewardsClaimingLeafs(leafs, depositTokens, claimFor);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[4]; //claim

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "kingMerkleDistributor"); //claim

        bytes32 root = 0x7c2229cfe3ad53683ed32e59062880d383c431240dfc1d33ee68cc9af646e6db;

        bytes32[] memory claimProofs = new bytes32[](20);
        claimProofs[0] = 0xf3aa01b2022cd135c973cdf7cc6ed8105af988cab16df1727453ceb06b106a97;
        claimProofs[1] = 0xa7fca71a6c585854c613fac44d7280be65dad2096bc9370b91267d1b0c46cf1b;
        claimProofs[2] = 0xc9fa5dfa06162d001a11cc5c3211b8034b44acbcadee827d08254255e06d61bb;
        claimProofs[3] = 0xcd4399ea8ad07b58d7eca27273234f3b760a96e38e673060bb6e0e20ab1f88ca;
        claimProofs[4] = 0xbd970cae30df062b7de39126d3e99b3b127b0c67b87d4ecdb675a723e29a43f3;
        claimProofs[5] = 0xdd2cb56ae5dc344eca11d72c20173149e4a2483e6f3080fb13e539bdd6313c04;
        claimProofs[6] = 0x786e674c0844f7a5709218c8239e561cd3ac87f0c9423a3cfb26c19ffbd5cf2b;
        claimProofs[7] = 0x568fba2c92050c6186b0b6253c5b49e85a23b999b122b522695c58bc9441dd12;
        claimProofs[8] = 0x31626ca41c415594e600e42e3c9ad6b8c5c9597767ad17c73a2f9b3d871a4ee8;
        claimProofs[9] = 0xef456640c1ae08e725ba0dced39e087c66a9ef1b386f9f69bc68e7114512ca5b;
        claimProofs[10] = 0x097dbd640176967c565fdff3fb2ca06bf08b9c2234ef97ffad14574c1ff3786b;
        claimProofs[11] = 0xfc8cf209da1c89db31f3677356ca6c0923a308cad20f00d46e0e72ebd40b2e78;
        claimProofs[12] = 0x34928f93132c3aff063b21919ae6f6318d0cffb57d4b4f652efe606a92ecc577;
        claimProofs[13] = 0x764c91af7e32f7f0194f76152d34ff051b510e0e07ed422c730c4fe2fe31767a;
        claimProofs[14] = 0x969908e513a871389d7268379f8759170df5468bca725fe5de8ec1b2571cdac2;
        claimProofs[15] = 0x92fcf36c3043d69bf2018b7f80f18d6273ca7548ea1d38bc0162689a0006b1f0;
        claimProofs[16] = 0xd1218d64b267d8538873e2f2c866ffdc4eb81082341eab5302cf0010e66da462;
        claimProofs[17] = 0x595ce98dd699c4f90b3d1e673665fbf1b2e3d4be8a970b2ac70a9ac8cdc5dc90;
        claimProofs[18] = 0x140082736a3fb43f631c406b173a7f85e5adc0bb1eba7c8128f574c14ee95b7d;
        claimProofs[19] = 0x57f6a51fadf2ba293b456bb71295295b1b81e3db7ae0ede5038f5f972527d800;

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "claim(address,uint256,bytes32,bytes32[])", claimFor, 2213478001621304080, root, claimProofs
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function testKingRedeem() external {
        _setUpMainnet();

        //starting with just the base assets
        deal(getAddress(sourceChain, "KING"), address(boringVault), 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        address[] memory depositTokens = new address[](2);
        depositTokens[0] = getAddress(sourceChain, "ETHFI");
        depositTokens[1] = getAddress(sourceChain, "EIGEN");
        address claimFor = 0x09CdfF26536BCfd97E14FB06880B21b7bb9e729A;

        _addKingRewardsClaimingLeafs(leafs, depositTokens, claimFor);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[3]; //redeem

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "KING"); //claim

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature("redeem(uint256)", 1e18);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function testKingDeposit() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "ETHFI"), address(boringVault), 1e18);
        deal(getAddress(sourceChain, "EIGEN"), address(boringVault), 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        address[] memory depositTokens = new address[](2);
        depositTokens[0] = getAddress(sourceChain, "ETHFI");
        depositTokens[1] = getAddress(sourceChain, "EIGEN");
        address claimFor = 0x09CdfF26536BCfd97E14FB06880B21b7bb9e729A;

        _addKingRewardsClaimingLeafs(leafs, depositTokens, claimFor);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3);

        tx_.manageLeafs[0] = leafs[0]; //approve ethfi
        tx_.manageLeafs[1] = leafs[1]; //approve eigen
        tx_.manageLeafs[2] = leafs[2]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "ETHFI"); //approve
        tx_.targets[1] = getAddress(sourceChain, "EIGEN"); //approve
        tx_.targets[2] = getAddress(sourceChain, "KING"); //deposit

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "KING"), 1e18);
        tx_.targetData[1] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "KING"), 1e18);

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 1e18;

        tx_.targetData[2] = abi.encodeWithSignature(
            "deposit(address[],uint256[],address)", depositTokens, amounts, address(boringVault)
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        vm.expectRevert(); //onlyDepositors(); //0x0afa41a8
        _submitManagerCall(manageProofs, tx_);
    }
}
