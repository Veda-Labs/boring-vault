// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";

contract GenericUniswapDecoderAndSanitizer is UniswapV4DecoderAndSanitizer, UniswapV3DecoderAndSanitizer {
    constructor(address _posm, address _v3posm)
        UniswapV4DecoderAndSanitizer(_posm)
        UniswapV3DecoderAndSanitizer(_v3posm)
    {}
}
