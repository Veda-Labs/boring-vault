// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {NestDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NestDecoderAndSanitizer.sol";
import {CamelotNonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullNestDecoder is NestDecoderAndSanitizer, BaseDecoderAndSanitizer {
    constructor(address _nestNonFungiblePositionManager) NestDecoderAndSanitizer(_nestNonFungiblePositionManager) {}
}

contract NestIntegrationTest is BaseTestIntegration {
    uint256 internal constant EXPECTED_TOKEN_ID = 66196;
    uint128 internal constant EXPECTED_LIQUIDITY = 58332013696143001337378;

    error InvalidSignature();

    function _setUpNest() internal {
        super.setUp();
        _setupChain("hyperEVM", 40631047);

        address nestDecoder = address(new FullNestDecoder(getAddress(sourceChain, "nestNonFungiblePositionManager")));

        _overrideDecoder(nestDecoder);
    }

    function testNestLpFlow() external {
        _setUpNest();

        deal(getAddress(sourceChain, "WHYPE"), address(boringVault), 100e18);
        deal(getAddress(sourceChain, "KHYPE"), address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WHYPE");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "KHYPE");
        _addNestLeafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(7);

        tx_.manageLeafs[0] = leafs[0]; // approve WHYPE
        tx_.manageLeafs[1] = leafs[1]; // approve KHYPE
        tx_.manageLeafs[2] = leafs[2]; // mint
        tx_.manageLeafs[3] = leafs[3]; // increaseLiquidity
        tx_.manageLeafs[4] = leafs[4]; // decreaseLiquidity
        tx_.manageLeafs[5] = leafs[5]; // collect
        tx_.manageLeafs[6] = leafs[6]; // burn

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WHYPE");
        tx_.targets[1] = getAddress(sourceChain, "KHYPE");
        tx_.targets[2] = getAddress(sourceChain, "nestNonFungiblePositionManager");
        tx_.targets[3] = getAddress(sourceChain, "nestNonFungiblePositionManager");
        tx_.targets[4] = getAddress(sourceChain, "nestNonFungiblePositionManager");
        tx_.targets[5] = getAddress(sourceChain, "nestNonFungiblePositionManager");
        tx_.targets[6] = getAddress(sourceChain, "nestNonFungiblePositionManager");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "nestNonFungiblePositionManager"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "nestNonFungiblePositionManager"), type(uint256).max
        );

        DecoderCustomTypes.CamelotMintParams memory mintParams = DecoderCustomTypes.CamelotMintParams({
            token0: getAddress(sourceChain, "WHYPE"),
            token1: getAddress(sourceChain, "KHYPE"),
            tickLower: int24(-213),
            tickUpper: int24(-211),
            amount0Desired: 0.4e18,
            amount1Desired: 2.5e18,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(boringVault),
            deadline: block.timestamp
        });
        tx_.targetData[2] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams
        );

        DecoderCustomTypes.IncreaseLiquidityParams memory increaseParams =
            DecoderCustomTypes.IncreaseLiquidityParams(EXPECTED_TOKEN_ID, 0.4e18, 2.5e18, 0, 0, block.timestamp);
        tx_.targetData[3] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseParams
        );

        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseParams =
            DecoderCustomTypes.DecreaseLiquidityParams(EXPECTED_TOKEN_ID, EXPECTED_LIQUIDITY, 0, 0, block.timestamp);
        tx_.targetData[4] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseParams
        );

        DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
            EXPECTED_TOKEN_ID, address(boringVault), type(uint128).max, type(uint128).max
        );
        tx_.targetData[5] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);

        tx_.targetData[6] = abi.encodeWithSignature("burn(uint256)", EXPECTED_TOKEN_ID);

        for (uint256 i; i < 7; ++i) {
            tx_.decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        _submitManagerCall(manageProofs, tx_);

        assertEq(
            CamelotNonFungiblePositionManager(getAddress(sourceChain, "nestNonFungiblePositionManager")).balanceOf(
                address(boringVault)
            ),
            0
        );
        assertApproxEqAbs(getERC20(sourceChain, "WHYPE").balanceOf(address(boringVault)), 100e18, 1e14);
        assertApproxEqAbs(getERC20(sourceChain, "KHYPE").balanceOf(address(boringVault)), 100e18, 1e14);
    }

    function testNestClaim() external {
        _setUpNest();

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WHYPE");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "KHYPE");
        _addNestLeafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);
        tx_.manageLeafs[0] = leafs[7]; // claim

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "nestGaugeRewarder");

        // Real GaugeRewarder claim signature pulled from on-chain tx 0x3186ff46...; it is bound to
        // the EOA that claimed, so calling as the vault reaches the rewarder's signature check and
        // reverts InvalidSignature. Any earlier revert would indicate a decoder/merkle failure.
        uint256 totalAmount = 110157207968164147;
        uint256 deadline = 1784225656;
        bytes memory signature =
            hex"539388990e0054b7fd3ebfe8b7585fb272fab9d17710624d968eaef55bdfe7014ccfc5bf4fef8db81948bd39a2654fe47cb2e63fea11d36f41c22e32d54c3ae91b";
        tx_.targetData[0] = abi.encodeWithSignature("claim(uint256,uint256,bytes)", totalAmount, deadline, signature);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(InvalidSignature.selector);
        _submitManagerCall(manageProofs, tx_);
    }
}
