// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {WormholeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/WormholeDecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";

/**
 * Decoder/sanitizer composite for the liquidMonadETH sub-vault.
 *
 * Covers the union of leaves used on both the Mainnet (bridging) and Monad (strategy) roots:
 *   - ERC4626       Steakhouse Prime ETH Morpho vault
 *   - MorphoBlue    wstETH / WETH market
 *   - Merkl         WMON reward claims
 *   - NativeWrapper WMON wrap / unwrap
 *   - UniswapV4     MON / WETH swaps
 *   - Wormhole      NTT MultiToken Executor WETH bridge (Mainnet ↔ Monad)
 *   - CCIP          Chainlink wstETH bridge (Mainnet ↔ Monad)
 */
contract LiquidMonadETHDecoderAndSanitizer is
    ERC4626DecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    UniswapV4DecoderAndSanitizer,
    WormholeDecoderAndSanitizer,
    CCIPDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{
    constructor(address _uniswapV4PositionManager) UniswapV4DecoderAndSanitizer(_uniswapV4PositionManager) {}
}
