// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";

contract SentoraBTCMainnetDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    CCTPDecoderAndSanitizer, 
    UniswapV3DecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager)
    UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    {}
}