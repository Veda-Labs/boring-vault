// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract SwellDecoderAndSanitizer {
    //============================== SWELL ===============================

    // Call swETH
    function deposit() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Call swEXIT 0x48C11b86807627AF70a34662D4865cF854251663
    function createWithdrawRequest(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Call swEXIT 0x48C11b86807627AF70a34662D4865cF854251663
    function finalizeWithdrawal(uint256 /*tokenId*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
