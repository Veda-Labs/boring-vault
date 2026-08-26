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

    function swapExactInput(bool, uint256, uint256, address recipient, bytes32 customerId, bytes32, uint256, uint256, uint256, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        _validateCustomerId(customerId);
        addressesFound = abi.encodePacked(recipient);
    }

    function swapExactOutput(bool, uint256, uint256, address recipient, bytes32 customerId, bytes32, uint256, uint256, uint256, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        _validateCustomerId(customerId);
        addressesFound = abi.encodePacked(recipient);
    }

    function _validateCustomerId(bytes32 customerId) internal pure {
        if (customerId != CUSTOMER_ID) revert DirectPropAMMDecoderAndSanitizer__InvalidCustomerId();
    }
}
