// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ModuleRegistry, IModule} from "src/base/Registry/ModuleRegistry.sol";

contract ApprovalRulesetDecoder {

    ModuleRegistry internal moduleRegistry; 

    constructor (address _moduleRegistry) {
        moduleRegistry = ModuleRegistry(_moduleRegistry);
    }
    
    function approve(address spender, uint256 /*amount*/) external view virtual returns (bool) {
         
        //things we need here: 
        //1) vault -> msg.sender...? I think this is preserved since it is a delegateCall, will have to double check that
        //2) protocolId we are checking -> can get from spender lookup (target -> protocolConfig from registry)
        //3) token we're checking -> can get from target?
        //--> none of these are in the function signature, maybe we append some calldata?
        //or just have a special case for this where we pass those in as params...?

        //we need to somehow get the address of the vault that is calling this
        //then, we can get the storage contract associated with it
        //
        //after that, we can check the token whitelist for the protocolId and verify that it is an acceptable token
        //after that we can check the spender by verifying is is the correct target address/addresses for that protocolConfig
    }
}
