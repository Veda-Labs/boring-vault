// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/// @notice Sanitizes the two DirectPropAMM taker entry points.
/// @dev The Merkle leaf binds the returned recipient to the BoringVault. A fixed customer ID keeps
///      each vault's trades on one rounding-credit route.
contract DirectPropAMMDecoderAndSanitizer {
    /// @notice The only customer ID either swap entry point accepts.
    /// @dev Shared across vaults safely. The pool keys credit on
    ///      `keccak256(taker, resolvedRecipient, customerId)` and the taker is the vault running
    ///      `manage`, so each vault still gets its own route.
    bytes32 public constant CUSTOMER_ID = keccak256("VEDA_DIRECT_PROP_AMM");

    error DirectPropAMMDecoderAndSanitizer__InvalidCustomerId();

    // Parameters, in order:
    // - baseToQuote: swap direction; true sells base for quote, false sells quote for base.
    // - amountIn: exact amount of the input token to sell.
    // - minAmountOut: minimum acceptable amount of the output token (slippage floor).
    // - recipient: address credited with the output token; sanitized and bound to the Merkle leaf.
    // - customerId: must equal `CUSTOMER_ID`; validated below.
    // - tradeId: caller-supplied trade identifier, unchecked here.
    // - deadline: unix timestamp after which the swap reverts, unchecked here.
    // - expectedOraclePrice: oracle price the caller expects at execution time, unchecked here.
    // - oraclePriceToleranceBps: allowed deviation from expectedOraclePrice, in bps, unchecked here.
    // - minimumOracleUpdatedAt: oldest acceptable oracle update timestamp, unchecked here.
    function swapExactInput(
        bool /* baseToQuote */,
        uint256 /* amountIn */,
        uint256 /* minAmountOut */,
        address recipient,
        bytes32 customerId,
        bytes32 /* tradeId */,
        uint256 /* deadline */,
        uint256 /* expectedOraclePrice */,
        uint256 /* oraclePriceToleranceBps */,
        uint256 /* minimumOracleUpdatedAt */
    ) external pure virtual returns (bytes memory addressesFound) {
        _validateCustomerId(customerId);
        addressesFound = abi.encodePacked(recipient);
    }

    // Parameters, in order:
    // - baseToQuote: swap direction; true sells base for quote, false sells quote for base.
    // - amountOut: exact amount of the output token to buy.
    // - maxAmountIn: maximum acceptable amount of the input token (slippage ceiling).
    // - recipient: address credited with the output token; sanitized and bound to the Merkle leaf.
    // - customerId: must equal `CUSTOMER_ID`; validated below.
    // - tradeId: caller-supplied trade identifier, unchecked here.
    // - deadline: unix timestamp after which the swap reverts, unchecked here.
    // - expectedOraclePrice: oracle price the caller expects at execution time, unchecked here.
    // - oraclePriceToleranceBps: allowed deviation from expectedOraclePrice, in bps, unchecked here.
    // - minimumOracleUpdatedAt: oldest acceptable oracle update timestamp, unchecked here.
    function swapExactOutput(
        bool /* baseToQuote */,
        uint256 /* amountOut */,
        uint256 /* maxAmountIn */,
        address recipient,
        bytes32 customerId,
        bytes32 /* tradeId */,
        uint256 /* deadline */,
        uint256 /* expectedOraclePrice */,
        uint256 /* oraclePriceToleranceBps */,
        uint256 /* minimumOracleUpdatedAt */
    ) external pure virtual returns (bytes memory addressesFound) {
        _validateCustomerId(customerId);
        addressesFound = abi.encodePacked(recipient);
    }

    function _validateCustomerId(bytes32 customerId) internal pure {
        if (customerId != CUSTOMER_ID) revert DirectPropAMMDecoderAndSanitizer__InvalidCustomerId();
    }
}
