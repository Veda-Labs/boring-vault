// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract rFLRDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== rFLR ===============================
    function claimRewards(uint256[] calldata, /*_projectIds*/ uint256 /*_month*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdraw(uint128, /*_amount*/ bool /*_wrap*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdrawAll(bool /*_wrap*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
