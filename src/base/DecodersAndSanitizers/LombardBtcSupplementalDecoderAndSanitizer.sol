// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";

contract LombardBtcSupplementalDecoderAndSanitizer is UniswapV4DecoderAndSanitizer {
    constructor(address _uniswapV4PositionManager)
        UniswapV4DecoderAndSanitizer(_uniswapV4PositionManager)
    {}
}
