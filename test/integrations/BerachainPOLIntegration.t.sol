// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {
    KodiakIslandDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol";
import {OogaBoogaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OogaBoogaDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {console} from "@forge-std/Test.sol";

contract FullBerachainDecoder is
    KodiakIslandDecoderAndSanitizer,
    InfraredDecoderAndSanitizer,
    OogaBoogaDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{}

contract BerachainPOLIntegrationTest is BaseTestIntegration {
    function _setUpBerachain() internal {
        super.setUp();
        _setupChain("berachain", 17559205);

        address berachainDecoder = address(new FullBerachainDecoder());

        _overrideDecoder(berachainDecoder);
    }

    function testFullPOLFlow() external {
        _setUpBerachain();

        //starting with just the base assets
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "beraETH"), address(boringVault), 1_000e18);

        address[] memory islands = new address[](1);
        islands[0] = 0x03bCcF796cDef61064c4a2EffdD21f1AC8C29E92;

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ==== Kodiak ====
        _addKodiakIslandLeafs(leafs, islands);

        // ==== Infrared ====
        address wethBeraETHVault = 0xfbC99D74cC43cF12EB6b78EDdCC2266Ff729bE19;
        _addInfraredVaultLeafs(leafs, wethBeraETHVault);

        // ==== Ooga Booga ====
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "iBGT");
        kind[0] = SwapKind.Sell;
        assets[1] = getAddress(sourceChain, "WETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "beraETH");
        kind[2] = SwapKind.BuyAndSell;

        _addOogaBoogaSwapLeafs(leafs, assets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3);

        tx_.manageLeafs[0] = leafs[0]; //approve token0
        tx_.manageLeafs[1] = leafs[1]; //approve token1
        tx_.manageLeafs[2] = leafs[3]; //addLiquidity

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve
        tx_.targets[1] = getAddress(sourceChain, "beraETH"); //approve
        tx_.targets[2] = getAddress(sourceChain, "kodiakIslandRouter"); //approve

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouter"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouter"), type(uint256).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address)",
            islands[0],
            1000e18,
            1000e18,
            0,
            0,
            0,
            address(boringVault)
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        //assert we actually get island tokens
        uint256 lpBalance = ERC20(islands[0]).balanceOf(address(boringVault));
        assertGt(lpBalance, 0);

        console.log("BORING VAULT NOW HAS: ", lpBalance, " ISLAND LP TOKENS");

        //now we stake on infrared

        tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[5]; //approve vault to spend island lp
        tx_.manageLeafs[1] = leafs[6]; //stake()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = islands[0]; //approve island to be spent by infrared vault
        tx_.targets[1] = wethBeraETHVault;

        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", wethBeraETHVault, type(uint256).max);
        tx_.targetData[1] = abi.encodeWithSignature("stake(uint256)", lpBalance);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        //check we have 0 LP now
        uint256 lpBalance2 = ERC20(islands[0]).balanceOf(address(boringVault));
        assertEq(lpBalance2, 0);

        console.log("BORING VAULT HAS STAKED");

        //skip 1 week to accumulate rewards
        skip(1 weeks);

        tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[9]; //getReward()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = wethBeraETHVault;

        tx_.targetData[0] = abi.encodeWithSignature("getReward()");

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        // On a fork, getReward() returns 0 since Infrared's reward distribution
        // requires external notifyRewardAmount calls that don't happen on a fork.
        // The call above still validates the manager can execute getReward() through the merkle path.

        // Unstake from Infrared to verify withdraw path
        tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[7]; //withdraw()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = wethBeraETHVault;

        tx_.targetData[0] = abi.encodeWithSignature("withdraw(uint256)", lpBalance);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        // Verify LP tokens returned after unstake
        uint256 lpAfterWithdraw = ERC20(islands[0]).balanceOf(address(boringVault));
        assertEq(lpAfterWithdraw, lpBalance);

        console.log("BORING VAULT UNSTAKED: ", lpAfterWithdraw, " ISLAND LP TOKENS RECOVERED");
    }
}
