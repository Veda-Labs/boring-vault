// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {AvalancheBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AvalancheBridgeDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullAvalancheBridgeDecoderAndSanitizer is 
    BaseDecoderAndSanitizer,
    AvalancheBridgeDecoderAndSanitizer
{

}

contract AvalancheBridgeIntegration is BaseTestIntegration {
        
    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22775708); 
            
        address avalancheDecoder = address(new FullAvalancheBridgeDecoderAndSanitizer()); 

        _overrideDecoder(avalancheDecoder); 
    }

    function _setUpAvalanche() internal {
        super.setUp(); 
        _setupChain("avalanche", 38455925); 
            
        address avalancheDecoder = address(new FullAvalancheBridgeDecoderAndSanitizer()); 

        _overrideDecoder(avalancheDecoder); 
    }

    function testAvalancheBridgeETHMainnet() external {
        _setUpMainnet();      
        
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18); 
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        ERC20[] memory assets = new ERC20[](2); 
        assets[0] = getERC20(sourceChain, "USDC"); 
        assets[1] = getERC20(sourceChain, "WETH"); 
        
        _addAvalancheBridgeLeafs(leafs, assets);  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //call transferTokens
        tx_.manageLeafs[2] = leafs[2]; //transfer WETH
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "usdcTokenRouter"); //transferTokens
        tx_.targets[2] = getAddress(sourceChain, "WETH"); //transfer

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "usdcTokenRouter"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "transferTokens(uint256,uint32,address,address)", 
            100e6,
            1, //1 to send to avalanche
            address(boringVault),
            getAddress(sourceChain, "USDC")
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "transfer(address,uint256)", 
            getAddress(sourceChain, "avalancheBridge"),
            1e18
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 
    }

    function testAvalancheBridgeAvalancheUSDC() external {
        _setUpAvalanche();      
        
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18); 
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        ERC20[] memory assets = new ERC20[](1); 
        assets[0] = getERC20(sourceChain, "USDC"); 
        
        _addAvalancheBridgeLeafs(leafs, assets);  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //call transferTokens
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "usdcTokenRouter"); //transferTokens

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "usdcTokenRouter"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "transferTokens(uint256,uint32,address,address)", 
            100e6,
            0, //0 to send to ethereum
            address(boringVault),
            getAddress(sourceChain, "USDC")
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 
    }

    function testAvalancheBridgeAvalancheWETH__Fails() external {
        _setUpAvalanche();      
        
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18); 
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6); 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        ERC20[] memory assets = new ERC20[](1); 
        assets[0] = getERC20(sourceChain, "WETH"); 

        vm.expectRevert(); 
        _addAvalancheBridgeLeafs(leafs, assets);  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(3); 

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //call transferTokens
        tx_.manageLeafs[2] = leafs[2]; //transfer WETH
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        //targets
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "usdcTokenRouter"); //transferTokens
        tx_.targets[2] = getAddress(sourceChain, "WETH"); //transfer

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "usdcTokenRouter"), type(uint256).max
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "transferTokens(uint256,uint32,address,address)", 
            100e6,
            0, //0 to send to ethereum
            address(boringVault),
            getAddress(sourceChain, "USDC")
        );
        tx_.targetData[2] = abi.encodeWithSignature(
            "unwrap(uint256,uint256)", 
            1e18,
            0
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        
        _submitManagerCall(manageProofs, tx_); 
    }
}
