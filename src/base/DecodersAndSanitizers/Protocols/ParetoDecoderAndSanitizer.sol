// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract ParetoDecoderAndSanitizer is BaseDecoderAndSanitizer {

    function depositAA(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function depositBB(uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function depositDuringEpoch(uint256 /*amount*/, address tranche) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(tranche);
    }

    function requestWithdraw(uint256 /*amount*/, address tranche) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(tranche);
    }

    function claimWithdrawRequest() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function claimInstantWithdrawRequest() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
