// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullOneInchV6Decoder is
    OneInchDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{

}

contract OneInchV6IntegrationTest is BaseTestIntegration {

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 24521559);

        address oneInchV6Decoder = address(new FullOneInchV6Decoder());

        _overrideDecoder(oneInchV6Decoder);

        // Override executor to match real API routing data
        setAddress(true, sourceChain, "oneInchExecutor", 0x0BB7a4Fdea32910038DEc59c20ccAe3a6E66b09f);
    }

    function testV6ApproveAndSwap() external {
        _setUpMainnet();

        // Deal USDT to boringVault (381_040_412 = 0x16b2f71c, ~381 USDT with 6 decimals)
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 381_040_412);

        address[] memory assets = new address[](2);
        SwapKind[] memory kind = new SwapKind[](2);
        assets[0] = getAddress(sourceChain, "USDT");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDC");
        kind[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6GeneralSwapping(leafs, assets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve USDT
        tx_.manageLeafs[1] = leafs[1]; // swap USDT -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDT");
        tx_.targets[1] = getAddress(sourceChain, "aggregationRouterV6");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aggregationRouterV6"), type(uint256).max
        );

        tx_.targetData[1] = hex"07ed23790000000000000000000000000bb7a4fdea32910038dec59c20ccae3a6e66b09f000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000bb7a4fdea32910038dec59c20ccae3a6e66b09f0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f0000000000000000000000000000000000000000000000000000000016b2f71c0000000000000000000000000000000000000000000000000000000016b38e3d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000542efbb34376081172010d429a6b9270d2ee3f69f6f8116454b30dd7ab0585090634166cbbd57de7a921ee305f015f9a7b2655d69c8bf9bbcbd4dfb4e1aaa0ff9520000000000000000000000000000000000000000000000000004e400001a0020d6bdbf78dac17f958d2ee523a2206206994597c13d831ec700a0c9e75c4800000000000000000000000000000000e100190000000000000000000000000000000000000000000000000000049200034200a007e5c0d200000000000000000000000000000000000000000000031e0000ae00005702a000000000000000000000000000000000000000000000000000480896cb71c0ea48c95033000000000000000000000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70001f400000a000002a00000000000000000000000000000000000000000000000000000010022a15bf648c95033010000000000000000000000000000000000000000d1d2eb1b1e90b638588728b4130137d262c87cae000bb800003c00005120111111125421ca6dc452d289314280a0f8842a65d1d2eb1b1e90b638588728b4130137d262c87cae012456a758680000000000000000000000000000000000000000f22bfe007b81ce043d2ded35000000000000000000000000fbeedcfe378866dab6abbafd8b2986f5c17687370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000d1d2eb1b1e90b638588728b4130137d262c87cae00000000000000000000000000000000000000000000000000000000024b176600000000000000000000000000000000000000000000000000000102b8f5bc92100000000000000000000000000003b32700699ca4eac59c20ccae3a6e66b09f000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000410e2f52552811d624642f7b746f2221498ef15a0e34f59f3a20504ddb935e3e611365121f4c8fbf01589913f2c12e114b502d886c05295516d97bceabcc877dc81b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014111111125421ca6dc452d289314280a0f8842a6500000000000000000000000051309995855c00494d039ab6792f18e368e530dff931dac17f958d2ee523a2206206994597c13d831ec70084f196187f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000053e2d6238da300000032000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff9a5889f795069a41a8a300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014394b1c000000000000000000000000111111125421ca6dc452d289314280a0f8842a65000000000000000000000000000000000000000000000000000000000000";

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        assertGt(ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault)), 0);
    }

    function testV6WrongAddressReverts() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);

        console.log(address(boringVault));

        address[] memory assets = new address[](2);
        SwapKind[] memory kind = new SwapKind[](2);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6GeneralSwapping(leafs, assets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Try swap with wrong dstReceiver — should fail Merkle verification
        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[1]; //swap WETH -> WEETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "aggregationRouterV6");

        DecoderCustomTypes.SwapDescription memory desc = DecoderCustomTypes.SwapDescription({
            srcToken: getAddress(sourceChain, "WETH"),
            dstToken: getAddress(sourceChain, "WEETH"),
            srcReceiver: payable(getAddress(sourceChain, "oneInchExecutor")),
            dstReceiver: payable(address(0xdead)), // wrong receiver — not boringVault
            amount: 1_000e18,
            minReturnAmount: 900e18,
            flags: 4
        });

        tx_.targetData[0] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes)",
            getAddress(sourceChain, "oneInchExecutor"),
            desc,
            ""
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Should revert because dstReceiver doesn't match the Merkle leaf
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }
}
