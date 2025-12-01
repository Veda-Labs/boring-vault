// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RedSnwapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RedSnwapperDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullRedSnwapperDecoderAndSanitizer is RedSnwapperDecoderAndSanitizer, BaseDecoderAndSanitizer { }

contract RedSnwapperIntegration is BaseTestIntegration {
        
    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 23576581); 
            
        address snwapperDecoder = address(new FullRedSnwapperDecoderAndSanitizer()); 

        _overrideDecoder(snwapperDecoder); 
    }

    function _setUpPlasma() internal {
        super.setUp(); 
        _setupChain("plasma", 3512356); 
            
        address snwapperDecoder = address(new FullRedSnwapperDecoderAndSanitizer()); 

        _overrideDecoder(snwapperDecoder); 
    }


    function testSwapMainnet() external {
        _setUpMainnet(); 
        
        address SNX = 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F;

        vm.prank(0xA31231E727Ca53Ff95f0D00a06C645110c4aB647); 
        ERC20(SNX).transfer(address(boringVault), 100000e18); 

        address[] memory tokens = new address[](2);   
        SwapKind[] memory kind = new SwapKind[](2); 
        tokens[0] = getAddress(sourceChain, "WETH"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = SNX;
        kind[1] = SwapKind.BuyAndSell; 
        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        _addSnwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[3]; //approve SNX
        tx_.manageLeafs[1] = leafs[2]; //swap SNX for WETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    
        //targets
        tx_.targets[0] = SNX; //approve
        tx_.targets[1] = getAddress(sourceChain, "redSnwapperRouter"); //swap

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "redSnwapperRouter"), type(uint256).max
        );
        
        //https://etherscan.io/tx/0xc2f749670557ef2b7aab4bf4ed2844ef7aa2b97c7c5a8e69e1534dc0a5c76566 
        //we are editing the calldata directly here because sushi has checks for slippage after and encodes the recipient into the calldata, so we have to edit it 
        tx_.targetData[1] = abi.encodeWithSignature(
            "snwap(address,uint256,address,address,uint256,address,bytes)",
            0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F,
            1132015887667565350796,
            address(boringVault),
            getAddress(sourceChain, "WETH"),
            530321444838082344,
            0xd2b37aDE14708bf18904047b1E31F8166d39612b,
            hex"ba3f2165000000000000000000000000de7259893af7cdbc9fd806c6ba61d22d581d56670000000000000000000000000000000000000000000000000004b8d55c9cc5f3000000000000000000000000c011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f00000000000000000000000000000000000000000000003d5de054280bbacf8c000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000076a4b31984794400000000000000000000000005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f00000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000bb0199e3270bdf000301c011a73ee8576fb46f5e1c5751ca3b9fe0af2a6f03aaaa0043ae24960e5534731fc831386c07755a2dc33d4701d2b37ade14708bf18904047b1e31f8166d39612b000bb8a3a5369e5a2baaaa00a1d7b2d891e3a1f9ef4bbc5be20630c2feb1c47001d2b37ade14708bf18904047b1e31f8166d39612b000bb8da3134d2bf29ffff01ede8dd046586d22625ae7ff2708f879ef7bdb8cf01d2b37ade14708bf18904047b1e31f8166d39612b00da3133d1fd280000000000"
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 
        
        _submitManagerCall(manageProofs, tx_); 
        
        uint256 wethBalance = getERC20(sourceChain, "WETH").balanceOf(address(boringVault)); 
        assertGt(wethBalance, 0); 
    }

    function testSwapPlasma() external {
        _setUpPlasma(); 
        
        deal(getAddress(sourceChain, "WXPL"), address(boringVault), 100000e18);         

        address[] memory tokens = new address[](2);   
        SwapKind[] memory kind = new SwapKind[](2); 
        tokens[0] = getAddress(sourceChain, "WXPL"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "USDT0");
        kind[1] = SwapKind.BuyAndSell; 
        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        _addSnwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve SNX
        tx_.manageLeafs[1] = leafs[1]; //swap SNX for WETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    
        //targets
        tx_.targets[0] = getAddress(sourceChain, "WXPL"); //approve
        tx_.targets[1] = getAddress(sourceChain, "redSnwapperRouter"); //swap

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "redSnwapperRouter"), type(uint256).max
        );
        
        //https://plasmascan.to/tx/0x7fdbac8a06d684902889ad2471413d46d00252b00f764cf962df310f4c398139 
        //we are editing the calldata directly here because sushi has checks for slippage after and encodes the recipient into the calldata, so we have to edit it 
        tx_.targetData[1] = abi.encodeWithSignature(
            "snwap(address,uint256,address,address,uint256,address,bytes)",
            getAddress(sourceChain, "WXPL"),
            1.64e20,
            address(boringVault),
            getAddress(sourceChain, "USDT0"),
            68001365,
            0xd2b37aDE14708bf18904047b1E31F8166d39612b,
            hex"ba3f2165000000000000000000000000de7259893af7cdbc9fd806c6ba61d22d581d566700000000000000000000000000000000000000000000000000000000000299bd0000000000000000000000006100e367285b01f48d07953803a2d8dca5d19873000000000000000000000000000000000000000000000008debbe5fdadb62b56000000000000000000000000b8ce59fc3717ada4c02eadf9682a9e934f625ebb000000000000000000000000000000000000000000000000000000000415723e0000000000000000000000005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f00000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000510199e28153f60001016100e367285b01f48d07953803a2d8dca5d1987301ffff018603c67b7cc056ef6981a9c709854c53b699fa6601d2b37ade14708bf18904047b1e31f8166d39612b008dec3482ae0b000000000000000000000000000000");

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 
        
        _submitManagerCall(manageProofs, tx_); 
        
        uint256 usdtBalance = getERC20(sourceChain, "USDT0").balanceOf(address(boringVault)); 
        assertGt(usdtBalance, 0); 
    }
}
