// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullTellerDecoderAndSanitizer is 
    TellerDecoderAndSanitizer
{

}

contract CrossChainTellerIntegration is BaseTestIntegration {

    function _setUpMainnet() internal {
        super.setUp(); 
        _setupChain("mainnet", 22238421); 
            
        address tellerDecoder = address(new FullTellerDecoderAndSanitizer()); 

        _overrideDecoder(tellerDecoder);     
    }

    function testCrossChainDepositAndBridgePayETH() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "LBTC"), address(boringVault), 1e8); 
        deal(address(boringVault), 10e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        
        address[] memory depositAssets = new address[](3); 
        depositAssets[0] = getAddress(sourceChain, "LBTC"); 
        depositAssets[1] = getAddress(sourceChain, "WBTC"); 
        depositAssets[2] = getAddress(sourceChain, "cbBTC"); 

        address[] memory feeAssets = new address[](1); 
        feeAssets[0] = getAddress(sourceChain, "ETH"); 

        _addCrossChainTellerLeafs(
            leafs, 
            getAddress(sourceChain, "eBTCTeller"),
            depositAssets,
            feeAssets
        ); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //generate test json 
        _generateTestLeafs(leafs, manageTree); 

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        
        Tx memory tx_ = _getTxArrays(3); 

        tx_.manageLeafs[0] = leafs[0]; //approve eBTC
        tx_.manageLeafs[1] = leafs[1]; //approve LBTC
        tx_.manageLeafs[2] = leafs[4]; //depositAndBridge w/ ETH as fee

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        //targets
        tx_.targets[0] = getAddress(sourceChain, "EBTC"); //approve eBTC to be spent by teller
        tx_.targets[1] = getAddress(sourceChain, "LBTC"); //approve LBTC to be spent by boringVault (deposit) 
        tx_.targets[2] = getAddress(sourceChain, "eBTCTeller"); //bridge shares (eBTC)
       

        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "eBTCTeller"), type(uint256).max); 
        tx_.targetData[1] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "eBTC"), type(uint256).max); 
        tx_.targetData[2] = abi.encodeWithSignature(
            "depositAndBridge(address,uint256,uint256,address,bytes,address,uint256)",
            getAddress(sourceChain, "LBTC"), 
            0.25e8,
            0,
            address(boringVault),
            abi.encode(layerZeroBaseEndpointId),
            getAddress(sourceChain, "ETH"),
            1e18          
        ); 
        
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[2] = rawDataDecoderAndSanitizer; 

        tx_.values[0] = 0; 
        tx_.values[1] = 0; 
        tx_.values[2] = 30819757242215; 
        
        _submitManagerCall(manageProofs, tx_); 

    }
}
