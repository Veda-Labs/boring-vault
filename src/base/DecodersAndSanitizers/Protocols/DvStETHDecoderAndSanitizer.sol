// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {IDvStETHVault} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol"; 


abstract contract DvStETHDecoderAndSanitizer is BaseDecoderAndSanitizer {
        
    error DvStETHDecoderAndSanitizer__OnlyOneAmount(); 

    address immutable dvStETHVault; 
    
    constructor(address _dvStETHVault) {
        dvStETHVault = _dvStETHVault; 
    }

    function deposit(
        address to,
        uint256[] memory amounts,
        uint256 /*minLpAmount*/,
        uint256 /*deadline*/,
        uint256 /*referralCode*/
    ) external view virtual returns (bytes memory addressesFound) {
        bool nonZero = false; 
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0) continue; 
            if (nonZero == true) revert DvStETHDecoderAndSanitizer__OnlyOneAmount(); 
            nonZero = true; 

            address[] memory tokens = IDvStETHVault(dvStETHVault).underlyingTokens(); 
            addressesFound = abi.encodePacked(addressesFound, tokens[i]); 
        } 

        addressesFound = abi.encodePacked(addressesFound, to); 
    }

    function registerWithdrawal(
        address to,
        uint256 /*lpAmount*/,
        uint256[] memory /*minAmounts*/,
        uint256 /*deadline*/,
        uint256 /*requestDeadline*/,
        bool /*closePrevious*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to); 
    }

    function cancelWithdrawalRequest() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function emergencyWithdraw(uint256[] memory /*minAmounts*/, uint256 /*deadline*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}

