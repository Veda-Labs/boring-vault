// SPDX-License-Identifier: UNLICENSED
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
