// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/// @notice Decoder and sanitizer for Upshift's Fractal-style TokenizedVault
///         (e.g. Sentora USD Earn on ETH mainnet: 0x74aD2F789Ed583DBd141bbdafC673fE1F033718b).
/// @dev Depositing requires approving the reference asset to the vault. Requesting a lagged
///      redemption requires approving the vault's LP token to the vault, since the vault pulls
///      LP tokens via transferFrom. Instant redemptions burn LP tokens directly from the caller.
/// @dev Audit status: this contract has not been audited as a whole. However, `deposit` and
///      `requestRedeem` are ABI- and sanitization-identical to the audited
///      `LombardBTCocDecoderAndSanitizer` (Last audited:
///      boring-vault-fixes commit 9ab12106d45f6e3ed0a3924fc49694e2acfad47b — file:audit/0xmacro-veda-92.pdf).
///      `instantRedeem` and `claim` are new selectors that follow the same receiver-only
///      sanitization pattern but have no direct audited equivalent.
contract UpshiftTokenizedVaultDecoderAndSanitizer {
    //============================== Upshift TokenizedVault ===============================

    /// @notice Deposits `amountIn` of `assetIn` into the vault, minting LP tokens to `receiverAddr`.
    /// @dev Sanitizes the deposit asset and receiver.
    /// @dev Audited pattern: identical to `LombardBTCocDecoderAndSanitizer.deposit`
    ///      (audit/0xmacro-veda-92.pdf).
    function deposit(address assetIn, uint256, /*amountIn*/ address receiverAddr)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(assetIn, receiverAddr);
    }

    /// @notice Instantly redeems `shares` LP tokens (burned directly from the caller) for the
    ///         reference asset, sent to `receiverAddr`.
    /// @dev Sanitizes the receiver only.
    /// @dev Not directly audited: new selector, same receiver-only pattern as `requestRedeem`.
    function instantRedeem(uint256, /*shares*/ address receiverAddr)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiverAddr);
    }

    /// @notice Requests a lagged redemption of `shares` LP tokens; the vault pulls LP tokens via
    ///         transferFrom and the claim accrues to `receiverAddr`.
    /// @dev Sanitizes the receiver only.
    /// @dev Audited pattern: identical to `LombardBTCocDecoderAndSanitizer.requestRedeem`
    ///      (audit/0xmacro-veda-92.pdf); only the address param's semantics differ (receiver vs owner).
    function requestRedeem(uint256, /*shares*/ address receiverAddr)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiverAddr);
    }

    /// @notice Claims a settled lagged redemption identified by its (year, month, day) batch,
    ///         sending the reference asset to `receiverAddr`.
    /// @dev Sanitizes the receiver only.
    /// @dev Not directly audited: selector unique to Upshift/Fractal, follows the standard
    ///      receiver-only sanitization pattern.
    function claim(uint256, /*year*/ uint256, /*month*/ uint256, /*day*/ address receiverAddr)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiverAddr);
    }
}
