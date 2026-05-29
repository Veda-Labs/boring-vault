// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {MPortalDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MPortalDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {UniswapV3SwapRouter02DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3SwapRouter02DecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";

contract VmUSDDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    CCTPDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    MPortalDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    UniswapV3SwapRouter02DecoderAndSanitizer,
    UniswapV4DecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager, address _uniswapV4PositionManager)
        UniswapV3SwapRouter02DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        UniswapV4DecoderAndSanitizer(_uniswapV4PositionManager)
    {}
}
