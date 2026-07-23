// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
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
        // 3: approve STETH -> depositAdapter
        // 4: depositStETHForWeETHWithPermit
        // 5: approve WSTETH -> depositAdapter
        // 6: depositWstETHForWeETHWithPermit
        leafs = new ManageLeaf[](8);
        _addEtherFiDepositAdapterLeafs(leafs);

        manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
    }

    function _dummyPermit() internal view returns (DecoderCustomTypes.PermitInput memory permit) {
        // A BoringVault cannot ECDSA-sign a permit. The adapter swallows the failed
        // permit unless the deadline has passed, then pulls on the standing allowance.
        permit.deadline = block.timestamp + 1;
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

    function testStethDeposit() external {
        _setUpMainnet();

        //std storage cannot set steth for some reason
        address stethWhale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;
        vm.prank(stethWhale);
        getERC20(sourceChain, "STETH").transfer(address(boringVault), 10e18);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setupLeafs();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[3]; //approve STETH
        tx_.manageLeafs[1] = leafs[4]; //depositStETHForWeETHWithPermit

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "STETH");
        tx_.targets[1] = getAddress(sourceChain, "depositAdapter");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "depositAdapter"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "depositStETHForWeETHWithPermit(uint256,uint256,address,(uint256,uint256,uint8,bytes32,bytes32))",
            5e18,
            0,
            address(0),
            _dummyPermit()
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 weETHBalanceBefore = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault));

        _submitManagerCall(manageProofs, tx_);

        uint256 weETHBalanceAfter = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault));
        assertGt(weETHBalanceAfter, weETHBalanceBefore);
    }

    function testWstethDeposit() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 10e18);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setupLeafs();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[5]; //approve WSTETH
        tx_.manageLeafs[1] = leafs[6]; //depositWstETHForWeETHWithPermit

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WSTETH");
        tx_.targets[1] = getAddress(sourceChain, "depositAdapter");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "depositAdapter"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "depositWstETHForWeETHWithPermit(uint256,uint256,address,(uint256,uint256,uint8,bytes32,bytes32))",
            5e18,
            0,
            address(0),
            _dummyPermit()
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 weETHBalanceBefore = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault));

        _submitManagerCall(manageProofs, tx_);

        uint256 weETHBalanceAfter = getERC20(sourceChain, "WEETH").balanceOf(address(boringVault));
        assertGt(weETHBalanceAfter, weETHBalanceBefore);
    }
}
