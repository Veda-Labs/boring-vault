// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
pragma solidity ^0.8.0;

contract ITBAaveDecoderAndSanitizer {
    function deposit(address asset, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset);
    }

    function withdrawSupply(address asset, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset);
    }
}
