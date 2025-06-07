// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract SyrupDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== SYRUP ===============================

    // Call to SyrupRouter, instantly deposits
    function deposit(
        uint256 /*amount*/,
        bytes32 /*depositData_*/ // "0:itb" for into the block or "0:okx" for okx, only used for event
    ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    // Call to Maple Pool (syrupUSDC and syrupUSDT), queues shares for withdrawal (must be processed)
    function requestRedeem(
        uint256 /*shares_*/,
        address owner_
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(owner_);
    }

    // Call to Maple Pool (syrupUSDC and syrupUSDT), cancels redemption requests and returns shares
    function removeShares(
        uint256 /*shares_*/,
        address owner_
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(owner_);
    }
}