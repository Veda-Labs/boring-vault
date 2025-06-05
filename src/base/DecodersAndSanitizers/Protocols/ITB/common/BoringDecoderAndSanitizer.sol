// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

contract BoringDecoderAndSanitizer {
    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault contract address.
     */
    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    function approve(address spender, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }
}
