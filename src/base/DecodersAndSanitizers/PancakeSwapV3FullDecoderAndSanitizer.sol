// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {
    PancakeSwapV3DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/PancakeSwapV3DecoderAndSanitizer.sol";

contract PancakeSwapV3FullDecoderAndSanitizer is PancakeSwapV3DecoderAndSanitizer, BaseDecoderAndSanitizer {
    constructor(address _pancakeSwapV3NonFungiblePositionManager, address _pancakeSwapV3MasterChef)
        PancakeSwapV3DecoderAndSanitizer(_pancakeSwapV3NonFungiblePositionManager, _pancakeSwapV3MasterChef)
    { }
}
