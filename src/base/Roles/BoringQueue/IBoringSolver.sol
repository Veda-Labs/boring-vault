// SPDX-License-Identifier: SEL-1.0
// Last audited: boring-vault@ec74b24330a1d7b144dc397c1c20c76e3d6fc460 — https://macroaudits.com/library/audits/sevenSeas-18
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

interface IBoringSolver {
    function boringSolve(
        address initiator,
        address boringVault,
        address solveAsset,
        uint256 totalShares,
        uint256 requiredAssets,
        bytes calldata solveData
    ) external;
}
