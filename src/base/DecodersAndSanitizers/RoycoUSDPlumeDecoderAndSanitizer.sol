// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {BoringChefDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";

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
    TellerDecoderAndSanitizer
{
    constructor(address _recipeMarketHub)
        BaseDecoderAndSanitizer()
        RoycoWeirollDecoderAndSanitizer(_recipeMarketHub)
        BoringChefDecoderAndSanitizer()
        TellerDecoderAndSanitizer()
    {}
}