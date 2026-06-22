// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/**
 * @notice Minimal interface for an Aave V4 spoke. Reserves are identified by a per-spoke
 *         sequential uint256 reserveId rather than the underlying asset address.
 */
interface IAaveV4Spoke {
    /// @dev Mirrors the spoke's fully static Reserve struct; `hub` is an interface type and
    ///      `flags` a user-defined uint8 value type onchain, both ABI-equivalent to the below.
    struct Reserve {
        address underlying;
        address hub;
        uint16 assetId;
        uint8 decimals;
        uint24 collateralRisk;
        uint8 flags;
        uint32 dynamicConfigKey;
    }

    function getReserve(uint256 reserveId) external view returns (Reserve memory);

    /// @notice User's supplied balance in underlying assets, including accrued yield. Rounds down
    ///         and is exactly the value Spoke.withdraw clamps to.
    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
}
