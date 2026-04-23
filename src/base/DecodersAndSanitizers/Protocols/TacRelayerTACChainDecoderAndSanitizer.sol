// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

abstract contract TacDecoderAndSanitizer is BaseDecoderAndSanitizer {
    error TacDecoderAndSanitizer__EmptyTvmTarget();
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

        DecoderCustomTypes.OutMessageV1 memory message = abi.decode(encodedMessage, (DecoderCustomTypes.OutMessageV1));

        if (message.toBridge.length == 0) {
            revert TacDecoderAndSanitizer__NoTokensToBridge();
        }

        if (bytes(message.tvmTarget).length == 0) {
            revert TacDecoderAndSanitizer__EmptyTvmTarget();
        }

        bytes32 tvmTargetHash = keccak256(bytes(message.tvmTarget));
        address tvmTargetAsAddress = address(uint160(uint256(tvmTargetHash)));

        addressesFound = abi.encodePacked(addressesFound, tvmTargetAsAddress);

        for (uint256 i = 0; i < message.toBridge.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, message.toBridge[i].evmAddress);
        }
    }
}

