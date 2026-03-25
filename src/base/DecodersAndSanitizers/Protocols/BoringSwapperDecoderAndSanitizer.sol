// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";


contract BoringSwapperDecoder is BaseDecoderAndSanitizer {

    function swap(DecoderCustomTypes.SwapConfig memory swapConfig) external pure returns (bytes memory addressesFound) {
        return abi.encodePacked(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut, address(swapConfig.receiver));
    }

    function submitOrder(DecoderCustomTypes.SwapConfig memory swapConfig) external pure returns (bytes memory addressesFound) {
        return abi.encodePacked(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut, address(swapConfig.receiver));
    }
}
