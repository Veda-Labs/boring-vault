// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {SonicGatewayDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SonicGatewayDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {BoringChefDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BoringChefDecoderAndSanitizer.sol";

contract RoyUSDCMainnetDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    SonicGatewayDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    BoringChefDecoderAndSanitizer
{
    constructor(address _odosRouter) OdosDecoderAndSanitizer(_odosRouter){}
}
