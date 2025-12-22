// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {
    UniswapV3DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {
    NativeWrapperDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import { OFTDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import { rFLRDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/rFLRDecoderAndSanitizer.sol";

contract LiquidUSDFlareDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    rFLRDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    { }
}
