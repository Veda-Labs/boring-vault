// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {VelodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/VelodromeDecoderAndSanitizer.sol";

contract AerodromeDecoderAndSanitizer is BaseDecoderAndSanitizer, VelodromeDecoderAndSanitizer {
    constructor(address _aerodromeNonFungiblePositionManager)
        VelodromeDecoderAndSanitizer(_aerodromeNonFungiblePositionManager)
    {}
}
