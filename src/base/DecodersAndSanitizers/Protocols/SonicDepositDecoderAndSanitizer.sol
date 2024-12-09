// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract SonicDepositDecoderAndSanitizer is BaseDecoderAndSanitizer {
    
    constructor (address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}

    function depositBudget(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;         
    }
}
