// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {BoringChefDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";

/**
 * @title RoycoUSDDecoderAndSanitizer
 * @notice Decoder and sanitizer for RoycoUSD vault functionality including:
 * - Fee claiming
 * - Teller deposits/withdrawals for main vault
 * - LayerZero bridging to Mainnet
 * - Teller deposits/withdrawals for RoycoPlumeUSDC vault
 * - Royco recipe markets and vault markets
 * - BoringChef rewards claiming and distribution
 * - Odos swapping functionality
 * - ERC20 approvals
 */
contract RoycoUSDDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    RoycoWeirollDecoderAndSanitizer,
    BoringChefDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    OFTDecoderAndSanitizer
{
    constructor(address _recipeMarketHub)
        BaseDecoderAndSanitizer()
        RoycoWeirollDecoderAndSanitizer(_recipeMarketHub)
        BoringChefDecoderAndSanitizer()
        TellerDecoderAndSanitizer()
        OFTDecoderAndSanitizer()
    {}
}