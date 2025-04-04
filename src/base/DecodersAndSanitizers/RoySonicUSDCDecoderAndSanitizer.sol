// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {BoringChefDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";

contract RoySonicUSDCDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    RoycoWeirollDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    BoringChefDecoderAndSanitizer
{
    constructor(address _recipeMarketHub, address _odosRouter)
        BaseDecoderAndSanitizer()
        RoycoWeirollDecoderAndSanitizer(_recipeMarketHub)
        OdosDecoderAndSanitizer(_odosRouter)
        BoringChefDecoderAndSanitizer()
    {}
}
