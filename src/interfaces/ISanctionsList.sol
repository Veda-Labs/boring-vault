// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

// Interface for the Chainalysis SanctionsList contract.
// https://go.chainalysis.com/chainalysis-oracle-docs.html
interface ISanctionsList {
    function isSanctioned(address addr) external view returns (bool);
}