// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {InfinifiDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/InfinifiDecoderAndSanitizer.sol";

contract InfinifiIntegrationTest is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 25130000);
        _overrideDecoder(address(new InfinifiDecoderAndSanitizer()));
    }

    function testInfinifiMintStakeAndUnstake() external {
        _setUpMainnet();

        uint256 usdcAmount = 100e6;
        deal(getAddress(sourceChain, "USDC"), address(boringVault), usdcAmount);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addInfinifiLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Approve USDC + mint iUSD
        {
            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[0]; // approve USDC
            tx_.manageLeafs[1] = leafs[3]; // mint

            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = getAddress(sourceChain, "USDC");
            tx_.targets[1] = getAddress(sourceChain, "infinifiGateway");

            tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "infinifiGateway"), type(uint256).max);
            tx_.targetData[1] = abi.encodeWithSignature("mint(address,uint256)", address(boringVault), usdcAmount);

            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(proofs, tx_);
        }

        uint256 iUSDBalance = getERC20(sourceChain, "iUSD").balanceOf(address(boringVault));
        assertGt(iUSDBalance, 0, "BoringVault should have iUSD after mint");

        // Approve iUSD + stake for siUSD
        {
            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[1]; // approve iUSD
            tx_.manageLeafs[1] = leafs[5]; // stake

            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = getAddress(sourceChain, "iUSD");
            tx_.targets[1] = getAddress(sourceChain, "infinifiGateway");

            tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "infinifiGateway"), type(uint256).max);
            tx_.targetData[1] = abi.encodeWithSignature("stake(address,uint256)", address(boringVault), iUSDBalance);

            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(proofs, tx_);
        }

        uint256 siUSDBalance = getERC20(sourceChain, "siUSD").balanceOf(address(boringVault));
        assertGt(siUSDBalance, 0, "BoringVault should have siUSD after stake");
        assertEq(getERC20(sourceChain, "iUSD").balanceOf(address(boringVault)), 0, "iUSD should be fully staked");

        // Approve siUSD + unstake
        {
            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[2]; // approve siUSD
            tx_.manageLeafs[1] = leafs[6]; // unstake

            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = getAddress(sourceChain, "siUSD");
            tx_.targets[1] = getAddress(sourceChain, "infinifiGateway");

            tx_.targetData[0] = abi.encodeWithSignature(
                "approve(address,uint256)", getAddress(sourceChain, "infinifiGateway"), type(uint256).max
            );
            tx_.targetData[1] =
                abi.encodeWithSignature("unstake(address,uint256)", address(boringVault), siUSDBalance);

            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(proofs, tx_);
        }

        assertGt(getERC20(sourceChain, "iUSD").balanceOf(address(boringVault)), 0, "BoringVault should have iUSD after unstake");
        assertEq(getERC20(sourceChain, "siUSD").balanceOf(address(boringVault)), 0, "siUSD should be fully unstaked");
    }

    function testInfinifiMintAndStake() external {
        _setUpMainnet();

        uint256 usdcAmount = 100e6;
        deal(getAddress(sourceChain, "USDC"), address(boringVault), usdcAmount);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addInfinifiLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Approve USDC + mintAndStake (USDC -> siUSD in one call)
        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0]; // approve USDC
        tx_.manageLeafs[1] = leafs[4]; // mintAndStake

        bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDC");
        tx_.targets[1] = getAddress(sourceChain, "infinifiGateway");

        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "infinifiGateway"), type(uint256).max);
        tx_.targetData[1] = abi.encodeWithSignature("mintAndStake(address,uint256)", address(boringVault), usdcAmount);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(proofs, tx_);

        assertGt(getERC20(sourceChain, "siUSD").balanceOf(address(boringVault)), 0, "BoringVault should have siUSD after mintAndStake");
        assertEq(getERC20(sourceChain, "USDC").balanceOf(address(boringVault)), 0, "USDC should be fully consumed");
    }

    function testInfinifiRedeem() external {
        _setUpMainnet();

        uint256 usdcAmount = 100e6;
        deal(getAddress(sourceChain, "USDC"), address(boringVault), usdcAmount);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addInfinifiLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Mint iUSD from USDC first
        {
            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[0]; // approve USDC
            tx_.manageLeafs[1] = leafs[3]; // mint

            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = getAddress(sourceChain, "USDC");
            tx_.targets[1] = getAddress(sourceChain, "infinifiGateway");

            tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "infinifiGateway"), type(uint256).max);
            tx_.targetData[1] = abi.encodeWithSignature("mint(address,uint256)", address(boringVault), usdcAmount);

            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(proofs, tx_);
        }

        uint256 iUSDBalance = getERC20(sourceChain, "iUSD").balanceOf(address(boringVault));
        assertGt(iUSDBalance, 0, "BoringVault should have iUSD before redeem");

        // Approve iUSD + redeem iUSD for USDC
        {
            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[1]; // approve iUSD
            tx_.manageLeafs[1] = leafs[7]; // redeem

            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = getAddress(sourceChain, "iUSD");
            tx_.targets[1] = getAddress(sourceChain, "infinifiGateway");

            tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "infinifiGateway"), type(uint256).max);
            tx_.targetData[1] = abi.encodeWithSignature("redeem(address,uint256,uint256)", address(boringVault), iUSDBalance, 0);

            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(proofs, tx_);
        }

        assertGt(getERC20(sourceChain, "USDC").balanceOf(address(boringVault)), 0, "BoringVault should have USDC after instant redeem");

    }
}
