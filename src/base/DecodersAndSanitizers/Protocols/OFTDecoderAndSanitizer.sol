// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
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
        // Sanitize Message.
        if (_sendParam.composeMsg.length > 0) {
            revert OFTDecoderAndSanitizer__NonZeroMessage();
        }
        if (_sendParam.oftCmd.length > 0) {
            revert OFTDecoderAndSanitizer__NonZeroOFTCommand();
        }

        sensitiveArguments = abi.encodePacked(
            address(uint160(_sendParam.dstEid)),
            address(bytes20(bytes16(_sendParam.to))),
            address(bytes20(bytes16(_sendParam.to << 128))),
            _refundAddress
        );
    }
}
