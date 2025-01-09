// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {BalancerV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";

contract StakedSonicUSDDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    TellerDecoderAndSanitizer
{
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}
}
