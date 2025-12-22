// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseTestIntegration } from "test/integrations/BaseTestIntegration.t.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SwellDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/SwellDecoderAndSanitizer.sol";
import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

contract FullSwellDecoderAndSanitizer is SwellDecoderAndSanitizer { }

contract RsWETHUnstakingIntegration is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 22_327_180);

        address swellDecoder = address(new FullSwellDecoderAndSanitizer());

        _overrideDecoder(swellDecoder);
    }

    function testSwellUnstaking() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "RSWETH"), address(boringVault), 10e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addRsWETHUnstakingLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[1]; //approve
        tx_.manageLeafs[1] = leafs[2]; //request unstake

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "RSWETH"); //approve
        tx_.targets[1] = getAddress(sourceChain, "rswEXIT");

        tx_.targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "rswEXIT"), type(uint256).max);
        tx_.targetData[1] = abi.encodeWithSignature("createWithdrawRequest(uint256)", 1e18);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        skip(22 days);

        tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[3]; //finalize unstake

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "rswEXIT");

        uint256 nftId = 5610;

        tx_.targetData[0] = abi.encodeWithSignature("finalizeWithdrawal(uint256)", nftId);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(); //not processed here, obviously
        _submitManagerCall(manageProofs, tx_);
    }
}
