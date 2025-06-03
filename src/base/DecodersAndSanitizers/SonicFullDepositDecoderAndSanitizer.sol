// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {SonicDepositDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SonicDepositDecoderAndSanitizer.sol";

contract SonicFullDepositDecoderAndSanitizer is SonicDepositDecoderAndSanitizer, BaseDecoderAndSanitizer {}
