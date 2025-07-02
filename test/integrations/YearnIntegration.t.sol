// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullYearnDecoderAndSanitizer is SpectraDecoderAndSanitizer {}

contract YearnIntegrationTest is BaseTestIntegration {

    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22724089); 
            
        address yearnDecoder = address(new FullYearnDecoderAndSanitizer()); 

        _overrideDecoder(yearnDecoder); 
    }


    function testYearnWithdrawSlippageChecks() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)
        
        address yearnVault = 0xcc6a16Be713f6a714f68b0E1f4914fD3db15fBeF; 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addYearnLeafs(leafs, ERC4626(yearnVault)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 

        tx_.manageLeafs[0] = leafs[0]; //approve WETH 
        tx_.manageLeafs[1] = leafs[1]; //deposit WETH 
        tx_.manageLeafs[2] = leafs[6]; //withdraw WETH w/ slippage

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = yearnVault; //deposit
        tx_.targets[2] = yearnVault; //withdraw

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", yearnVault, type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1e18, address(boringVault)
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "withdraw(uint256,address,address,uint256)", 1e18, address(boringVault), address(boringVault), 150 
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 
    }

    function testYearnRedeemSlippageChecks() external {
        _setUpMainnet(); 
        //Test all the leaves necessary for building an LP position from a base asset (USDC, USDT)
        
        address yearnVault = 0xcc6a16Be713f6a714f68b0E1f4914fD3db15fBeF; 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addYearnLeafs(leafs, ERC4626(yearnVault)); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 

        tx_.manageLeafs[0] = leafs[0]; //approve WETH 
        tx_.manageLeafs[1] = leafs[1]; //deposit WETH 
        tx_.manageLeafs[2] = leafs[5]; //redeem WETH w/ slippage

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = yearnVault; //deposit
        tx_.targets[2] = yearnVault; //redeem

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", yearnVault, type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(uint256,address)", 1e18, address(boringVault)
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "redeem(uint256,address,address,uint256)", 0.9e18, address(boringVault), address(boringVault), 150 
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 
    }
}

