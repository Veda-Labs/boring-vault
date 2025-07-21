// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 
import {KinetiqDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KinetiqDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullKinetiqDecoderAndSanitizer is KinetiqDecoderAndSanitizer, BaseDecoderAndSanitizer { }

contract KinetiqIntegration is BaseTestIntegration {
        
    function _setUpHyperEVM() internal {
        super.setUp(); 
        _setupChain("hyperEVM", 8668511); 
            
        address kinetiqDecoder = address(new FullKinetiqDecoderAndSanitizer()); 

        _overrideDecoder(kinetiqDecoder); 
    }

    function testHyperEVM() external {
        _setUpHyperEVM(); 
        
        //starting with just the base assets 
        deal(address(boringVault), 100e18); 
        deal(getAddress(sourceChain, "kHypeStakingManager"), 10000000e18); 


        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // ==== kHYPE ====
        _addKHypeLeafs(leafs); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[1]; //stake

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    
        //targets
        tx_.targets[0] = getAddress(sourceChain, "kHypeStakingManager"); //stake

        tx_.targetData[0] = abi.encodeWithSignature("stake()");

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        tx_.values[0] = 5e18; 
        
        _submitManagerCall(manageProofs, tx_); 
        
        uint256 kHypeBalance = getERC20(sourceChain, "KHYPE").balanceOf(address(boringVault)); 
        console.log("KHYPE BALANCE: ", kHypeBalance);  
    
        //skip 1 day before we can initiate a withdraw
        skip(1 days); 
        
       //now we queue the withdraw 
        tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve() kHYPE
        tx_.manageLeafs[1] = leafs[2]; //queueWithdrawal()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "KHYPE"); //approve island to be spent by infrared vault
        tx_.targets[1] = getAddress(sourceChain, "kHypeStakingManager");  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "kHypeStakingManager"), type(uint256).max 
        ); 
        tx_.targetData[1] = abi.encodeWithSignature(
            "queueWithdrawal(uint256)", kHypeBalance
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        //skip 1 week + some so we can bridge  
        skip(8 days);         

        tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[3]; //confirmWithdrawal()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        tx_.targets[0] = getAddress(sourceChain, "kHypeStakingManager"); 

        tx_.targetData[0] = abi.encodeWithSignature(
            "confirmWithdrawal(uint256)", 0
        ); 

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer; 

        _submitManagerCall(manageProofs, tx_); 
        
        kHypeBalance = getERC20(sourceChain, "KHYPE").balanceOf(address(boringVault)); 
        console.log("KHYPE BALANCE: ", kHypeBalance);  
        assertEq(kHypeBalance, 0); 

        console.log("HYPE BALANCE: ", address(boringVault).balance);  
        assertGt(address(boringVault).balance, 99e18); //we start with 100, so we ensure that we get at least 99 back for fees 
    }
}
