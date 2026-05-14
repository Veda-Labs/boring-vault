// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "./Protocols/ERC4626DecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "./Protocols/SyrupDecoderAndSanitizer.sol";
import {MagpieDecoderAndSanitizer} from "./MagpieDecoderAndSanitizer.sol";
import {RoycoDawnDecoderAndSanitizer} from "./Protocols/RoycoDawnDecoderAndSanitizer.sol";

contract RoycoJrUsdcDecoderAndSanitizer is
    ERC4626DecoderAndSanitizer,
    SyrupDecoderAndSanitizer,
    RoycoDawnDecoderAndSanitizer,
    MagpieDecoderAndSanitizer
{
    constructor(address _magpieRouter) MagpieDecoderAndSanitizer(_magpieRouter) {}
}
