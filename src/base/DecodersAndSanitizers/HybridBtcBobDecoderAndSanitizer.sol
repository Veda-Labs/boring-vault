// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {
    StandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import { EulerEVKDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {
    UniswapV3SwapRouter02DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3SwapRouter02DecoderAndSanitizer.sol";

contract HybridBtcBobDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    UniswapV3SwapRouter02DecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager)
        UniswapV3SwapRouter02DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    { }
}
