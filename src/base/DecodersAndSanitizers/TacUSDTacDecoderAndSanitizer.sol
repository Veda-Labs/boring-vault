// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {TacCrossChainLayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TacCrossChainLayerDecoderAndSanitizer.sol";

contract TacDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    TacCrossChainLayerDecoderAndSanitizer
{}
