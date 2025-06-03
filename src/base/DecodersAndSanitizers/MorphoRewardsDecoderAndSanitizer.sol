// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {MorphoRewardsWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsWrapperDecoderAndSanitizer.sol";
import {MorphoRewardsMerkleClaimerDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsMerkleClaimerDecoderAndSanitizer.sol";

contract MorphoRewardsDecoderAndSanitizer is
    MorphoRewardsWrapperDecoderAndSanitizer,
    MorphoRewardsMerkleClaimerDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{
    constructor() MorphoRewardsWrapperDecoderAndSanitizer() {}
}
