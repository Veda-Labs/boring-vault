// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {SonicGatewayDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SonicGatewayDecoderAndSanitizer.sol"; 

contract SonicUSDDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    SonicGatewayDecoderAndSanitizer
{
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}
}
