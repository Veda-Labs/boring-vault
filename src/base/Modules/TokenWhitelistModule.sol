// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IModule} from "src/base/Registry/ModuleRegistry.sol"; 
import {TokenRegistry} from "src/base/Registry/TokenRegistry.sol";
import {TokenWhitelistStorageModule} from "src/base/Modules/StorgeModules/TokenWhitelistStorageModule.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract TokenWhitelistModule is IModule {
    
    //could be transient, could just be state variable;  
    //we could also just have a CacheModule that does this and use it only where needed? maybe overkill 
   // address internal cachedStorage; //load this once, reuse across the entire tx, next vault that uses it has to store thier own here

    TokenRegistry public tokenRegistry; 

    constructor(address _tokenRegistry) {
        tokenRegistry = TokenRegistry(_tokenRegistry);
    }

    function checkRule(bytes calldata params) external view returns (bool) {
        //importantly, the storageContract can only come from the vault, a vault wouldn't be able to simply pass in anothers storageContract to get access to their tokens
        //what mechanism is used here to make that happen is undecided at the moment
        //TODO need index here
        (uint256 protocolId, address storageContract, address[] memory tokens) = abi.decode(params, (uint256, address, address[])); 

        for (uint256 i = 0; i < tokens.length; i++) {
            //call the global registry first to check that it is an approved token 
            bool approved = tokenRegistry.isApprovedGlobally(tokens[i]);
            if (!approved) return false;
        } 
       
        uint256 mask = _createMask(tokens); //creates a mask based on the tokens passed in by looking them up in the registry 
        bool inMask = TokenWhitelistStorageModule(storageContract).checkMask(protocolId, mask); //compares the bits against each other
        if (!inMask) revert("ya right ur denied"); 

        return true;
    }

    function _createMask(address[] memory tokens) internal view returns (uint256) {
            
        uint256 tokenMask; 
        for (uint i; i < tokens.length;) {
            
            //get the token bit from the registry
            tokenMask |= tokenRegistry.tokenIds(tokens[i]);

            unchecked {
                ++i; 
            }
        } 

        return tokenMask;
    } 
}
