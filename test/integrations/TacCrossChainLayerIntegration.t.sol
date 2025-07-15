// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol"; 
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol"; 
import {TacCrossChainLayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TacCrossChainLayerDecoderAndSanitizer.sol"; 
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullTACDecoder is TacCrossChainLayerDecoderAndSanitizer { }

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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);
        
        _addTacCrossChainLeafs(); 
        //TODO
    }

}
