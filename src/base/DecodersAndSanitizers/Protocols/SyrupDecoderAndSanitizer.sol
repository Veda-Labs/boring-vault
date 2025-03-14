// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract SyrupDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== SYRUP ===============================

    // Call to SyrupRouter, instantly deposits
    function deposit(
        uint256 /*amount*/,
        bytes32 /*depositData_*/ // "0:itb" for into the block or "0:okx" for okx, only used for event
    ) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        return addressesFound;
    }

    // Call to Maple Pool (syrupUSDC and syrupUSDT), queues shares for withdrawal (must be processed)
    function requestRedeem(
        uint256 /*shares_*/,
        address owner_
    ) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(owner_);
    }

    // Call to Maple Pool (syrupUSDC and syrupUSDT), cancels redemption requests and returns shares
    function removeShares(
        uint256 /*shares_*/,
        address owner_
    ) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize
        // Return addresses found
        addressesFound = abi.encodePacked(owner_);
    }
}