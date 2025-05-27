// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {AtomicQueueDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/AtomicQueueDecoderAndSanitizer.sol";

contract OnlyAtomicQueueDecoderAndSanitizer is AtomicQueueDecoderAndSanitizer {
    constructor(uint32 min, uint32 max) AtomicQueueDecoderAndSanitizer(min, max) {}
}
