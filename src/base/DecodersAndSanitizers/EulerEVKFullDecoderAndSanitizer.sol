// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract EulerEVKFullDecoderAndSanitizer is BaseDecoderAndSanitizer, EulerEVKDecoderAndSanitizer {}
