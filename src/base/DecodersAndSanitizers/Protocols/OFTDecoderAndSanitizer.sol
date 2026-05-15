// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract OFTDecoderAndSanitizer {
    error OFTDecoderAndSanitizer__NonZeroMessage();
    error OFTDecoderAndSanitizer__NonZeroOFTCommand();

    //============================== OFT ===============================

    function send(
        DecoderCustomTypes.SendParam calldata _sendParam,
        DecoderCustomTypes.MessagingFee calldata, /*_fee*/
        address _refundAddress
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        if (_sendParam.oftCmd.length > 0) {
            revert OFTDecoderAndSanitizer__NonZeroOFTCommand();
        }

        // MultiHop support.
        if (_sendParam.composeMsg.length > 0) {
            // It requires the final destination parameters to be encoded in the compose message.
            DecoderCustomTypes.SendParam memory finalDestinationParams =
                abi.decode(_sendParam.composeMsg, (DecoderCustomTypes.SendParam));

            if (finalDestinationParams.oftCmd.length > 0) {
                revert OFTDecoderAndSanitizer__NonZeroOFTCommand();
            }

            // Do not allow more than one compose message.
            if (finalDestinationParams.composeMsg.length > 0) {
                revert OFTDecoderAndSanitizer__NonZeroMessage();
            }

            // Layout (6 addresses):
            //   [0]   Packed endpoint IDs: (firstHopEid << 32 | finalDestEid) as address
            //   [1-2] First hop receiver (bytes32 `to`, split upper/lower)
            //   [3-4] Final destination receiver (bytes32 `to`, split upper/lower)
            //   [5]   Refund address
            return abi.encodePacked(
                address(uint160((uint256(_sendParam.dstEid) << 32) | uint256(finalDestinationParams.dstEid))),
                address(bytes20(bytes16(_sendParam.to))),
                address(bytes20(bytes16(_sendParam.to << 128))),
                address(bytes20(bytes16(finalDestinationParams.to))),
                address(bytes20(bytes16(finalDestinationParams.to << 128))),
                _refundAddress
            );
        }

        sensitiveArguments = abi.encodePacked(
            address(uint160(_sendParam.dstEid)),
            address(bytes20(bytes16(_sendParam.to))),
            address(bytes20(bytes16(_sendParam.to << 128))),
            _refundAddress
        );
    }
}
