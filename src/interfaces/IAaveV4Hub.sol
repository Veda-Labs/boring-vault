// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/**
 * @notice Minimal interface for an Aave V4 liquidity hub. Hubs hold the funds for one or more
 *         spokes; users never call hubs directly.
 */
interface IAaveV4Hub {
    struct SpokeConfig {
        uint40 addCap;
        uint40 drawCap;
        uint24 riskPremiumThreshold;
        bool active;
        bool halted;
    }

    /// @notice The amount of liquidity currently available for withdrawals/borrows of an asset.
    /// @dev Internal accounting that nets out borrows and reinvestment sweeps; Hub.remove reverts
    ///      above this value regardless of the hub's ERC20 balance, so this (not balanceOf) is the
    ///      correct withdrawability bound.
    function getAssetLiquidity(uint256 assetId) external view returns (uint256);

    function getSpokeConfig(uint256 assetId, address spoke) external view returns (SpokeConfig memory);
}
