// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DolomiteDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DolomiteDecoderAndSanitizer.sol";
import {KodiakIslandDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol";
import {HoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HoneyDecoderAndSanitizer.sol";
import {BeraETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraETHDecoderAndSanitizer.sol";

contract BerachainTestBeraETHDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    DolomiteDecoderAndSanitizer,
    KodiakIslandDecoderAndSanitizer,
    InfraredDecoderAndSanitizer,
    HoneyDecoderAndSanitizer,
    BeraETHDecoderAndSanitizer
{}
