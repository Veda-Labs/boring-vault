// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract CCIPDecoderAndSanitizer {
    bytes4 internal constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;
    bytes4 internal constant SVM_EXTRA_ARGS_V1_TAG = 0x1f3b3aba;

    error CCIPDecoderAndSanitizer__NonZeroDataLength();
    error CCIPDecoderAndSanitizer__NonZeroGasLimit();
    error CCIPDecoderAndSanitizer__InvalidExtraArgsTag();
    error CCIPDecoderAndSanitizer__NonZeroComputeUnits();
    error CCIPDecoderAndSanitizer__NonEmptyAccounts();
    error CCIPDecoderAndSanitizer__NonZeroWritableBitmap();
    error CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired();
    error CCIPDecoderAndSanitizer__InvalidSVMReceiver();

    //============================== CCIP ===============================

    function ccipSend(uint64 destinationChainSelector, DecoderCustomTypes.EVM2AnyMessage calldata message)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Sanitize Message.
        if (message.data.length > 0) revert CCIPDecoderAndSanitizer__NonZeroDataLength();

        bytes4 tag = bytes4(message.extraArgs[:4]);
        if (tag == EVM_EXTRA_ARGS_V1_TAG) {
            // extraArgs is `tag ++ abi.encode(EVMExtraArgsV1)` (Client._argsToBytes in chainlink-ccip).
            // Decode the struct from the bytes after the tag, exactly as the CCIP onramp does and
            // identically to the SVM branch below, so both tags are parsed the same canonical way.
            DecoderCustomTypes.EVMExtraArgsV1 memory extraArgs =
                abi.decode(message.extraArgs[4:], (DecoderCustomTypes.EVMExtraArgsV1));

            if (extraArgs.gasLimit != 0) revert CCIPDecoderAndSanitizer__NonZeroGasLimit();

            // Extract sensitive arguments.
            sensitiveArguments =
                abi.encodePacked(address(uint160(destinationChainSelector)), abi.decode(message.receiver, (address)));
        } else if (tag == SVM_EXTRA_ARGS_V1_TAG) {
            // SVM destinations only support token transfers: no program execution on the destination, so
            // computeUnits must be zero, no accounts may be passed, and the receiver must be the zero PDA.
            // The token recipient lives in extraArgs.tokenReceiver. The onramp parses extraArgs[4:] the same way.
            DecoderCustomTypes.SVMExtraArgsV1 memory extraArgs =
                abi.decode(message.extraArgs[4:], (DecoderCustomTypes.SVMExtraArgsV1));

            if (extraArgs.computeUnits != 0) revert CCIPDecoderAndSanitizer__NonZeroComputeUnits();
            if (extraArgs.accounts.length != 0) revert CCIPDecoderAndSanitizer__NonEmptyAccounts();
            if (extraArgs.accountIsWritableBitmap != 0) revert CCIPDecoderAndSanitizer__NonZeroWritableBitmap();
            if (!extraArgs.allowOutOfOrderExecution) revert CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired();
            if (message.receiver.length != 32 || bytes32(message.receiver) != bytes32(0)) {
                revert CCIPDecoderAndSanitizer__InvalidSVMReceiver();
            }

            // Extract sensitive arguments, splitting the 32 byte token receiver across 2 leaf address slots.
            sensitiveArguments = abi.encodePacked(
                address(uint160(destinationChainSelector)),
                address(bytes20(bytes16(extraArgs.tokenReceiver))),
                address(bytes20(bytes16(extraArgs.tokenReceiver << 128)))
            );
        } else {
            revert CCIPDecoderAndSanitizer__InvalidExtraArgsTag();
        }

        uint256 tokenAmountsLength = message.tokenAmounts.length;
        for (uint256 i; i < tokenAmountsLength; ++i) {
            sensitiveArguments = abi.encodePacked(sensitiveArguments, message.tokenAmounts[i].token);
        }

        sensitiveArguments = abi.encodePacked(sensitiveArguments, message.feeToken);
    }
}
