// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SGHODecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SGHODecoderAndSanitizer.sol";

interface IGSM {
    function UNDERLYING_ASSET() external view returns (address);
}

contract SGHOIntegrationTest is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 24577143);
        _overrideDecoder(address(new SGHODecoderAndSanitizer()));
    }

    function testSGHOStakeAndRedeem() external {
        _setUpMainnet();

        uint256 stakeAmount = 100e18;
        deal(getAddress(sourceChain, "GHO"), address(boringVault), stakeAmount);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addSGHOLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Approve + Stake
        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0]; // approve
        tx_.manageLeafs[1] = leafs[1]; // stake

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "GHO");
        tx_.targets[1] = getAddress(sourceChain, "stkGHO");

        tx_.targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "stkGHO"), type(uint256).max);
        tx_.targetData[1] = abi.encodeWithSignature("stake(address,uint256)", address(boringVault), stakeAmount);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        uint256 stkGHOBalance = getERC20(sourceChain, "stkGHO").balanceOf(address(boringVault));
        assertGt(stkGHOBalance, 0, "BoringVault should have stkGHO after staking");

        // Cooldown
        {
            Tx memory cooldownTx = _getTxArrays(1);
            cooldownTx.manageLeafs[0] = leafs[2];

            bytes32[][] memory cooldownProofs = _getProofsUsingTree(cooldownTx.manageLeafs, manageTree);

            cooldownTx.targets[0] = getAddress(sourceChain, "stkGHO");
            cooldownTx.targetData[0] = abi.encodeWithSignature("cooldown()");
            cooldownTx.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

            _submitManagerCall(cooldownProofs, cooldownTx);
        }

        // Redeem
        {
            Tx memory redeemTx = _getTxArrays(1);
            redeemTx.manageLeafs[0] = leafs[3];

            bytes32[][] memory redeemProofs = _getProofsUsingTree(redeemTx.manageLeafs, manageTree);

            redeemTx.targets[0] = getAddress(sourceChain, "stkGHO");
            redeemTx.targetData[0] =
                abi.encodeWithSignature("redeem(address,uint256)", address(boringVault), stkGHOBalance);
            redeemTx.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

            _submitManagerCall(redeemProofs, redeemTx);
        }

        uint256 ghoAfterRedeem = getERC20(sourceChain, "GHO").balanceOf(address(boringVault));
        assertGt(ghoAfterRedeem, 0, "BoringVault should have GHO after redeem");
    }

    function testGSMBuyAndSell() external {
        _setUpMainnet();

        address gsmUsdc = getAddress(sourceChain, "gsmUsdc");
        ERC20 gsmUnderlying = ERC20(IGSM(gsmUsdc).UNDERLYING_ASSET());
        deal(getAddress(sourceChain, "GHO"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addGHOGSMLeafs(leafs, gsmUsdc, gsmUnderlying);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Approve GHO + buyAsset
        {
            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[0];
            tx_.manageLeafs[1] = leafs[2];

            bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = getAddress(sourceChain, "GHO");
            tx_.targets[1] = gsmUsdc;

            tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", gsmUsdc, type(uint256).max);
            tx_.targetData[1] = abi.encodeWithSignature("buyAsset(uint256,address)", 100e6, address(boringVault));

            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(manageProofs, tx_);
        }

        uint256 underlyingBalance = gsmUnderlying.balanceOf(address(boringVault));
        assertGt(underlyingBalance, 0, "BoringVault should have GSM underlying after buyAsset");

        // Approve underlying + sellAsset
        {
            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[1];
            tx_.manageLeafs[1] = leafs[3];

            bytes32[][] memory sellProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = address(gsmUnderlying);
            tx_.targets[1] = gsmUsdc;

            tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", gsmUsdc, type(uint256).max);
            tx_.targetData[1] =
                abi.encodeWithSignature("sellAsset(uint256,address)", underlyingBalance, address(boringVault));

            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(sellProofs, tx_);
        }

        assertGt(getERC20(sourceChain, "GHO").balanceOf(address(boringVault)), 0, "Should have GHO after sellAsset");
        assertEq(gsmUnderlying.balanceOf(address(boringVault)), 0, "GSM underlying should be fully sold");
    }
}
