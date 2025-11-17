// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IModule} from "src/base/Registry/ModuleRegistry.sol"; 

contract RecipientModule is IModule {

    //encodes the rules for checking if the recipient address is the boring vault
    function checkRule(bytes calldata params) external view returns (bool) {
        // here, all we would do is decode the params into an address type, and then verify that it comes from the boring vault
        // to do this, we could pass it in as a param to here or check msg.sender 
        (address caller, address vault) = abi.decode(params, (address, address)); 
        if (caller != vault) return false; 
        
        return true; 
    } 
}
