// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {
    BoringChefDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {
    AtomicQueueDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/AtomicQueueDecoderAndSanitizer.sol";

/**
 * @title RoycoUSDPlumeDecoderAndSanitizer
 * @notice Decoder and sanitizer for RoycoUSDPlume vault functionality including:
 * - Fee claiming for multiple Plume tokens (pUSD, nINSTO, nCREDIT, opNALPHA)
 * - Teller deposits/withdrawals for multiple Plume tokens
 * - Royco recipe markets with pUSD and PLUME token incentives
 * - BoringChef rewards claiming and distribution
 */
contract RoycoUSDPlumeDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    RoycoWeirollDecoderAndSanitizer,
    BoringChefDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    AtomicQueueDecoderAndSanitizer
{
    constructor(address _recipeMarketHub)
        RoycoWeirollDecoderAndSanitizer(_recipeMarketHub)
        BoringChefDecoderAndSanitizer()
        TellerDecoderAndSanitizer()
        AtomicQueueDecoderAndSanitizer(0.9e4, 1.1e4)
    {}
}

