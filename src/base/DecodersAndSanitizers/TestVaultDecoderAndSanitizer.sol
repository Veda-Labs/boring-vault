// SPDX-License-Identifier: SEL-1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract TestVaultDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    {}
}
