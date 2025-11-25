// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {DvStETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DvStETHDecoderAndSanitizer.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullDvStETHDecoderAndSanitizer is ERC4626DecoderAndSanitizer, BaseDecoderAndSanitizer, DvStETHDecoderAndSanitizer {

    constructor(address _dvstETH) ERC4626DecoderAndSanitizer() BaseDecoderAndSanitizer() DvStETHDecoderAndSanitizer(_dvstETH){}

    /*function deposit(
        uint256 amount,
        address receiver,
        address referral
    ) external view returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, referral);
    }*/
}

contract DVstETHIntegrationTest is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 23627622); 
            
        address dvStETHDecoder = address(new FullDvStETHDecoderAndSanitizer(getAddress(sourceChain, "dvstETH"))); 

        _overrideDecoder(dvStETHDecoder); 
    }

    function testDvStETHIntegrationDepositViaWhitelistedEthWrapper() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18); 
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addDvStETHLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

       // _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2);
        
        tx_.manageLeafs[0] = leafs[0]; //approve
        tx_.manageLeafs[1] = leafs[1]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "WETH");  
        tx_.targets[1] = getAddress(sourceChain, "dvStethWhitelistedEthWrapper");  
        
        
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dvStethWhitelistedEthWrapper"), type(uint256).max
        );
    
        uint amount = 1e18;
        
        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256,address,address,address)",
            getAddress(sourceChain, "WETH"),
            amount,
            getAddress(sourceChain, "dvstETH"),
            address(boringVault),
            address(0)
        );
        
        //decoders 
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
        console.log("dvstETH balance of boringVault", getERC20(sourceChain, "dvstETH").balanceOf(address(boringVault)));
        console.log("dvstETH balance of this", getERC20(sourceChain, "dvstETH").balanceOf(address(this)));
        console.log("WETH balance of boringVault", getERC20(sourceChain, "WETH").balanceOf(address(boringVault)));
        console.log("WSTETH balance of dvstETH", getERC20(sourceChain, "WSTETH").balanceOf(getAddress(sourceChain, "dvstETH")));
    }

    function testDvStETHIntegrationRedeemDvStETHVault() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "dvstETH"), address(boringVault), 10e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addDvStETHLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

       // _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[6]; //redeem

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "dvstETH");  

        tx_.targetData[0] = abi.encodeWithSignature("redeem(uint256,address,address)", 1e18, address(boringVault), address(boringVault));

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
        console.log("dvstETH balance of boringVault", getERC20(sourceChain, "dvstETH").balanceOf(address(boringVault)));
        console.log("WSTETH balance of boringVault", getERC20(sourceChain, "WSTETH").balanceOf(address(boringVault)));
    }

        function testDvStETHIntegrationWithdrawDvStETHVault() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "dvstETH"), address(boringVault), 10e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addDvStETHLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

       // _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[4]; //withdraw

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "dvstETH");  

        tx_.targetData[0] = abi.encodeWithSignature("withdraw(uint256,address,address)", 1e18, address(boringVault), address(boringVault));

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
        console.log("dvstETH balance of boringVault", getERC20(sourceChain, "dvstETH").balanceOf(address(boringVault)));
        console.log("WSTETH balance of boringVault", getERC20(sourceChain, "WSTETH").balanceOf(address(boringVault)));
    }

    /*function testDvStETHIntegrationMintDvStETHVault() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 10e18); 
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addDvStETHLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

       // _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[2]; //approve
        tx_.manageLeafs[1] = leafs[5]; //mint

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "WSTETH");  
        tx_.targets[1] = getAddress(sourceChain, "dvstETH");  
        
        
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "dvstETH"), type(uint256).max
        );
    
        uint amount = 1e18;
        
        tx_.targetData[1] = abi.encodeWithSignature(
            "mint(uint256,address)",
            amount,
            address(boringVault)
        );
        
        //decoders 
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
        console.log("dvstETH balance of boringVault", getERC20(sourceChain, "dvstETH").balanceOf(address(boringVault)));
        console.log("dvstETH balance of this", getERC20(sourceChain, "dvstETH").balanceOf(address(this)));
        console.log("WETH balance of boringVault", getERC20(sourceChain, "WETH").balanceOf(address(boringVault)));
        console.log("WSTETH balance of dvstETH", getERC20(sourceChain, "WSTETH").balanceOf(getAddress(sourceChain, "dvstETH")));
    }*/
    
}


/*contract BalancerV3IntegrationTest is BaseTestIntegration {

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
*/

