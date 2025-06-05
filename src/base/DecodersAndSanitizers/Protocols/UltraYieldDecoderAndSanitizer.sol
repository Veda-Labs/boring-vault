// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";


abstract contract UltraYieldDecoderAndSanitizer is BaseDecoderAndSanitizer, ERC4626DecoderAndSanitizer {
    function requestRedeem(uint256 /*shares*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function deposit(uint256 /*assets*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function mint(uint256 /*shares*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdraw(uint256 /*assets*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeem(uint256 /*shares*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
