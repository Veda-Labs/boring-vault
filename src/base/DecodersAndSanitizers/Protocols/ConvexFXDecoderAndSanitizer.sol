// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {IPoolRegistry} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";  

abstract contract ConvexFXDecoderAndSanitizer is BaseDecoderAndSanitizer {

    //============================== Immutables ================================
    
    IPoolRegistry internal immutable poolRegistry; 
        
    //============================== Constructor ===============================
    
    constructor(address _poolRegistry) {
        poolRegistry = IPoolRegistry(_poolRegistry); 
    }

    //============================== F(X) Booster ===============================
    
    function createVault(uint256 _pid) external view virtual returns (bytes memory addressesFound) {
        // stakingAddress and stakingToken are both available on the FE and should be enough to verify we're whitelisting the correct PID
        (/*implementation*/, address stakingAddress, address stakingToken, /*rewardsAddress*/, /*active*/) = poolRegistry.poolInfo(_pid);         
        
        addressesFound = abi.encodePacked(stakingAddress, stakingToken); 
    } 


    //============================== F(X) Staking Proxy ===============================
   
    // @dev can use 'false' to achieve same result from using `deposit(uint256)` 
    function deposit(uint256 /*_amount*/, bool /*manage*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }
    
    function withdraw(uint256 /*_amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function getReward(bool /*claim*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }
    
    // @dev not sanitizing reward addresses for flexibility, all claimed tokens are transfered to vault here. For recovery if (any) tokens are sent to vault instead of claimed. 
    function transferTokens(address[] calldata /*_tokenList*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }



}
