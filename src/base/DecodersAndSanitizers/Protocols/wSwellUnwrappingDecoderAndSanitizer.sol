// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract wSwellUnwrappingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== ETHERFI ===============================

    function withdrawToByLockTimestamp(address account, uint256 /*lockTimetamp*/, bool /*allowRemainderLoss*/) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(account); 
    }

    function withdrawToByLockTimestamps(address account, uint256[] memory /*lockTimetamp*/, bool /*allowRemainderLoss*/) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(account); 
    }
}
