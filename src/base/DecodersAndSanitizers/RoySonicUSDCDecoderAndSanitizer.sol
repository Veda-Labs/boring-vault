// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
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
