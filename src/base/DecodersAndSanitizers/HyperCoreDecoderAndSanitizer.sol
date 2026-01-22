// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {HyperliquidCoreWriterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/HyperliquidCoreWriterDecoderAndSanitizer.sol";

/**
 * @title HyperCoreDecoderAndSanitizer
 * @notice Decoder and sanitizer for the HyperCore vault on HyperEVM.
 * @dev Combines HyperCore trading capabilities with basic ERC20 operations.
 */
contract HyperCoreDecoderAndSanitizer is
    HyperliquidCoreWriterDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{}
