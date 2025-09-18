// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {FluidRewardsClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidRewardsClaimingDecoderAndSanitizer.sol";
import {UniswapV3SwapRouter02DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3SwapRouter02DecoderAndSanitizer.sol";

contract LiquidETHPlasmaDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    UniswapV3SwapRouter02DecoderAndSanitizer,
    FluidFTokenDecoderAndSanitizer,
    FluidDexDecoderAndSanitizer,
    FluidRewardsClaimingDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager)
        UniswapV3SwapRouter02DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    {}
}
