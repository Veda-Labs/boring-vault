// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

import "../common/ITBContractDecoderAndSanitizer.sol";

abstract contract AaveDecoderAndSanitizer is ITBContractDecoderAndSanitizer {
    function deposit(address asset, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset);
    }

    function withdrawSupply(address asset, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset);
    }
}
