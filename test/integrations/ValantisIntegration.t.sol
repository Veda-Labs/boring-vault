// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { BaseTestIntegration } from "test/integrations/BaseTestIntegration.t.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import { ValantisDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/ValantisDecoderAndSanitizer.sol";
import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

contract FullValantisDecoderAndSanitizer is BaseDecoderAndSanitizer, ValantisDecoderAndSanitizer { }

contract ValantisIntegration is BaseTestIntegration {
    function _setUpHyperEVM() internal {
        super.setUp();
        _setupChain("hyperEVM", 9_637_765);

        address valantisDecoder = address(new FullValantisDecoderAndSanitizer());

        _overrideDecoder(valantisDecoder);
    }

    function testHyperEVM() external {
        _setUpHyperEVM();

        //starting with just the base assets
        deal(getAddress(sourceChain, "KHYPE"), address(boringVault), 100e18);
        //deal(getAddress(sourceChain, "WHYPE"), address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // ==== kHYPE ====
        _addValantisLSTLeafs(leafs, getAddress(sourceChain, "KHYPE_WHYPE_sovereign_pool"), false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(4);

        tx_.manageLeafs[0] = leafs[0]; //approve token0
        tx_.manageLeafs[1] = leafs[1]; //approve token1
        tx_.manageLeafs[2] = leafs[2]; //swap 0 -> 1
        tx_.manageLeafs[3] = leafs[3]; //swap 1 -> 0

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "KHYPE"); //approve
        tx_.targets[1] = getAddress(sourceChain, "WHYPE"); //approve
        tx_.targets[2] = getAddress(sourceChain, "KHYPE_WHYPE_sovereign_pool"); //swap 0 -> 1
        tx_.targets[3] = getAddress(sourceChain, "KHYPE_WHYPE_sovereign_pool"); //swap 1 -> 0

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "KHYPE_WHYPE_sovereign_pool"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "KHYPE_WHYPE_sovereign_pool"), type(uint256).max
        );

        DecoderCustomTypes.SovereignPoolSwapContextData memory contextData =
            DecoderCustomTypes.SovereignPoolSwapContextData("", "", "", "");

        DecoderCustomTypes.SovereignPoolSwapParams memory swapParams = DecoderCustomTypes.SovereignPoolSwapParams(
            false, true, 1e18, 0, block.timestamp, address(boringVault), getAddress(sourceChain, "WHYPE"), contextData
        );

        tx_.targetData[2] = abi.encodeWithSignature(
            "swap((bool,bool,uint256,uint256,uint256,address,address,(bytes,bytes,bytes,bytes)))", swapParams
        );

        DecoderCustomTypes.SovereignPoolSwapParams memory swapParams2 = DecoderCustomTypes.SovereignPoolSwapParams(
            false, false, 1e18, 0, block.timestamp, address(boringVault), getAddress(sourceChain, "KHYPE"), contextData
        );

        tx_.targetData[3] = abi.encodeWithSignature(
            "swap((bool,bool,uint256,uint256,uint256,address,address,(bytes,bytes,bytes,bytes)))", swapParams2
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        uint256 whypeBalance = getERC20(sourceChain, "WHYPE").balanceOf(address(boringVault));
        console.log("whypeBalance: ", whypeBalance);
        assertGt(whypeBalance, 0);
    }
}
