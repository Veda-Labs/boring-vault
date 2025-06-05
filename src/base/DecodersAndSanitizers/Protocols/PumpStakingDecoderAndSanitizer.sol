// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract PumpStakingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== PUMP STAKING ===============================

    function stake(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function unstakeRequest(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function claimSlot(uint8 /*slot*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function claimAll() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function unstakeInstant(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
