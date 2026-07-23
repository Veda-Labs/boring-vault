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

interface IEtherFiRedemptionManager {
    function setLowWatermarkInBpsOfTvl(uint16 _lowWatermarkInBpsOfTvl, address token) external;
    function setCapacity(uint256 capacity, address token) external;
    function setRefillRatePerSecond(uint256 refillRate, address token) external;
}

interface IEtherFiLiquidityPool {
    function deposit() external payable returns (uint256);
}

contract EtherFiRedemptionManagerIntegration is BaseTestIntegration {
    address internal constant OPERATING_TIMELOCK = 0xcD425f44758a08BaAB3C4908f3e3dE5776e45d7a;

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 25596500);

        address etherFiDecoder = address(new FullEtherFiDecoderAndSanitizer());

        _overrideDecoder(etherFiDecoder);

        // On mainnet the low watermark and bucket rate limit block small test
        // redemptions; lift them as the operating timelock for both output tokens.
        IEtherFiRedemptionManager redemptionManager =
            IEtherFiRedemptionManager(getAddress(sourceChain, "etherFiRedemptionManager"));
        address[2] memory outputTokens = [getAddress(sourceChain, "ETH"), getAddress(sourceChain, "STETH")];
        vm.startPrank(OPERATING_TIMELOCK);
        for (uint256 i; i < 2; i++) {
            redemptionManager.setLowWatermarkInBpsOfTvl(0, outputTokens[i]);
            redemptionManager.setCapacity(1_000e18, outputTokens[i]);
            redemptionManager.setRefillRatePerSecond(1_000e18, outputTokens[i]);
        }
        vm.stopPrank();
        vm.warp(block.timestamp + 1); //refill the bucket
    }

    function _setupLeafs() internal returns (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) {
        // 0: approve EETH -> etherFiRedemptionManager
        // 1: approve WEETH -> etherFiRedemptionManager
        // 2: redeemEEth (ETH out)    4: redeemEEth (stETH out)
        // 3: redeemWeEth (ETH out)   5: redeemWeEth (stETH out)
        leafs = new ManageLeaf[](8);
        _addEtherFiRedemptionManagerLeafs(leafs);

        manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
    }

    function _fundVaultWithEEth(uint256 amount) internal {
        // eETH is rebasing so deal does not work; stake ETH as an EOA and transfer
        address staker = vm.addr(0xE7EF);
        vm.deal(staker, amount + 1e18);
        vm.startPrank(staker);
        IEtherFiLiquidityPool(getAddress(sourceChain, "EETH_LIQUIDITY_POOL")).deposit{value: amount + 1e18}();
        getERC20(sourceChain, "EETH").transfer(address(boringVault), amount);
        vm.stopPrank();
    }

    function testRedeemEEthForEth() external {
        _setUpMainnet();
        _fundVaultWithEEth(10e18);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setupLeafs();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve EETH
        tx_.manageLeafs[1] = leafs[2]; //redeemEEth for ETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "EETH");
        tx_.targets[1] = getAddress(sourceChain, "etherFiRedemptionManager");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "etherFiRedemptionManager"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "redeemEEth(uint256,address,address)", 5e18, address(boringVault), getAddress(sourceChain, "ETH")
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 ethBalanceBefore = address(boringVault).balance;

        _submitManagerCall(manageProofs, tx_);

        uint256 ethDelta = address(boringVault).balance - ethBalanceBefore;
        assertGt(ethDelta, 0);
        //receiver gets the redeemed amount minus the exit fee (a few bps)
        assertApproxEqRel(ethDelta, 5e18, 0.01e18);
    }

    function testRedeemWeEthForEth() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 10e18);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setupLeafs();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[1]; //approve WEETH
        tx_.manageLeafs[1] = leafs[3]; //redeemWeEth for ETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WEETH");
        tx_.targets[1] = getAddress(sourceChain, "etherFiRedemptionManager");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "etherFiRedemptionManager"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "redeemWeEth(uint256,address,address)", 5e18, address(boringVault), getAddress(sourceChain, "ETH")
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 ethBalanceBefore = address(boringVault).balance;

        _submitManagerCall(manageProofs, tx_);

        assertGt(address(boringVault).balance, ethBalanceBefore);
    }

    function testRedeemEEthForSteth() external {
        _setUpMainnet();
        _fundVaultWithEEth(10e18);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setupLeafs();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve EETH
        tx_.manageLeafs[1] = leafs[4]; //redeemEEth for stETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "EETH");
        tx_.targets[1] = getAddress(sourceChain, "etherFiRedemptionManager");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "etherFiRedemptionManager"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "redeemEEth(uint256,address,address)", 5e18, address(boringVault), getAddress(sourceChain, "STETH")
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 stethBalanceBefore = getERC20(sourceChain, "STETH").balanceOf(address(boringVault));

        _submitManagerCall(manageProofs, tx_);

        uint256 stethBalanceAfter = getERC20(sourceChain, "STETH").balanceOf(address(boringVault));
        assertGt(stethBalanceAfter, stethBalanceBefore);
    }

    function testRedeemWeEthForSteth() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 10e18);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setupLeafs();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[1]; //approve WEETH
        tx_.manageLeafs[1] = leafs[5]; //redeemWeEth for stETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WEETH");
        tx_.targets[1] = getAddress(sourceChain, "etherFiRedemptionManager");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "etherFiRedemptionManager"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "redeemWeEth(uint256,address,address)", 5e18, address(boringVault), getAddress(sourceChain, "STETH")
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 stethBalanceBefore = getERC20(sourceChain, "STETH").balanceOf(address(boringVault));

        _submitManagerCall(manageProofs, tx_);

        uint256 stethBalanceAfter = getERC20(sourceChain, "STETH").balanceOf(address(boringVault));
        assertGt(stethBalanceAfter, stethBalanceBefore);
    }
}
