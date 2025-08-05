// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {OogaBoogaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OogaBoogaDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol";

contract LiquidBeraEthBerachainDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    RoycoWeirollDecoderAndSanitizer,
    OogaBoogaDecoderAndSanitizer,
    InfraredDecoderAndSanitizer
{
    constructor(address _recipeMarketHub) RoycoWeirollDecoderAndSanitizer(_recipeMarketHub) {}
}
