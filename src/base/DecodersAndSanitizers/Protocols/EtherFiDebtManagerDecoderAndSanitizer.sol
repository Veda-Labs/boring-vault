// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

contract EtherFiDebtManagerDecoderAndSanitizer {
    //============================== ETHERFI DEBT MANAGER ===============================

    function supply(address user, address borrowToken, uint256 amount) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(user, borrowToken);
    }

    function withdrawBorrowToken(address borrowToken, uint256 amount) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(borrowToken);
    }
}
