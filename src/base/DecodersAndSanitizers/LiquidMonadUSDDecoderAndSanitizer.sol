// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";

/**
 * Decoder/sanitizer composite for the liquidMonadUSD sub-vault.
 *
 * Covers the union of leaves used on both the Mainnet (bridging) and Monad (strategy) roots:
 *   - ERC4626       Upshift earnAUSD vault
 *   - Merkl         AUSD / WMON reward claims
 *   - NativeWrapper WMON wrap / unwrap
 *   - OFT           LayerZero AUSD bridge (Mainnet ↔ Monad)
 *   - CCTP          Circle USDC bridge (Mainnet ↔ Monad)  [also inherits BaseDecoderAndSanitizer]
 */
contract LiquidMonadUSDDecoderAndSanitizer is
    ERC4626DecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    CCTPDecoderAndSanitizer
{}
