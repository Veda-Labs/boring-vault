// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

/// @title Decoder and sanitizer for Executable
/// @author IntoTheBlock Corp
abstract contract ExecutableDecoderAndSanitizer {
    function removeExecutor(address /*_executor*/ ) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
