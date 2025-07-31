// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol"; 
import {rFLRDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/rFLRDecoderAndSanitizer.sol"; 


contract LiquidUSDFlareDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    rFLRDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    {}
}
