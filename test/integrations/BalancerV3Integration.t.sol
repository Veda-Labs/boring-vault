// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullBalancerV3DecoderAndSanitizer is BalancerV3DecoderAndSanitizer {

    //function deposit(uint256, address receiver) external pure override(ERC4626DecoderAndSanitizer, CurveDecoderAndSanitizer) returns (bytes memory addressesFound) {
    //    addressesFound = abi.encodePacked(receiver);
    //}

}

contract BalancerV3IntegrationTest is BaseTestIntegration {
        
    //comes from balancer pool FE 
    address waETHUSDC = 0xD4fa2D31b7968E448877f69A96DE69f5de8cD23E; //where ETH means mainnet not ETH currency
    address waETHUSDT = 0x7Bc3485026Ac48b6cf9BaF0A377477Fff5703Af8; //where ETH means mainnet not ETH currency
    address waETHGHO = 0xC71Ea051a5F82c67ADcF634c36FFE6334793D24C; //where ETH means mainnet not ETH currency

    address waETHWETH = 0x0FE906e030a44eF24CA8c7dC7B7c53A6C4F00ce9;  
    address waETHWSTETH = 0x775F661b0bD1739349b9A2A3EF60be277c5d2D29;  
    address tETH = 0xD11c452fc99cF405034ee446803b6F6c1F6d5ED8; 

    address wsSonicUSDC = 0x7870ddFd5ACA4E977B2287e9A212bcbe8FC4135a; 
    address scUSD = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE; 

    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22067550); 
            
        address balancerV3Decoder = address(new FullBalancerV3DecoderAndSanitizer()); 

        _overrideDecoder(balancerV3Decoder); 
    }

    function _setUpSonic() internal {
        super.setUp(); 
        _setupChain("sonicMainnet", 14684422); 
            
        address balancerV3Decoder = address(new FullBalancerV3DecoderAndSanitizer()); 

        _overrideDecoder(balancerV3Decoder); 
    }

    function testBalancerAddRemoveLiqProportional0() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
        deal(waETHUSDC, address(boringVault), 1_000e18); 
        deal(waETHUSDT, address(boringVault), 1_000e18); 
        deal(waETHGHO, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), boosted, address(0)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(8); 

        tx_.manageLeafs[0] = leafs[21]; //approve permit2 USDC
        tx_.manageLeafs[1] = leafs[22]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[5]; //approve permit2 USDT
        tx_.manageLeafs[3] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[13]; //approve permit2 GHO
        tx_.manageLeafs[5] = leafs[14]; //use permit2 to approve router
        tx_.manageLeafs[6] = leafs[24]; //use permit2 to approve router

        tx_.manageLeafs[7] = leafs[25]; //addLiqProportional

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHUSDT; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = waETHGHO; //approve 
        tx_.targets[5] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[6] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"); //approve 
        
        //router calls
        tx_.targets[7] = getAddress(sourceChain, "balancerV3Router"); //addLiqProportional

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDT, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHGHO, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[6] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](3); 
        amounts[0] = 10e18;  
        amounts[1] = 10e18;  
        amounts[2] = 10e18;  

        tx_.targetData[7] = abi.encodeWithSignature(
            "addLiquidityProportional(address,uint256[],uint256,bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), amounts, 1e8, false, "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[29]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  
        amounts[2] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }

    function testPermit2Lockdown() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
        deal(waETHUSDC, address(boringVault), 1_000e18); 
        deal(waETHUSDT, address(boringVault), 1_000e18); 
        deal(waETHGHO, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), boosted, address(0)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 

        tx_.manageLeafs[0] = leafs[21]; //approve permit2 USDC
        tx_.manageLeafs[1] = leafs[22]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[23]; //lockdown

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = getAddress(sourceChain, "permit2"); //permit2 approves router

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        
        DecoderCustomTypes.TokenSpenderPair[] memory approvals = new DecoderCustomTypes.TokenSpenderPair[](1); 
        approvals[0] = DecoderCustomTypes.TokenSpenderPair(
            waETHUSDC,
            getAddress(sourceChain, "balancerV3Router")
        ); 

        tx_.targetData[2] = abi.encodeWithSignature(
            "lockdown((address,address)[])", approvals 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

    }

    function testBalancerGaugeStaking0() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
        deal(waETHUSDC, address(boringVault), 1_000e18); 
        deal(waETHUSDT, address(boringVault), 1_000e18); 
        deal(waETHGHO, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), boosted, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge")); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(10); 


        tx_.manageLeafs[0] = leafs[21]; //approve permit2 USDC
        tx_.manageLeafs[1] = leafs[22]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[5]; //approve permit2 USDT
        tx_.manageLeafs[3] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[13]; //approve permit2 GHO
        tx_.manageLeafs[5] = leafs[14]; //use permit2 to approve router
        tx_.manageLeafs[6] = leafs[24]; //use permit2 to approve router

        tx_.manageLeafs[7] = leafs[25]; //addLiqProportional
        tx_.manageLeafs[8] = leafs[34]; //approve gauge lp
        tx_.manageLeafs[9] = leafs[35]; //deposit gauge lp


        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = waETHUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHUSDT; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = waETHGHO; //approve 
        tx_.targets[5] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[6] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"); //approve 
        
        //router calls
        tx_.targets[7] = getAddress(sourceChain, "balancerV3Router"); //addLiqProportional
        tx_.targets[8] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"); //approve 
        tx_.targets[9] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge"); //deposit

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDT, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHGHO, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[6] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](3); 
        amounts[0] = 10e18;  
        amounts[1] = 10e18;  
        amounts[2] = 10e18;  

        tx_.targetData[7] = abi.encodeWithSignature(
            "addLiquidityProportional(address,uint256[],uint256,bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), amounts, 1e8, false, "" 
        );
        tx_.targetData[8] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge"), type(uint256).max 
        );
        tx_.targetData[9] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1e8, address(boringVault)  
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get gauge staking tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT_gauge").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 
    
        //claim rewards, withdraw lp, then remove liquidity
        tx_ = _getTxArrays(3); 

        tx_.manageLeafs[0] = leafs[37]; 
        tx_.manageLeafs[1] = leafs[36]; 
        tx_.manageLeafs[2] = leafs[29]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge"); 
        tx_.targets[1] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge"); 
        tx_.targets[2] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  
        amounts[2] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "claim_rewards(address)", address(boringVault) 
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "withdraw(uint256)", lpBalance
        ); 
        tx_.targetData[2] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 

        //check we have more GHO now
        uint256 GHORewards = getERC20(sourceChain, "GHO").balanceOf(address(boringVault));  
        assertGt(GHORewards, 0); 
    }

    function testBalancerV3FullBoostedDepositFlow() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT, GHO)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
        deal(getAddress(sourceChain, "GHO"), address(boringVault), 1_000e18); 
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000e6); 

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), boosted, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge")); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(16); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDT 
        tx_.manageLeafs[1] = leafs[1]; //deposit into waETHUSDT

        tx_.manageLeafs[2] = leafs[8]; //approve GHO
        tx_.manageLeafs[3] = leafs[9]; //deposit into waETHGHO

        tx_.manageLeafs[4] = leafs[16]; //approve USDC
        tx_.manageLeafs[5] = leafs[17]; //deposit into waETHUSDC

        tx_.manageLeafs[6] = leafs[21]; //approve permit2 USDC
        tx_.manageLeafs[7] = leafs[22]; //use permit2 to approve router
        tx_.manageLeafs[8] = leafs[5]; //approve permit2 USDT
        tx_.manageLeafs[9] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[10] = leafs[13]; //approve permit2 GHO
        tx_.manageLeafs[11] = leafs[14]; //use permit2 to approve router
        tx_.manageLeafs[12] = leafs[24]; //use permit2 to approve router

        tx_.manageLeafs[13] = leafs[25]; //addLiqProportional
        tx_.manageLeafs[14] = leafs[34]; //approve gauge lp
        tx_.manageLeafs[15] = leafs[35]; //deposit gauge lp


        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
         
        tx_.targets[0] = getAddress(sourceChain, "USDT"); //approve 
        tx_.targets[1] = waETHUSDT; //deposit
        tx_.targets[2] = getAddress(sourceChain, "GHO"); //approve 
        tx_.targets[3] = waETHGHO; //deposit
        tx_.targets[4] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[5] = waETHUSDC; //deposit
        
        tx_.targets[6] = waETHUSDC; //approve 
        tx_.targets[7] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[8] = waETHUSDT; //approve 
        tx_.targets[9] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[10] = waETHGHO; //approve 
        tx_.targets[11] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[12] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"); //approve 
        
        //router calls
        tx_.targets[13] = getAddress(sourceChain, "balancerV3Router"); //addLiqProportional
        tx_.targets[14] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"); //approve 
        tx_.targets[15] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge"); //deposit

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", waETHUSDT, type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1000e6, address(boringVault) 
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", waETHGHO, type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1000e18, address(boringVault) 
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", waETHUSDC, type(uint256).max
        );
        tx_.targetData[5] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1000e6, address(boringVault) 
        );

        tx_.targetData[6] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[7] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[8] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[9] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDT, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[10] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[11] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHGHO, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[12] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](3); 
        amounts[0] = 10e18;  
        amounts[1] = 10e18;  
        amounts[2] = 10e18;  

        tx_.targetData[13] = abi.encodeWithSignature(
            "addLiquidityProportional(address,uint256[],uint256,bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), amounts, 1e8, false, "" 
        );
        tx_.targetData[14] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge"), type(uint256).max 
        );
        tx_.targetData[15] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1e8, address(boringVault)  
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[11] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[12] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[13] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[13] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[14] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[15] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get gauge staking tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT_gauge").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 
    
        //claim rewards, withdraw lp, then remove liquidity, then withdraw into USDT, GHO, USDC
        tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[37]; 
        tx_.manageLeafs[1] = leafs[36]; 
        tx_.manageLeafs[2] = leafs[29]; 

        tx_.manageLeafs[3] = leafs[2]; 
        tx_.manageLeafs[4] = leafs[10]; 
        tx_.manageLeafs[5] = leafs[18]; 


        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge"); 
        tx_.targets[1] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge"); 
        tx_.targets[2] = getAddress(sourceChain, "balancerV3Router"); 

        tx_.targets[3] = waETHUSDT; 
        tx_.targets[4] = waETHGHO; 
        tx_.targets[5] = waETHUSDC; 

        amounts[0] = 0;  
        amounts[1] = 0;  
        amounts[2] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "claim_rewards(address)", address(boringVault) 
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "withdraw(uint256)", lpBalance
        ); 
        tx_.targetData[2] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), lpBalance, amounts, false, "" 
        ); 
        tx_.targetData[3] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)", 1000e6, address(boringVault), address(boringVault)
        ); 
        tx_.targetData[4] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)", 1000e18, address(boringVault), address(boringVault)
        ); 
        tx_.targetData[5] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)", 1000e6, address(boringVault), address(boringVault)
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 

        //check we have more GHO now
        uint256 GHORewards = getERC20(sourceChain, "GHO").balanceOf(address(boringVault));  
        assertGt(GHORewards, 1000e18); //check that we have more than initial
    }

    function testBalancerAddRemoveLiqSingleTokenExactOut() external {
        _setUpMainnet();
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
        deal(waETHUSDC, address(boringVault), 1_000e18); 
        deal(waETHUSDT, address(boringVault), 1_000e18); 
        deal(waETHGHO, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), boosted, address(0)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(8); 

        tx_.manageLeafs[0] = leafs[21]; //approve permit2 USDC
        tx_.manageLeafs[1] = leafs[22]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[5]; //approve permit2 USDT
        tx_.manageLeafs[3] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[13]; //approve permit2 GHO
        tx_.manageLeafs[5] = leafs[14]; //use permit2 to approve router
        tx_.manageLeafs[6] = leafs[24]; //use permit2 to approve router

        tx_.manageLeafs[7] = leafs[27]; //addLiqSingleExactOut

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHUSDT; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = waETHGHO; //approve 
        tx_.targets[5] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[6] = getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"); //approve 
        //router calls
        tx_.targets[7] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHUSDT, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHGHO, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[6] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](3); 
        amounts[0] = 10e18;  
        amounts[1] = 0;  
        amounts[2] = 0;  

        tx_.targetData[7] = abi.encodeWithSignature(
            "addLiquiditySingleTokenExactOut(address,address,uint256,uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"),
            waETHUSDC,
            10e18,
            1e8,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[29]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  
        amounts[2] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_USDC_GHO_USDT").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }

    function testBalancerAddRemoveLiqUnbalanced0() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(waETHWETH, address(boringVault), 1_000e18); 
        deal(waETHWSTETH, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), boosted, address(0)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 WETH
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[13]; //approve permit2 WSTETH
        tx_.manageLeafs[3] = leafs[14]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[16]; //approve router to spend bpt
        
        //router calls
        tx_.manageLeafs[5] = leafs[18]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHWSTETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"); //approve 
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 1e18;  
        amounts[1] = 0;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            amounts,
            1e8,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[21]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }

    function testBalancerAddRemoveLiqSingleTokenExactIn() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(waETHWETH, address(boringVault), 1_000e18); 
        deal(waETHWSTETH, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), boosted, address(0)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 WETH
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[13]; //approve permit2 WSTETH
        tx_.manageLeafs[3] = leafs[14]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[16]; //approve router to spend bpt
        
        //router calls
        tx_.manageLeafs[5] = leafs[18]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHWSTETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"); //approve 
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 0.1e18;  
        amounts[1] = 0;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            amounts,
            1e2,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[22]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquiditySingleTokenExactIn(address,uint256,address,uint256,bool,bytes)", getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), lpBalance, waETHWETH, 10, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have 0 lp left
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }

    function testBalancerRemoveLiqSingleTokenExactOut() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        //deal(waETHWETH, address(boringVault), 1_000e18); 
        deal(waETHWSTETH, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), boosted, address(0)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 WETH
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[13]; //approve permit2 WSTETH
        tx_.manageLeafs[3] = leafs[14]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[16]; //approve router to spend bpt
        
        //router calls
        tx_.manageLeafs[5] = leafs[18]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = waETHWSTETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"); //approve 
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 0;  
        amounts[1] = 0.1e18;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            amounts,
            1e2,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_WETH_WSTETH_boosted").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[23]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquiditySingleTokenExactOut(address,uint256,address,uint256,bool,bytes)", getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), lpBalance, waETHWETH, 1e8, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have 1e8 waETHWETH out
        uint256 waETHWETHBalance = ERC20(waETHWETH).balanceOf(address(boringVault)); 
        assertEq(waETHWETHBalance, 1e8); 
    }

    function testBalancerV3Swap__ExactIn() external {
        _setUpMainnet(); 
        
        deal(waETHWETH, address(boringVault), 1_000e18); 
        //deal(waETHWSTETH, address(boringVault), 1_000e18); 
        
        //swapping assumes you already have the necessary tokens to swap into the pool
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBalancerV3SwapLeafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), false); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(5); 
        
        tx_.manageLeafs[0] = leafs[0]; //approve waWETH
        tx_.manageLeafs[1] = leafs[1]; //apporve waWSTETH
        tx_.manageLeafs[2] = leafs[2]; //approve waWSTETH
        tx_.manageLeafs[3] = leafs[3]; //permit2 approve
        tx_.manageLeafs[4] = leafs[4]; //swapExactIn
        

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        //targets
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //approve 
        tx_.targets[2] = waETHWSTETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //approve 
        tx_.targets[4] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced
        
        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );

        tx_.targetData[4] = abi.encodeWithSignature(
            "swapSingleTokenExactIn(address,address,address,uint256,uint256,uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            waETHWETH, //in
            waETHWSTETH, //out
            1e18, //in
            1, //min out
            block.timestamp + 1,
            false,
            bytes("")
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get tokens 
        uint256 bal = ERC20(waETHWSTETH).balanceOf(address(boringVault)); 
        assertGt(bal, 0); 
    }

    function testBalancerV3Swap__ExactOut() external {
        _setUpMainnet(); 
        
        deal(waETHWETH, address(boringVault), 1_000e18); 
        //deal(waETHWSTETH, address(boringVault), 1_000e18); 
        
        //swapping assumes you already have the necessary tokens to swap into the pool
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBalancerV3SwapLeafs(leafs, getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"), false); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(5); 
        
        tx_.manageLeafs[0] = leafs[0]; //approve waWETH
        tx_.manageLeafs[1] = leafs[1]; //apporve waWSTETH
        tx_.manageLeafs[2] = leafs[2]; //approve waWSTETH
        tx_.manageLeafs[3] = leafs[3]; //permit2 approve
        tx_.manageLeafs[4] = leafs[5]; //swapExactOut
        

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        //targets
        tx_.targets[0] = waETHWETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //approve 
        tx_.targets[2] = waETHWSTETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //approve 
        tx_.targets[4] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced
        
        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );

        tx_.targetData[4] = abi.encodeWithSignature(
            "swapSingleTokenExactOut(address,address,address,uint256,uint256,uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            waETHWETH, //in
            waETHWSTETH, //out
            1e18, //exactOut
            10e18, //maxIn
            block.timestamp + 1,
            false,
            bytes("")
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 bal = ERC20(waETHWSTETH).balanceOf(address(boringVault)); 
        assertEq(bal, 1e18); 
    }

    function testBalancerAddRemoveLiqUnbalanced__HooksStableSurge() external {
        _setUpMainnet(); 

        deal(tETH, address(boringVault), 1_000e18); 
        deal(waETHWSTETH, address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_WSTETH_TETH_stablesurge"), boosted, address(0)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 WSTETH
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[13]; //approve permit2 TETH
        tx_.manageLeafs[3] = leafs[14]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[16]; //approve router to spend bpt
        
        //router calls
        tx_.manageLeafs[5] = leafs[18]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = waETHWSTETH; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = tETH; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_WSTETH_TETH_stablesurge"); //approve 
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", waETHWSTETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", tETH, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 1e18;  
        amounts[1] = 0;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_WSTETH_TETH_stablesurge"),
            amounts,
            1e8,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_WSTETH_TETH_stablesurge").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[21]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_WSTETH_TETH_stablesurge"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_WSTETH_TETH_stablesurge").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 
    }


    // Sonic Tests
    
    function testBalancerAddRemoveLiqUnbalanced__Sonic() external {
        _setUpSonic(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(wsSonicUSDC, address(boringVault), 1_000e6); 
        deal(scUSD, address(boringVault), 1_000e6); 

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"), boosted, address(0)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(6); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 WETH
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[8]; //approve permit2 WSTETH
        tx_.manageLeafs[3] = leafs[9]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[11]; //approve router to spend bpt
        
        //router calls
        tx_.manageLeafs[5] = leafs[13]; //addLiqUnbalanced

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = wsSonicUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = scUSD; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"); //approve 
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqUnbalanced

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", wsSonicUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", scUSD, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 100e6;  
        amounts[1] = 0;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"),
            amounts,
            1e6,
            false,
            "" 
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get LP tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_USDC_scUSD_boosted").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(1 days); 

        // Try unbalanced method
        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[16]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3Router"); 

        amounts[0] = 0;  
        amounts[1] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "removeLiquidityProportional(address,uint256,uint256[],bool,bytes)", getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"), lpBalance, amounts, false, "" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_USDC_scUSD_boosted").balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 

    }

    function testBalancerGaugeStaking__Sonic() external {
        _setUpSonic(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)

        deal(wsSonicUSDC, address(boringVault), 1_000e6); 
        deal(scUSD, address(boringVault), 1_000e6); 

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        bool boosted = true; 
        _addBalancerV3Leafs(leafs, getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"), boosted, getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted_gauge")); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(8); 

        tx_.manageLeafs[0] = leafs[5]; //approve permit2 USDCe
        tx_.manageLeafs[1] = leafs[6]; //use permit2 to approve router
        tx_.manageLeafs[2] = leafs[8]; //approve permit2 scUSD
        tx_.manageLeafs[3] = leafs[9]; //use permit2 to approve router
        tx_.manageLeafs[4] = leafs[11]; //approve bpt

        tx_.manageLeafs[5] = leafs[13]; //addLiqUnbalanced
        tx_.manageLeafs[6] = leafs[21]; //approve gauge lp
        tx_.manageLeafs[7] = leafs[22]; //deposit gauge lp


        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = wsSonicUSDC; //approve 
        tx_.targets[1] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[2] = scUSD; //approve 
        tx_.targets[3] = getAddress(sourceChain, "permit2"); //permit2 approves router
        tx_.targets[4] = getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"); //approve 
        
        //router calls
        tx_.targets[5] = getAddress(sourceChain, "balancerV3Router"); //addLiqProportional
        tx_.targets[6] = getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"); //approve 
        tx_.targets[7] = getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted_gauge"); //deposit

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", wsSonicUSDC, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max
        );
        tx_.targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)", scUSD, getAddress(sourceChain, "balancerV3Router"), 1_000e18, type(uint48).max
        );
        tx_.targetData[4] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3Router"), type(uint256).max
        );
        
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 100e6;  
        amounts[1] = 0;  

        tx_.targetData[5] = abi.encodeWithSignature(
            "addLiquidityUnbalanced(address,uint256[],uint256,bool,bytes)", 
            getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted"),
            amounts,
            1e6,
            false,
            "" 
        );

        tx_.targetData[6] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted_gauge"), type(uint256).max 
        );
        tx_.targetData[7] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1e6, address(boringVault)  
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get gauge staking tokens 
        uint256 lpBalance = getERC20(sourceChain, "balancerV3_USDC_scUSD_boosted_gauge").balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        skip(10 days); 
    
        //claim rewards, withdraw lp, then remove liquidity
        tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[24]; 
        tx_.manageLeafs[1] = leafs[23]; 

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted_gauge"); 
        tx_.targets[1] = getAddress(sourceChain, "balancerV3_USDC_scUSD_boosted_gauge"); 

        amounts[0] = 0;  
        amounts[1] = 0;  

        tx_.targetData[0] = abi.encodeWithSignature(
            "claim_rewards(address)", address(boringVault) 
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "withdraw(uint256)", lpBalance
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have more LP now
        uint256 lpBalance2 = getERC20(sourceChain, "balancerV3_USDC_scUSD_boosted").balanceOf(address(boringVault)); 
        assertGt(lpBalance2, 0); 

        //check we have more BEETS now
        uint256 BEETSRewards = getERC20(sourceChain, "BEETS").balanceOf(address(boringVault));  
        assertGt(BEETSRewards, 0); 
    }         

}
