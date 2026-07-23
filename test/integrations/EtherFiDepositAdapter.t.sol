// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullEtherFiDecoderAndSanitizer is EtherFiDecoderAndSanitizer, BaseDecoderAndSanitizer {}

contract EtherFiDepositAdapterIntegration is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 25596500);

        address etherFiDecoder = address(new FullEtherFiDecoderAndSanitizer());

        _overrideDecoder(etherFiDecoder);
    }

    function _setupLeafs() internal returns (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) {
        // 0: depositETHForWeETH (canSendValue)
        // 1: approve WETH -> depositAdapter
        // 2: depositWETHForWeETH
        leafs = new ManageLeaf[](4);
        _addEtherFiDepositAdapterLeafs(leafs);

        manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
    }

    function testEthDeposit() external {
        _setUpMainnet();

        vm.deal(address(boringVault), 10e18);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setupLeafs();

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; //depositETHForWeETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "depositAdapter");
        tx_.targetData[0] = abi.encodeWithSignature("depositETHForWeETH(address)", address(0));
        tx_.values[0] = 5e18;
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 weETHBalanceBefore = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault));

        _submitManagerCall(manageProofs, tx_);

        uint256 weETHBalanceAfter = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault));
        assertGt(weETHBalanceAfter, weETHBalanceBefore);
    }

    function testWethDeposit() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setupLeafs();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[1]; //approve WETH
        tx_.manageLeafs[1] = leafs[2]; //depositWETHForWeETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = getAddress(sourceChain, "depositAdapter");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "depositAdapter"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature("depositWETHForWeETH(uint256,address)", 5e18, address(0));

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 weETHBalanceBefore = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault));

        _submitManagerCall(manageProofs, tx_);

        uint256 weETHBalanceAfter = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault));
        assertGt(weETHBalanceAfter, weETHBalanceBefore);
    }
}
