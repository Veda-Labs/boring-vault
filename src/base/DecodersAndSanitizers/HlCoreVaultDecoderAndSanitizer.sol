// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {
    CctpCoreDepositWalletDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/CctpCoreDepositWalletDecoderAndSanitizer.sol";
import {
    CoreWriterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/HlCoreWriterDecoderAndSanitizer.sol";

contract HlCoreVaultDecoderAndSanitizer is CctpCoreDepositWalletDecoderAndSanitizer, CoreWriterDecoderAndSanitizer {
    constructor() {}
}
