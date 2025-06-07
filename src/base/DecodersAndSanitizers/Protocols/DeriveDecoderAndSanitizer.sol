// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

/// @notice provides a full flow for borings vaults to use and claim rewards from Derive (Basis) Vaults
abstract contract DeriveDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ERRORS ===============================
    
    error DeriveDecoderAndSanitizer__OptionsLengthNonZero();  
    
    
    //============================== Deposits/Withdraws ===============================
    
    function bridge(
        address receiver_,
        uint256 /*amount_*/,
        uint256 /*msgGasLimit_*/,
        address connector_,
        bytes calldata extraData_,
        bytes calldata options_
    ) external pure virtual returns (bytes memory addressesFound) {
        if (options_.length > 0) revert DeriveDecoderAndSanitizer__OptionsLengthNonZero(); 
        (address user, address connectorPlugOnDeriveChain) = abi.decode(extraData_, (address, address)); 
        addressesFound = abi.encodePacked(receiver_, connector_, user, connectorPlugOnDeriveChain);  
    }

    function retry(
        address connector_,
        bytes32 /*messageId_*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(connector_); 
    }

    //============================== Rewards ===============================
    
    function claimAll() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    } 

    //============================== stDRV ===============================
   
    function redeem(uint256 /*stDeriveAmount*/, uint256 /*duration*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    } 

    function finalizeRedeem(uint256 /*redeemIndex*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function cancelRedeem(uint256 /*redeemIndex*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}
