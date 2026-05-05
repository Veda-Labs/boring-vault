// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "./Protocols/ERC4626DecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "./Protocols/SyrupDecoderAndSanitizer.sol";

contract RoycoJrUsdcDecoderAndSanitizer is ERC4626DecoderAndSanitizer, SyrupDecoderAndSanitizer {}
