// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DvStETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DvStETHDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullDvStETHDecoderAndSanitizer is DvStETHDecoderAndSanitizer {

    constructor(address _vault) DvStETHDecoderAndSanitizer(_vault){}
}


contract BalancerV3IntegrationTest is BaseTestIntegration {

    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22067550); 
            
        address dvStETHDecoder= address(new FullDvStETHDecoderAndSanitizer(getAddress(sourceChain, "dvStETHVault"))); 

        _overrideDecoder(dvStETHDecoder); 
    }

    function testDvStETHIntegration() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory depositTokens = new address[](2); 
        depositTokens[0] = getAddress(sourceChain, "WETH"); 
        depositTokens[1] = getAddress(sourceChain, "WSTETH"); 
        _addDvStETHLeafs(leafs, depositTokens); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3);

        tx_.manageLeafs[0] = leafs[0]; //approve
        tx_.manageLeafs[1] = leafs[1]; //deposit
        tx_.manageLeafs[2] = leafs[4]; //registerWithdraw

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = getAddress(sourceChain, "WETH");  
        tx_.targets[1] = getAddress(sourceChain, "dvStETHVault");  
        tx_.targets[2] = getAddress(sourceChain, "dvStETHVault");  

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dvStETHVault"), type(uint256).max
        );
    
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 0; //no wsteth
        amounts[1] = 1e18; //weth amount

        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256[],uint256,uint256,uint256)",
            address(boringVault),
            amounts,
            0,
            block.timestamp + 5,
            0
        );
        
        uint256 lpAmount = 984338263058981516;  

        amounts[0] = 0; 
        amounts[1] = 0; 
        tx_.targetData[2] = abi.encodeWithSignature(
            "registerWithdrawal(address,uint256,uint256[],uint256,uint256,bool)",
            address(boringVault),
            lpAmount,
            amounts,
            block.timestamp + 5,
            block.timestamp + 10,
            false
        );
        
        //decoders 
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 
    }

    function testDvStETHIntegrationCancel() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory depositTokens = new address[](2); 
        depositTokens[0] = getAddress(sourceChain, "WETH"); 
        depositTokens[1] = getAddress(sourceChain, "WSTETH"); 
        _addDvStETHLeafs(leafs, depositTokens); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(4);

        tx_.manageLeafs[0] = leafs[0]; //approve
        tx_.manageLeafs[1] = leafs[1]; //deposit
        tx_.manageLeafs[2] = leafs[4]; //registerWithdraw
        tx_.manageLeafs[3] = leafs[5]; //registerWithdraw

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = getAddress(sourceChain, "WETH");  
        tx_.targets[1] = getAddress(sourceChain, "dvStETHVault");  
        tx_.targets[2] = getAddress(sourceChain, "dvStETHVault");  
        tx_.targets[3] = getAddress(sourceChain, "dvStETHVault");  

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dvStETHVault"), type(uint256).max
        );
    
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 0; //no wsteth
        amounts[1] = 1e18; //weth amount

        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256[],uint256,uint256,uint256)",
            address(boringVault),
            amounts,
            0,
            block.timestamp + 5,
            0
        );
        
        uint256 lpAmount = 984338263058981516;  

        amounts[0] = 0; 
        amounts[1] = 0; 
        tx_.targetData[2] = abi.encodeWithSignature(
            "registerWithdrawal(address,uint256,uint256[],uint256,uint256,bool)",
            address(boringVault),
            lpAmount,
            amounts,
            block.timestamp + 5,
            block.timestamp + 10,
            false
        );

        tx_.targetData[3] = abi.encodeWithSignature("cancelWithdrawalRequest()");
        //decoders 
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 
    }

    function testDvStETHIntegrationEmergencyWithdraw() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory depositTokens = new address[](2); 
        depositTokens[0] = getAddress(sourceChain, "WETH"); 
        depositTokens[1] = getAddress(sourceChain, "WSTETH"); 
        _addDvStETHLeafs(leafs, depositTokens); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3);

        tx_.manageLeafs[0] = leafs[0]; //approve
        tx_.manageLeafs[1] = leafs[1]; //deposit
        tx_.manageLeafs[2] = leafs[4]; //registerWithdraw

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");  
        tx_.targets[1] = getAddress(sourceChain, "dvStETHVault");  
        tx_.targets[2] = getAddress(sourceChain, "dvStETHVault");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dvStETHVault"), type(uint256).max
        );
    
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 0; //no wsteth
        amounts[1] = 1e18; //weth amount

        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256[],uint256,uint256,uint256)",
            address(boringVault),
            amounts,
            0,
            block.timestamp + 5,
            0
        );
        
        uint256 lpAmount = 984338263058981516;  

        amounts[0] = 0; 
        amounts[1] = 0; 
        tx_.targetData[2] = abi.encodeWithSignature(
            "registerWithdrawal(address,uint256,uint256[],uint256,uint256,bool)",
            address(boringVault),
            lpAmount,
            amounts,
            block.timestamp + 5,
            block.timestamp + 10,
            false
        );

        //decoders 
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 



        skip(7776001); 



        tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[6]; //emergencyWithdraw

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "dvStETHVault");  

        tx_.targetData[0] = abi.encodeWithSignature("emergencyWithdraw(uint256[],uint256)", amounts, block.timestamp + 5);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 
    }

    function testDvStETHIntegrationReverts() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory depositTokens = new address[](2); 
        depositTokens[0] = getAddress(sourceChain, "WETH"); 
        depositTokens[1] = getAddress(sourceChain, "WSTETH"); 
        _addDvStETHLeafs(leafs, depositTokens); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve
        tx_.manageLeafs[1] = leafs[1]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = getAddress(sourceChain, "WETH");  
        tx_.targets[1] = getAddress(sourceChain, "dvStETHVault");  

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dvStETHVault"), type(uint256).max
        );
    
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 1e18; //no wsteth
        amounts[1] = 1e18; //weth amount

        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256[],uint256,uint256,uint256)",
            address(boringVault),
            amounts,
            0,
            block.timestamp + 5,
            0
        );
        
        //decoders 
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        
        vm.expectRevert(abi.encodeWithSelector(DvStETHDecoderAndSanitizer.DvStETHDecoderAndSanitizer__OnlyOneAmount.selector));
        _submitManagerCall(manageProofs, tx_); 
    }

    function testDvStETHIntegrationDepositWSETH() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 10e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory depositTokens = new address[](2); 
        depositTokens[0] = getAddress(sourceChain, "WETH"); 
        depositTokens[1] = getAddress(sourceChain, "WSTETH"); 
        _addDvStETHLeafs(leafs, depositTokens); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[2]; //approve
        tx_.manageLeafs[1] = leafs[3]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //address[] memory targets = new address[](7);
        tx_.targets[0] = getAddress(sourceChain, "WSTETH");  
        tx_.targets[1] = getAddress(sourceChain, "dvStETHVault");  

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dvStETHVault"), type(uint256).max
        );
    
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 1e18; //wsteth
        amounts[1] = 0; //no weth amount

        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256[],uint256,uint256,uint256)",
            address(boringVault),
            amounts,
            0,
            block.timestamp + 5,
            0
        );
        
        //decoders 
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        
        vm.expectRevert(); //this is failing on their end, they are not allowing wsteth deposits atm? ratio is set to 0 in configurator.  
        _submitManagerCall(manageProofs, tx_); 
    }


}
