// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {PancakeSwapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/PancakeSwapV3DecoderAndSanitizer.sol"; 
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";


contract GigaBNBDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    PancakeSwapV3DecoderAndSanitizer,
    OneInchDecoderAndSanitizer 
{
    constructor(address _pancakeSwapV3NonFungiblePositionManager, address _pancakeSwapV3MasterChef)
        PancakeSwapV3DecoderAndSanitizer(_pancakeSwapV3NonFungiblePositionManager, _pancakeSwapV3MasterChef)
    {}
}
