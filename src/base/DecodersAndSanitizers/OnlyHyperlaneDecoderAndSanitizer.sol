// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {HyperlaneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HyperlaneDecoderAndSanitizer.sol";

contract OnlyHyperlaneDecoderAndSanitizer is HyperlaneDecoderAndSanitizer, BaseDecoderAndSanitizer {}
