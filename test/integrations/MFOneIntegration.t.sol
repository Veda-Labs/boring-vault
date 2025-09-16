// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MFOneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MFOneDecoderAndSanitizer.sol"; 
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullMFOneDecoderAndSanitizer is MFOneDecoderAndSanitizer, BaseDecoderAndSanitizer{}


contract MFOneIntegrationTest is BaseTestIntegration {

    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 23234480); 
            
        address mfOneDecoder = address(new FullMFOneDecoderAndSanitizer()); 

        _overrideDecoder(mfOneDecoder); 
    }

    function testDeposit() external {
        _setUpMainnet(); 
        
        vm.prank(0x4f75307888fD06B16594cC93ED478625AD65EEea); 
        IRoleGranter(0x0312A9D1Ff2372DDEdCBB21e4B6389aFc919aC4B).grantRole(0xd2576bd6a4c5558421de15cb8ecdf4eb3282aac06b94d4f004e8cd0d00f3ebd8, address(boringVault)); 
        
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100_000_000_000e6);  

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMfOneLeafs(leafs); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[2]; //depositInstant(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "mfOneDepositVault");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "mfOneDepositVault"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "depositInstant(address,uint256,uint256,bytes32)",
            getAddress(sourceChain, "USDC"),
            1_000_000e18,
            0, 
            bytes32(0)
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        uint256 mfBal = getERC20(sourceChain, "MF-ONE").balanceOf(address(boringVault)); 
        assertGt(mfBal, 0); 
    }

    function testDepositRequest() external {
        _setUpMainnet(); 
        
        vm.prank(0x4f75307888fD06B16594cC93ED478625AD65EEea); 
        IRoleGranter(0x0312A9D1Ff2372DDEdCBB21e4B6389aFc919aC4B).grantRole(0xd2576bd6a4c5558421de15cb8ecdf4eb3282aac06b94d4f004e8cd0d00f3ebd8, address(boringVault)); 
        
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100_000_000_000e6);  

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMfOneLeafs(leafs); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[3]; //depositRequest(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "mfOneDepositVault");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "mfOneDepositVault"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "depositRequest(address,uint256,bytes32)",
            getAddress(sourceChain, "USDC"),
            1_000_000e18,
            bytes32(0)
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //uint256 mfBal = getERC20(sourceChain, "MF-ONE").balanceOf(address(boringVault)); 
        //assertGt(mfBal, 0); 
    }

    function testReedemInstant() external {
        _setUpMainnet(); 
        
        vm.prank(0x4f75307888fD06B16594cC93ED478625AD65EEea); 
        IRoleGranter(0x0312A9D1Ff2372DDEdCBB21e4B6389aFc919aC4B).grantRole(0xd2576bd6a4c5558421de15cb8ecdf4eb3282aac06b94d4f004e8cd0d00f3ebd8, address(boringVault)); 
        
        deal(getAddress(sourceChain, "MF-ONE"), address(boringVault), 100_000_000e18);  

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMfOneLeafs(leafs); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[1]; //approve MF-ONE
        tx_.manageLeafs[1] = leafs[4]; //redeemInstant(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "MF-ONE"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "mfOneRedemptionVault");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "mfOneRedemptionVault"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "redeemInstant(address,uint256,uint256)",
            getAddress(sourceChain, "USDC"),
            1_000_000e18,
            0
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        uint256 usdcBal = getERC20(sourceChain, "USDC").balanceOf(address(boringVault)); 
        assertGt(usdcBal, 0); 
    }

    function testReedemRequest() external {
        _setUpMainnet(); 
        
        vm.prank(0x4f75307888fD06B16594cC93ED478625AD65EEea); 
        IRoleGranter(0x0312A9D1Ff2372DDEdCBB21e4B6389aFc919aC4B).grantRole(0xd2576bd6a4c5558421de15cb8ecdf4eb3282aac06b94d4f004e8cd0d00f3ebd8, address(boringVault)); 
        
        deal(getAddress(sourceChain, "MF-ONE"), address(boringVault), 100_000_000e18);  

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMfOneLeafs(leafs); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[1]; //approve MF-ONE
        tx_.manageLeafs[1] = leafs[5]; //redeemInstant(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "MF-ONE"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "mfOneRedemptionVault");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "mfOneRedemptionVault"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "redeemRequest(address,uint256)",
            getAddress(sourceChain, "USDC"),
            1_000_000e18
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //uint256 mfBal = getERC20(sourceChain, "MF-ONE").balanceOf(address(boringVault)); 
        //assertGt(mfBal, 0); 
    }

    function testReedemRequestFiat() external {
        _setUpMainnet(); 
        
        vm.prank(0x4f75307888fD06B16594cC93ED478625AD65EEea); 
        IRoleGranter(0x0312A9D1Ff2372DDEdCBB21e4B6389aFc919aC4B).grantRole(0xd2576bd6a4c5558421de15cb8ecdf4eb3282aac06b94d4f004e8cd0d00f3ebd8, address(boringVault)); 
        
        deal(getAddress(sourceChain, "MF-ONE"), address(boringVault), 100_000_000e18);  

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addMfOneLeafs(leafs); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[1]; //approve MF-ONE
        tx_.manageLeafs[1] = leafs[6]; //redeemRequestFiat(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "MF-ONE"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "mfOneRedemptionVault");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "mfOneRedemptionVault"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "redeemFiatRequest(uint256)",
            1_000_000e18
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //uint256 mfBal = getERC20(sourceChain, "MF-ONE").balanceOf(address(boringVault)); 
        //assertGt(mfBal, 0); 
    }

}

interface IRoleGranter {
    function grantRole(bytes32 role, address account) external; 
}
