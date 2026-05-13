// SPDX-License-Identifier: SEL-1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {UniswapV3SwapRouter02DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3SwapRouter02DecoderAndSanitizer.sol";
import {GlueXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GlueXDecoderAndSanitizer.sol";
import {RedSnwapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RedSnwapperDecoderAndSanitizer.sol";

contract WhopDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    UniswapV3SwapRouter02DecoderAndSanitizer,
    GlueXDecoderAndSanitizer,
    RedSnwapperDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager)
        UniswapV3SwapRouter02DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    {}
}
