/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import "../common/ITBContractDecoderAndSanitizer.sol";
import "./CurveNoConfigDecoderAndSanitizer.sol";
import "./ConvexDecoderAndSanitizer.sol";

contract CurveAndConvexDecoderAndSanitizer is
    ITBContractDecoderAndSanitizer,
    CurveNoConfigDecoderAndSanitizer,
    ConvexDecoderAndSanitizer
{}
