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
        //check that the spender is a valid target address 
        //check that the vault has the spender protocol enabled
    }
}
