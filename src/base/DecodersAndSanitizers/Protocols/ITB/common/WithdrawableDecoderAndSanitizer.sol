// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

/// @title Decoder and sanitizer for Withdrawable
/// @author IntoTheBlock Corp
abstract contract WithdrawableDecoderAndSanitizer {
    function withdraw(address, /*_asset_address*/ uint256) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdrawAll(address /*_asset_address*/ ) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
