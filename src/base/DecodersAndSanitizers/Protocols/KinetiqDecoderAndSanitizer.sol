// SPDX-License-Identifier: SEL-1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract KinetiqDecoderAndSanitizer {

    function stake() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function queueWithdrawal(uint256 /*kHYPEAmount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    } 

    function confirmWithdrawal(uint256 /*withdrawalId*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}
