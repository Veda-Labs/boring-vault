// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

/**
 * @title FluidDecoderAndSanitizer
 * @notice Decoder and sanitizer for Fluid DEX swap operations
 * @dev Each function extracts and returns address arguments that need to be verified in the Merkle tree
 *
 * Token Sanitization Approach:
 * - The pool address itself (target) contains immutable TOKEN_0 and TOKEN_1
 * - By whitelisting the pool address in the Merkle tree, we approve the specific token pair
 * - We only need to sanitize the `to_` recipient address parameter
 * - The swap direction (swap0to1_) is just a boolean and doesn't need sanitization
 */
contract FluidDecoderAndSanitizer is BaseDecoderAndSanitizer {

    /**
     * @notice Decode and sanitize swapIn function call
     * @dev Extracts the recipient address from swap parameters
     * @param swap0to1_ Swap direction (not sanitized - just a boolean)
     * @param amountIn_ Amount of input tokens (not sanitized - just a uint256)
     * @param amountOutMin_ Minimum output amount (not sanitized - slippage protection)
     * @param to_ Recipient address - THIS IS SANITIZED
     * @return addressesFound Packed bytes containing the recipient address
     */
    function swapIn(
        bool swap0to1_,
        uint256 amountIn_,
        uint256 amountOutMin_,
        address to_
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to_);
        return addressesFound;
    }

    /**
     * @notice Decode and sanitize swapOut function call
     * @dev Extracts the recipient address from swap parameters
     * @param swap0to1_ Swap direction (not sanitized - just a boolean)
     * @param amountOut_ Amount of output tokens desired (not sanitized - just a uint256)
     * @param amountInMax_ Maximum input amount (not sanitized - slippage protection)
     * @param to_ Recipient address - THIS IS SANITIZED
     * @return addressesFound Packed bytes containing the recipient address
     */
    function swapOut(
        bool swap0to1_,
        uint256 amountOut_,
        uint256 amountInMax_,
        address to_
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to_);
        return addressesFound;
    }
}
