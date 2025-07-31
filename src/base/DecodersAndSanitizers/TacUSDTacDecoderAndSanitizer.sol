// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {TacCrossChainLayerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TacCrossChainLayerDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";

contract TacDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    TacCrossChainLayerDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    CurveDecoderAndSanitizer
{

    function deposit(uint256, address receiver) external pure virtual override(CurveDecoderAndSanitizer, ERC4626DecoderAndSanitizer) returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }
}
