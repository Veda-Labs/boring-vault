// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {TacCrossChainLayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TacCrossChainLayerDecoderAndSanitizer.sol"; 
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullTACDecoder is TacCrossChainLayerDecoderAndSanitizer, BaseDecoderAndSanitizer { }

contract TacCrossChainIntegration is BaseTestIntegration {

    function _setUpTac() internal {
        super.setUp(); 
        _setupChain("tac", 2219681); 
            
        address tacDecoder = address(new FullTACDecoder()); 

        _overrideDecoder(tacDecoder); 
    }

    function testSendMessage() external {
        _setUpTac(); 
        
        //starting with just the base assets 
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000e18); 
        deal(address(boringVault), 1_000e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](128);
        
        string memory tvmTarget = "EQAfvsbMnBsK_ItgK4uVkxYzxqsREx9uVW5BU3VNv0tjynYe"; 
        _addTacCrossChainLeafs(leafs, getERC20(sourceChain, "USDT"), tvmTarget); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        
        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve
        tx_.manageLeafs[1] = leafs[1]; //sendMessage
         
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "USDT"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "crossChainLayer"); //sendMessage
        
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "crossChainLayer"), type(uint256).max
        );
    
        string[] memory executors = new string[](1); 
        executors[0] = "EQB9Yo7kY7hlsVB6aei8ZkSpiI2OPC_kkbh5KAoUrKW04ZxW"; 

        DecoderCustomTypes.TokenAmount[] memory tokenAmounts = new DecoderCustomTypes.TokenAmount[](1); 
        tokenAmounts[0] = DecoderCustomTypes.TokenAmount(getAddress(sourceChain, "USDT"), 100e6); 

        DecoderCustomTypes.NFTAmount[] memory nftAmounts = new DecoderCustomTypes.NFTAmount[](0); 
    
        DecoderCustomTypes.OutMessageV1 memory message = DecoderCustomTypes.OutMessageV1(
            350781532111736576,
            "EQAfvsbMnBsK_ItgK4uVkxYzxqsREx9uVW5BU3VNv0tjynYe",
            "",
            2000000000000000000,
            40382947566000000000, 
            executors,
            tokenAmounts,
            nftAmounts
        ); 

        tx_.targetData[1] = abi.encodeWithSignature(
            "sendMessage(uint256,bytes)", 
            1,
            abi.encode(message)
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        tx_.values[0] = 0; 
        tx_.values[1] = 100e18; 
        
        _submitManagerCall(manageProofs, tx_); 
    }
}
