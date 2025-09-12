// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract MFOneDecoderAndSanitizer {

    function depositInstant(address tokenIn, uint256 /*amountToken*/, uint256 /*minReceiveAmount*/, bytes32 referrerId) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(
            tokenIn, 
            address(bytes20(bytes16(referrerId))),
            address(bytes20(bytes16(referrerId << 128)))
        ); 
    }

    function depositRequest(address tokenIn, uint256 /*amountToken*/, bytes32 referrerId) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(
            tokenIn, 
            address(bytes20(bytes16(referrerId))),
            address(bytes20(bytes16(referrerId << 128)))
        ); 
    }

    function redeemInstant(address tokenOut, uint256 /*amountMTokenIn*/, uint256 /*minReceiveAmount*/) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenOut); 
    }

    //redeemRequest
    function redeemRequest(address tokenOut, uint256 /*amountMTokenIn*/) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenOut); 
    }
    
    function redeemFiatRequest(uint256 /*amountMTokenIn*/) external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}
