// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract BungeeDecoderAndSanitizer is BaseDecoderAndSanitizer {
    function createRequest(DecoderCustomTypes.Request calldata singleOutputRequest)
        external
        payable
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(
            singleOutputRequest.basicReq.sender,
            singleOutputRequest.basicReq.receiver,
            singleOutputRequest.basicReq.delegate,
            singleOutputRequest.basicReq.bungeeGateway,
            singleOutputRequest.basicReq.inputToken,
            singleOutputRequest.basicReq.outputToken,
            singleOutputRequest.swapOutputToken,
            singleOutputRequest.exclusiveTransmitter
        );
    }
}
