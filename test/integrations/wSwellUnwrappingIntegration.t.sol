// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {wSwellUnwrappingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/wSwellUnwrappingDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract FullWSwellUnwrappingDecoderAndSanitier is wSwellUnwrappingDecoderAndSanitizer{}


contract wSwellUwrappingIntegrationTest is BaseTestIntegration {

    function _setUpSwell() internal {
        super.setUp(); 
        _setupChain("swell", 7015846); 
            
        address wswellDecoder = address(new FullWSwellUnwrappingDecoderAndSanitier()); 

        _overrideDecoder(wswellDecoder); 
    }

    function testWSwellIntegration() external {
        _setUpSwell(); 

        deal(getAddress(sourceChain, "WSWELL"), address(boringVault), 100e18);  

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addWSwellUnwrappingLeafs(leafs); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1); 

        tx_.manageLeafs[0] = leafs[0];  //withdrawTo

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WSWELL"); //approve 

        tx_.targetData[0] = abi.encodeWithSignature(
            "withdrawToByLockTimestamp(address,uint256,bool)", 
            address(boringVault),
            1740700800,
            true
        );
        
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 

    }

}
