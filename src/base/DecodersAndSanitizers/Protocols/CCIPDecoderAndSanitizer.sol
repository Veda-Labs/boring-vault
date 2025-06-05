// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CCIPDecoderAndSanitizer is BaseDecoderAndSanitizer {
    bytes4 internal constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;

    error CCIPDecoderAndSanitizer__NonZeroDataLength();
    error CCIPDecoderAndSanitizer__NonZeroGasLimit();
    error CCIPDecoderAndSanitizer__InvalidExtraArgsTag();

    //============================== CCIP ===============================

    function ccipSend(uint64 destinationChainSelector, DecoderCustomTypes.EVM2AnyMessage calldata message)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Sanitize Message.
        if (message.data.length > 0) revert CCIPDecoderAndSanitizer__NonZeroDataLength();

        (bytes4 tag, DecoderCustomTypes.EVMExtraArgsV1 memory extraArgs) =
            abi.decode(message.extraArgs, (bytes4, DecoderCustomTypes.EVMExtraArgsV1));

        if (tag != EVM_EXTRA_ARGS_V1_TAG) revert CCIPDecoderAndSanitizer__InvalidExtraArgsTag();
        if (extraArgs.gasLimit != 0) revert CCIPDecoderAndSanitizer__NonZeroGasLimit();

        // Extract sensitive arguments.
        sensitiveArguments =
            abi.encodePacked(address(uint160(destinationChainSelector)), abi.decode(message.receiver, (address)));

        uint256 tokenAmountsLength = message.tokenAmounts.length;
        for (uint256 i; i < tokenAmountsLength; ++i) {
            sensitiveArguments = abi.encodePacked(sensitiveArguments, message.tokenAmounts[i].token);
        }

        sensitiveArguments = abi.encodePacked(sensitiveArguments, message.feeToken);
    }
}
