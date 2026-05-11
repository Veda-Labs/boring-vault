// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract BTCKDecoderAndSanitizer {

    //on LBTC
    function deposit(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function mint(bytes calldata payload, bytes calldata /*proof*/) external pure virtual returns (bytes memory addressesFound) {
        (,,,,, bytes memory msgBody) =
            abi.decode(payload[4:], (bytes32, uint256, bytes32, address, address, bytes));
        bytes32 recipientWord;
        assembly {
            recipientWord := mload(add(msgBody, 0x44))
        }
        addressesFound = abi.encodePacked(address(uint160(uint256(recipientWord))));
    }
    
    //on LBTC
    function redeem(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    //on BTCK
    function mintV1(bytes calldata payload, bytes calldata /*proof*/) external pure virtual returns (bytes memory addressesFound) {
        (, address receiver) = abi.decode(payload[4:], (uint256, address));
        addressesFound = abi.encodePacked(receiver);
    }
}
