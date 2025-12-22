// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {
    UniswapV3DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import { ERC4626DecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import { OneInchDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import { OdosDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {
    NativeWrapperDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import { LidoDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import { OFTDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";

contract TacETHDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    OFTDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager, address _odosRouter)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
    { }
}
