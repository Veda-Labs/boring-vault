// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IModule} from "src/base/Registry/ModuleRegistry.sol"; 

////these are deployed per vault on a "need" basis, they are opt in -> this is handled via factory (adds overhead, but pay it once) 
////the overhead here becomes managing each of these per vault, and dealing with each of them individually. You could imagine having to deal with different function signatures per storage contract being annoying (updateMask in one, updateList in another, updateTokenPairMask in another, etc). These would be limited per protocol, so conceptually it might make sense, but still, that is where the overhead comes in. Via a UI, this may be acceptable.
//if handled via a registry w/ a centralized api, this may also work. IE, all storage modules have an update, add, remove function w/ the same function signature. This reduces overhead when updating and thinking about which paramaters need to be passed where, etc. 
//
//
//
//The other way to handle this would be from a singleton contact that keeps track of each vaults token whitelists. Reduces some deployment overhead, able to reuse per vault. Adds some complexity and adds risk of "cross-contamination" lol, ie, updating the mask for the wrong vault.
//This also makes it more complicated to auth. Which admins can update which vault whitelists? etc. Need to keep track of that somewhere. List? Mapping? Another thing to keep track of.
//
//maybe other ways to do this as well...? these are the only two I can think of rn.
contract TokenWhitelistStorageModule {

    //reuse the protocol bit from the master registry as the id
    //register tokens PER protocol -> works for 95% of cases (approvals included naturally)
    mapping(uint256 protocolId => uint256 tokenMask) public tokenMasks; 
        
    //keep track of which vault this belongs to
    address internal immutable boringVault; 

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    function checkMask(uint256 protocolId, uint256 tokenMask) external view returns (bool) {
        return (tokenMasks[protocolId] & tokenMask) == tokenMask; 
    } 
    
    //overwrites the mask with a new one 
    function updateEntireMask(uint256 protocolId, uint256 tokenMask) external {
        tokenMasks[protocolId] = tokenMask; 
    } 
    
    //adds a single token to the whitelist 
    function addTokens(uint256 protocolId, uint256 tokenBits) external {
        tokenMasks[protocolId] |= tokenBits;
    } 
    
    //removes a single token from the whitelist
    function removeTokens(uint256 protocolId, uint256 tokenBits) external {
        tokenMasks[protocolId] &= ~tokenBits;
    }
}
