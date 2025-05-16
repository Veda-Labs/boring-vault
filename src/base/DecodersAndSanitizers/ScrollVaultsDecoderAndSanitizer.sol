// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol"; 
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol"; 
import {ScrollBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ScrollBridgeDecoderAndSanitizer.sol";


contract ScrollVaultsDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    ScrollBridgeDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer
{}


