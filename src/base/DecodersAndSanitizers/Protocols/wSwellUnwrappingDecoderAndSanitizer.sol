// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract wSwellUnwrappingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ETHERFI ===============================

    function withdrawToByLockTimestamp(address account, uint256 /*lockTimestamp*/, bool /*allowRemainderLoss*/) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(account); 
    }

    function withdrawToByLockTimestamps(address account, uint256[] memory /*lockTimetamp*/, bool /*allowRemainderLoss*/) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(account); 
    }
}
