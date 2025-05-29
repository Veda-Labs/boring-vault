// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {OogaBoogaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OogaBoogaDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol";
import {BeraborrowDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraborrowDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {KodiakIslandDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol";

contract LiquidBeraDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    RoycoWeirollDecoderAndSanitizer,
    OogaBoogaDecoderAndSanitizer,
    InfraredDecoderAndSanitizer,
    BeraborrowDecoderAndSanitizer,
    KodiakIslandDecoderAndSanitizer
{
    constructor(address _recipeMarketHub) 
        RoycoWeirollDecoderAndSanitizer(_recipeMarketHub)
    {}

}
