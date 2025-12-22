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

contract EtherFiStethDepositIntegration is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 23225880);

        address etherFiDecoder = address(new FullEtherFiDecoderAndSanitizer());

        _overrideDecoder(etherFiDecoder);
    }

    function testStethDeposit() external {
        _setUpMainnet();

        //std storage cannot set steth for some reason
        //deal(getAddress(sourceChain, "STETH"), address(boringVault), 100e18);

        address stethWhale = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;
        vm.prank(stethWhale);
        getERC20(sourceChain, "STETH").transfer(address(boringVault), 10e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addEtherFiLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[7]; //approve STETH
        tx_.manageLeafs[1] = leafs[8]; //depositWithERC20(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "STETH"); //approve
        tx_.targets[1] = getAddress(sourceChain, "etherFiVampirePool");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "etherFiVampirePool"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "depositWithERC20(address,uint256,address)", getAddress(sourceChain, "STETH"), 10e18, address(0)
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 eETHBalanceBefore = getERC20(sourceChain, "EETH").balanceOf(address(boringVault));

        _submitManagerCall(manageProofs, tx_);

        uint256 eETHBalanceAfter = getERC20(sourceChain, "EETH").balanceOf(address(boringVault));
        assertGt(eETHBalanceAfter, eETHBalanceBefore);
    }
}
