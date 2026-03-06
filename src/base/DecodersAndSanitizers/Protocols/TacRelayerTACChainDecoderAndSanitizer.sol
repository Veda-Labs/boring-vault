// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomType} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract TacDecoderAndSanitizer is BaseDecoderAndSanitizer {
    error TacDecoderAndSanitizer__UnsupportedMessageVersion(uint256 version);
    error TacDecoderAndSanitizer__NoTokensToBridge();

    function sendMessage(uint256 messageVersion, bytes calldata encodedMessage)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (messageVersion != 1) {
            revert TacDecoderAndSanitizer__UnsupportedMessageVersion(messageVersion);
        }

        OutMessageV1 memory message = abi.decode(encodedMessage, (DecoderCustomType.OutMessageV1));

        if (message.toBridge.length == 0) {
            revert TacDecoderAndSanitizer__NoTokensToBridge();
        }

        for (uint256 i = 0; i < message.toBridge.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, message.toBridge[i].evmAddress);
        }
    }
}

