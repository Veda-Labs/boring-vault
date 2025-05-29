// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SiloDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SiloDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullSiloDecoderAndSanitizer is SiloDecoderAndSanitizer {

}

contract SiloVaultsIntegration is BaseTestIntegration {

    address WBERA_HONEY_lp = 0x2c4a603A2aA5596287A06886862dc29d56DbC354; 

    function _setUpSonic() internal {
        super.setUp(); 
        _setupChain("sonicMainnet", 25048440); 
            
        address siloDecoder = address(new FullSiloDecoderAndSanitizer()); 

        _overrideDecoder(siloDecoder); 
    }


    function testSiloVaultsIntegration() external {
        //set up sonic
        _setUpSonic(); 

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e18); 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addSiloVaultLeafs(leafs, getAddress(sourceChain, "silo_USDC_vault")); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); //approve, deposit
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[0]; //approve asset()
        tx_.manageLeafs[1] = leafs[1]; //deposit()

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        //targets
        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "silo_USDC_vault");
        
        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "silo_USDC_vault"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "deposit(uint256,address)", 100e6, address(boringVault)
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        
        //submit call 
        _submitManagerCall(manageProofs, tx_); 

        //accrue rewards
        skip(1 weeks); 

        tx_ = _getTxArrays(2); //getReward, withdraw
        
        //manage leafs
        tx_.manageLeafs[0] = leafs[5]; //claimReward()
        tx_.manageLeafs[1] = leafs[2]; //withdraw()

        manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        
        //targets
        tx_.targets[0] = getAddress(sourceChain, "silo_USDC_vault"); //approve 
        tx_.targets[1] = getAddress(sourceChain, "silo_USDC_vault");
        
        //targetDatas
        tx_.targetData[0] = abi.encodeWithSignature(
            "claimRewards()" 
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)", 100e6, address(boringVault), address(boringVault)
        );
        
        //decoders
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        

        //submit call 
        _submitManagerCall(manageProofs, tx_); 
    }
}
