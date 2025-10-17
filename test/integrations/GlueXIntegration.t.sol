// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {GlueXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GlueXDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullGlueXDecoderAndSanitizer is GlueXDecoderAndSanitizer, BaseDecoderAndSanitizer { }

contract GlueXIntegration is BaseTestIntegration {
        
    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 23569229); 
            
        address glueXDecoder = address(new FullGlueXDecoderAndSanitizer()); 

        _overrideDecoder(glueXDecoder); 
    }

    function _setUpPlasma() internal {
        super.setUp(); 
        _setupChain("plasma", 3506874); 
            
        address glueXDecoder = address(new FullGlueXDecoderAndSanitizer()); 

        _overrideDecoder(glueXDecoder); 
    }

    function testSwapMainnet() external {
        _setUpMainnet(); 
        
        //starting with just the base assets 
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000e18); 

        address[] memory tokens = new address[](2);   
        SwapKind[] memory kind = new SwapKind[](2); 
        tokens[0] = getAddress(sourceChain, "USDT"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = 0x9FD7466f987Fd4C45a5BBDe22ED8aba5BC8D72d1; 
        kind[1] = SwapKind.BuyAndSell; 
        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        _addGlueXLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token0
        tx_.manageLeafs[1] = leafs[3]; //swap USDT for hwHLP

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    
        //targets
        tx_.targets[0] = getAddress(sourceChain, "USDT"); //approve
        tx_.targets[1] = getAddress(sourceChain, "glueXRouter"); //swap

        DecoderCustomTypes.RouteDescription memory route = DecoderCustomTypes.RouteDescription({
            inputToken: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            outputToken: 0x9FD7466f987Fd4C45a5BBDe22ED8aba5BC8D72d1,
            inputReceiver: payable(0x2102Ab11A3c74B1D543891020969dc3D46C132AB),
            outputReceiver: payable(address(boringVault)),
            partnerAddress: payable(address(0)),
            inputAmount: 640629735,
            outputAmount: 562120106,
            partnerFee: 0,
            routingFee: 0,
            partnerSurplusShare: 5000,
            protocolSurplusShare: 5000,
            partnerSlippageShare: 3300, 
            protocolSlippageShare: 6600,
            effectiveOutputAmount: 562120106,
            minOutputAmount: 550877703, 
            isPermit2: false,
            uniquePID: 0x1d9b2b29e27b739431a7883b86f1b45be9d0a8ad037a91519bf36c593ef07c46
        }); 

        DecoderCustomTypes.Interaction[] memory interactions = new DecoderCustomTypes.Interaction[](2); 
        interactions[0] = DecoderCustomTypes.Interaction({
            target: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            value: 0,
            callData: hex"095ea7b30000000000000000000000009fd7466f987fd4c45a5bbde22ed8aba5bc8d72d100000000000000000000000000000000000000000000000000000000262f3be7"
        });
        interactions[1] = DecoderCustomTypes.Interaction({
            target: 0xfA9D7D4709716b90Cd5013fD88fB17AEEDd24Bc4,
            value: 0,
            callData: hex"0efe6a8b000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000262f3be70000000000000000000000000000000000000000000000000000000020d5ba07"
        }); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "glueXRouter"), type(uint256).max
        );
        
        tx_.targetData[1] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bytes32),(address,uint256,bytes)[])",
            0x2102Ab11A3c74B1D543891020969dc3D46C132AB,
            route,
            interactions
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 
        
        _submitManagerCall(manageProofs, tx_); 
            
        address hwHLP = 0x9FD7466f987Fd4C45a5BBDe22ED8aba5BC8D72d1;  
        uint256 vaultBalance = ERC20(hwHLP).balanceOf(address(boringVault)); 
        assertEq(vaultBalance, 562120106); 
    }

    function testSwapPlasma() external {
        _setUpPlasma(); 
        
        //starting with just the base assets 
        deal(getAddress(sourceChain, "WXPL"), address(boringVault), 1_000e18); 

        address[] memory tokens = new address[](2);   
        SwapKind[] memory kind = new SwapKind[](2); 
        tokens[0] = getAddress(sourceChain, "WXPL"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = 0x92A01Ab7317Ac318b39b00EB6704ba56F0245D7a; 
        kind[1] = SwapKind.BuyAndSell; 
        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        _addGlueXLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token0
        tx_.manageLeafs[1] = leafs[3]; //swap WXPL for trillions

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    
        //targets
        tx_.targets[0] = getAddress(sourceChain, "WXPL"); //approve
        tx_.targets[1] = getAddress(sourceChain, "glueXRouter"); //swap

        DecoderCustomTypes.RouteDescription memory route = DecoderCustomTypes.RouteDescription({
            inputToken: 0x6100E367285b01F48D07953803A2d8dCA5D19873,
            outputToken: 0x92A01Ab7317Ac318b39b00EB6704ba56F0245D7a,
            inputReceiver: payable(0x2102Ab11A3c74B1D543891020969dc3D46C132AB),
            outputReceiver: payable(address(boringVault)),
            partnerAddress: payable(address(0)),
            inputAmount: 1943727989510338943,
            outputAmount: 135401478313139290112,
            partnerFee: 0,
            routingFee: 0,
            partnerSurplusShare: 0,
            protocolSurplusShare: 10000,
            partnerSlippageShare: 0, 
            protocolSlippageShare: 6600,
            effectiveOutputAmount: 135333777573982720464,
            minOutputAmount: 132356434467355099136, 
            isPermit2: false,
            uniquePID: 0x866a61811189692e8eccae5d2759724a812fa6f8703ebffe90c29dc1f886bbc1
        }); 

        DecoderCustomTypes.Interaction[] memory interactions = new DecoderCustomTypes.Interaction[](2); 
        interactions[0] = DecoderCustomTypes.Interaction({
            target: 0x6100E367285b01F48D07953803A2d8dCA5D19873,
            value: 0,
            callData: hex"a9059cbb00000000000000000000000005f10be187252b2858b9592714376787ce01bb760000000000000000000000000000000000000000000000001af9824ee2bf797f"
        });
        interactions[1] = DecoderCustomTypes.Interaction({
            target: 0xc4dC928BED00a8aee692F786CF5625aF2Dcd947E,
            value: 0,
            callData: hex"5a91c34c00000000000000000000000005f10be187252b2858b9592714376787ce01bb760000000000000000000000000000000000000000000000001af9824ee2bf797f0000000000000000000000000000000000000000000000072dbbbebdb13dc0000000000000000000000000002102ab11a3c74b1d543891020969dc3d46c132ab0000000000000000000000000000000000000000000000000000000026f74e21"
        }); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "glueXRouter"), type(uint256).max
        );
        
        tx_.targetData[1] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bytes32),(address,uint256,bytes)[])",
            0x2102Ab11A3c74B1D543891020969dc3D46C132AB,
            route,
            interactions
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 
        
        _submitManagerCall(manageProofs, tx_); 
            
        address trillions = 0x92A01Ab7317Ac318b39b00EB6704ba56F0245D7a;  
        uint256 vaultBalance = ERC20(trillions).balanceOf(address(boringVault)); 
        assertGt(vaultBalance, 0); 
    }

}
