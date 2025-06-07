// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {KodiakIslandDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol"; 
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol"; 
import {OogaBoogaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OogaBoogaDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullBerachainDecoder is 
    KodiakIslandDecoderAndSanitizer,
    InfraredDecoderAndSanitizer,
    OogaBoogaDecoderAndSanitizer
{

}

contract BerachainPOLIntegrationTest is BaseTestIntegration {
        
    function _setUpBerachain() internal {
        super.setUp(); 
        _setupChain("berachain", 2950067); 
            
        address berachainDecoder = address(new FullBerachainDecoder()); 

        _overrideDecoder(berachainDecoder); 
    }

    function testFullPOLFlow() external {
        _setUpBerachain(); 
        
        //starting with just the base assets 
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18); 
        deal(getAddress(sourceChain, "beraETH"), address(boringVault), 1_000e18); 

        address[] memory islands = new address[](1); 
        islands[0] = 0x03bCcF796cDef61064c4a2EffdD21f1AC8C29E92; 

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ==== Kodiak ====
        _addKodiakIslandLeafs(leafs, islands); 


        // ==== Infrared ====
        address wethBeraETHVault = 0xfbC99D74cC43cF12EB6b78EDdCC2266Ff729bE19; 
        _addInfraredVaultLeafs(leafs, wethBeraETHVault); 

        // ==== Ooga Booga ====
        address[] memory assets = new address[](3); 
        SwapKind[] memory kind = new SwapKind[](3); 
        assets[0] = getAddress(sourceChain, "iBGT"); 
        kind[0] = SwapKind.Sell; 
        assets[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        assets[2] = getAddress(sourceChain, "beraETH"); 
        kind[2] = SwapKind.BuyAndSell; 
        
        _addOogaBoogaSwapLeafs(leafs, assets, kind); 
        

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 

        tx_.manageLeafs[0] = leafs[0]; //approve token0
        tx_.manageLeafs[1] = leafs[1]; //approve token1
        tx_.manageLeafs[2] = leafs[3]; //addLiquidity


        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    
        //targets
        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "beraETH"); //approve 
        tx_.targets[2] = getAddress(sourceChain, "kodiakIslandRouter"); //approve 
        

        //bytes[] memory targetData = new bytes[](7);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouter"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouter"), type(uint256).max
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address)", 
            islands[0],
            1000e18,
            1000e18,
            900e18,
            900e18,
            0,
            address(boringVault)   
        );

        //address[] memory decodersAndSanitizers = new address[](7);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 

        //assert we actually get island tokens 
        uint256 lpBalance = ERC20(islands[0]).balanceOf(address(boringVault)); 
        assertGt(lpBalance, 0); 

        console.log("BORING VAULT NOW HAS: ", lpBalance, " ISLAND LP TOKENS"); 
        
        //now we stake on infrared

        tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[5]; //approve vault to spend island lp
        tx_.manageLeafs[1] = leafs[6]; //stake()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
       tx_.targets[0] = islands[0]; //approve island to be spent by infrared vault
       tx_.targets[1] = wethBeraETHVault; 

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", wethBeraETHVault, type(uint256).max 
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "stake(uint256)", lpBalance
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //check we have 0 LP now
        uint256 lpBalance2 = ERC20(islands[0]).balanceOf(address(boringVault)); 
        assertEq(lpBalance2, 0); 

        console.log("BORING VAULT HAS STAKED"); 

        //skip 1 week to accumulate rewards
        skip(1 weeks); 

        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[9]; //getReward()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
       tx_.targets[0] = wethBeraETHVault; 

        tx_.targetData[0] = abi.encodeWithSignature(
            "getReward()" 
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //assert we got some rewards 
        uint256 rewardBalance = getERC20(sourceChain, "iBGT").balanceOf(address(boringVault)); 
        assertGt(rewardBalance, 0); 

        console.log("BORING VAULT HAS ", rewardBalance, "iBGT TOKENS AFTER 1 WEEK"); 


        //we we sell the iBGT
        tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[11]; //approve OBRouter to spend iBGT
        tx_.manageLeafs[1] = leafs[12]; //stake()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
       tx_.targets[0] = getAddress(sourceChain, "iBGT"); //approve island to be spent by infrared vault
       tx_.targets[1] = getAddress(sourceChain, "OBRouter"); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "OBRouter"), type(uint256).max 
        ); 

        DecoderCustomTypes.swapTokenInfoOogaBooga memory swapTokenInfo = DecoderCustomTypes.swapTokenInfoOogaBooga({
            inputToken: getAddress(sourceChain, "iBGT"),
            inputAmount: rewardBalance,
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: 4453404017,
            outputMin: 4448636996,
            outputReceiver: address(boringVault)
        }); 

        bytes memory pathDefinition = hex"2f6f07cdcf3588944bf4c42ac74ff24bf56e7590000000000000000000000000000000000000000000000000000000284f46af0a7100000000000000000000000000000000000000000000000000002819b72471e40000000000000000000000000000000000000000000000000000284970acf46601ac03caba51e17c86c921e1f6cbfbdc91f8bb2e6b01ffff0112bf773f18cec56f14e7cb91d82984ef5a3148ee00a700f8e594098a3607ffb603c91e9dfd37017cf701696969696969696969696969696969696969696901ffff01d6481d35c3c370a08fb3d50ac0b0ca5f2b77cf0600a700f8e594098a3607ffb603c91e9dfd37017cf7"; 

        tx_.targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, getAddress(sourceChain, "OBExecutor"), 0
        );


        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
         
        //check that swap went through 
        //assert we sold all iBGT for WETH
        rewardBalance = getERC20(sourceChain, "iBGT").balanceOf(address(boringVault)); 
        assertEq(rewardBalance, 0); 

    }
}
