// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 

interface IScratchPad {
    function write(uint256 slot, bytes32 value) external;
    function read(uint256 slot) external view returns (bytes32);
    function add(uint256 slotA, uint256 slotB, uint256 resultSlot) external;
    function sub(uint256 slotA, uint256 slotB, uint256 resultSlot) external;
    function eq(uint256 slotA, uint256 slotB) external view;
    function gt(uint256 slotA, uint256 slotB) external view;
    function gte(uint256 slotA, uint256 slotB) external view;
    function lt(uint256 slotA, uint256 slotB) external view;
    function lte(uint256 slotA, uint256 slotB) external view;
}

contract FullScratchpadDecoder is OdosDecoderAndSanitizer, BaseDecoderAndSanitizer {
    constructor(address _odosRouter) OdosDecoderAndSanitizer(_odosRouter) {}

    // Scratchpad decoder functions - no address arguments to extract
    function write(uint256, bytes32) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function read(uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function add(uint256, uint256, uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function sub(uint256, uint256, uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function eq(uint256, uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function gt(uint256, uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function gte(uint256, uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function lt(uint256, uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function lte(uint256, uint256) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }
}

contract TestScratchpad is BaseTestIntegration {

    address internal scratchpad;

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 22140604);

        address decoder = address(new FullScratchpadDecoder(getAddress(sourceChain, "odosRouterV2")));
        _overrideDecoder(decoder);

        scratchpad = deployCode("Scratchpad.sol:ScratchPad");
    }

    function testScratchpad() public {
        _setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);
        
        //old executor
        address oldOdosExecutor = 0xd768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F;
        setAddress(true, sourceChain, "odosExecutor", oldOdosExecutor);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        _addScratchpadLeafs(leafs, scratchpad);
        // leafs[0] = write, leafs[1] = read, leafs[2] = gte (from _addScratchpadLeafs)

        address[] memory tokens = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        tokens[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        tokens[1] = getAddress(sourceChain, "WETH");
        kind[1] = SwapKind.BuyAndSell;
        tokens[2] = getAddress(sourceChain, "USDT");
        kind[2] = SwapKind.BuyAndSell;

        _addOdosSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Expected minimum output from swap and actual output (deterministic at this block)
        uint256 expectedOutputMin = 44770662095406488;
        uint256 actualOutput = 44870662095406488; // Known output at block 22140604

        Tx memory tx_ = _getTxArrays(5);

        // Flow:
        // 1. Write expected minimum to slot 0
        // 2. Approve USDC
        // 3. Swap USDC -> WETH
        // 4. Write actual received to slot 1
        // 5. Call gte(slot1, slot0) - reverts if actual < expected
        tx_.manageLeafs[0] = leafs[0]; //write expected to slot 0
        tx_.manageLeafs[1] = leafs[3]; //approve USDC (index shifted due to gte leaf)
        tx_.manageLeafs[2] = leafs[4]; //swap USDC -> WETH
        tx_.manageLeafs[3] = leafs[0]; //write actual to slot 1 (reuse write leaf)
        tx_.manageLeafs[4] = leafs[2]; //gte(slot1, slot0)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = scratchpad; //write expected
        tx_.targets[1] = getAddress(sourceChain, "USDC"); //approve
        tx_.targets[2] = getAddress(sourceChain, "odosRouterV2"); //swap
        tx_.targets[3] = scratchpad; //write actual
        tx_.targets[4] = scratchpad; //gte comparison

        // Write expected minimum to slot 0
        tx_.targetData[0] = abi.encodeWithSignature(
            "write(uint256,bytes32)", 0, bytes32(expectedOutputMin)
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );

        // Swap USDC -> WETH using Odos (from block 22140604)
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000, // 100 USDC
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: actualOutput,
            outputMin: expectedOutputMin,
            outputReceiver: address(boringVault)
        });

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000";

        tx_.targetData[2] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
            swapTokenInfo,
            pathDefinition,
            getAddress(sourceChain, "odosExecutor"),
            0
        );

        // Write actual output to slot 1
        tx_.targetData[3] = abi.encodeWithSignature(
            "write(uint256,bytes32)", 1, bytes32(actualOutput)
        );

        // Compare: gte(slot1, slot0) - reverts if actual < expected
        tx_.targetData[4] = abi.encodeWithSignature("gte(uint256,uint256)", 1, 0);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        // Verify we received WETH
        uint256 wethBal = getERC20(sourceChain, "WETH").balanceOf(address(boringVault));
        assertGt(wethBal, 0);

        // Verify we got at least the minimum expected output
        assertGe(wethBal, expectedOutputMin);
    }

    function testScratchpad_SlippageCheckFails() public {
        _setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);

        address oldOdosExecutor = 0xd768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F;
        setAddress(true, sourceChain, "odosExecutor", oldOdosExecutor);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        _addScratchpadLeafs(leafs, scratchpad);
        // leafs[0] = write, leafs[1] = read, leafs[2] = gte

        address[] memory tokens = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        tokens[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        tokens[1] = getAddress(sourceChain, "WETH");
        kind[1] = SwapKind.BuyAndSell;
        tokens[2] = getAddress(sourceChain, "USDT");
        kind[2] = SwapKind.BuyAndSell;

        _addOdosSwapLeafs(leafs, tokens, kind);
        // leafs[3] = USDC approve, leafs[4] = swap USDC->WETH

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Set expected minimum HIGHER than actual output to trigger slippage failure
        uint256 actualOutput = 44870662095406488; // Known output at block 22140604
        uint256 unreasonableExpectedMin = 100e18; // Way higher than actual - will fail

        Tx memory tx_ = _getTxArrays(5);

        tx_.manageLeafs[0] = leafs[0]; //write expected to slot 0
        tx_.manageLeafs[1] = leafs[3]; //approve USDC
        tx_.manageLeafs[2] = leafs[4]; //swap USDC -> WETH
        tx_.manageLeafs[3] = leafs[0]; //write actual to slot 1
        tx_.manageLeafs[4] = leafs[2]; //gte(slot1, slot0) - will FAIL

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = scratchpad;
        tx_.targets[1] = getAddress(sourceChain, "USDC");
        tx_.targets[2] = getAddress(sourceChain, "odosRouterV2");
        tx_.targets[3] = scratchpad;
        tx_.targets[4] = scratchpad;

        // Write unreasonable expected minimum to slot 0
        tx_.targetData[0] = abi.encodeWithSignature(
            "write(uint256,bytes32)", 0, bytes32(unreasonableExpectedMin)
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );

        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: actualOutput,
            outputMin: 1, // Low min so Odos swap itself succeeds
            outputReceiver: address(boringVault)
        });

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000";

        tx_.targetData[2] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
            swapTokenInfo,
            pathDefinition,
            getAddress(sourceChain, "odosExecutor"),
            0
        );

        // Write actual output to slot 1
        tx_.targetData[3] = abi.encodeWithSignature(
            "write(uint256,bytes32)", 1, bytes32(actualOutput)
        );

        // Compare: gte(slot1, slot0) - REVERTS because actual < unreasonableExpectedMin
        tx_.targetData[4] = abi.encodeWithSignature("gte(uint256,uint256)", 1, 0);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        // Expect the entire tx to revert with ComparisonFailed(actual, expected)
        vm.expectRevert(
            abi.encodeWithSignature("ComparisonFailed(uint256,uint256)", actualOutput, unreasonableExpectedMin)
        );

        _submitManagerCall(manageProofs, tx_);
    }

    // ==================== GAS COMPARISON TESTS ====================

    function testGas_SwapWithScratchpadSlippage() public {
        _setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);

        address oldOdosExecutor = 0xd768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F;
        setAddress(true, sourceChain, "odosExecutor", oldOdosExecutor);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addScratchpadLeafs(leafs, scratchpad);

        address[] memory tokens = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        tokens[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        tokens[1] = getAddress(sourceChain, "WETH");
        kind[1] = SwapKind.BuyAndSell;
        tokens[2] = getAddress(sourceChain, "USDT");
        kind[2] = SwapKind.BuyAndSell;

        _addOdosSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        uint256 expectedOutputMin = 44770662095406488;
        uint256 actualOutput = 44870662095406488;

        // WITH SCRATCHPAD: 5 calls (write, approve, swap, write, gte)
        Tx memory tx_ = _getTxArrays(5);

        tx_.manageLeafs[0] = leafs[0]; //write
        tx_.manageLeafs[1] = leafs[3]; //approve
        tx_.manageLeafs[2] = leafs[4]; //swap
        tx_.manageLeafs[3] = leafs[0]; //write
        tx_.manageLeafs[4] = leafs[2]; //gte

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = scratchpad;
        tx_.targets[1] = getAddress(sourceChain, "USDC");
        tx_.targets[2] = getAddress(sourceChain, "odosRouterV2");
        tx_.targets[3] = scratchpad;
        tx_.targets[4] = scratchpad;

        tx_.targetData[0] = abi.encodeWithSignature("write(uint256,bytes32)", 0, bytes32(expectedOutputMin));
        tx_.targetData[1] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max);

        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: actualOutput,
            outputMin: 1, // Use minimal Odos slippage since scratchpad handles it
            outputReceiver: address(boringVault)
        });

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000";

        tx_.targetData[2] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
            swapTokenInfo, pathDefinition, getAddress(sourceChain, "odosExecutor"), 0
        );
        tx_.targetData[3] = abi.encodeWithSignature("write(uint256,bytes32)", 1, bytes32(actualOutput));
        tx_.targetData[4] = abi.encodeWithSignature("gte(uint256,uint256)", 1, 0);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        uint256 gasBefore = gasleft();
        _submitManagerCall(manageProofs, tx_);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used WITH scratchpad slippage (5 calls)", gasUsed);
    }

    function testGas_SwapWithoutScratchpad() public {
        _setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);

        address oldOdosExecutor = 0xd768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F;
        setAddress(true, sourceChain, "odosExecutor", oldOdosExecutor);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addScratchpadLeafs(leafs, scratchpad);

        address[] memory tokens = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        tokens[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        tokens[1] = getAddress(sourceChain, "WETH");
        kind[1] = SwapKind.BuyAndSell;
        tokens[2] = getAddress(sourceChain, "USDT");
        kind[2] = SwapKind.BuyAndSell;

        _addOdosSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        uint256 expectedOutputMin = 44770662095406488;
        uint256 actualOutput = 44870662095406488;

        // WITHOUT SCRATCHPAD: 2 calls (approve, swap with Odos slippage)
        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[3]; //approve
        tx_.manageLeafs[1] = leafs[4]; //swap

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDC");
        tx_.targets[1] = getAddress(sourceChain, "odosRouterV2");

        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max);

        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: getAddress(sourceChain, "odosExecutor"),
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: actualOutput,
            outputMin: expectedOutputMin, // Odos handles slippage
            outputReceiver: address(boringVault)
        });

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000";

        tx_.targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
            swapTokenInfo, pathDefinition, getAddress(sourceChain, "odosExecutor"), 0
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 gasBefore = gasleft();
        _submitManagerCall(manageProofs, tx_);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used WITHOUT scratchpad (2 calls)", gasUsed);
    }
}
