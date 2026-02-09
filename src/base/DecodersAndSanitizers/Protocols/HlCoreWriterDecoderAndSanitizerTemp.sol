// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CoreWriterDecoderAndSanitizer is BaseDecoderAndSanitizer {
    uint64 constant G = 10;

    error CoreWriterDecoderAndSanitizer__InvalidEncodingVersion();
    error CoreWriterDecoderAndSanitizer__InvalidActionID();

    function sendRawAction(bytes calldata data) external view virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
