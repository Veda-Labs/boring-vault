// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract CCIPDecoderAndSanitizer {
    /// @notice Version of the CCIP decoding logic. Namespaced (not `version()`) so the per-vault decoders that
    ///         inherit this contract gain no generic selector a merkle leaf could route a target call through.
    string public constant CCIP_DECODER_VERSION = "V0.2";

    bytes4 internal constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;
    bytes4 internal constant GENERIC_EXTRA_ARGS_V2_TAG = 0x181dcf10;
    bytes4 internal constant SVM_EXTRA_ARGS_V1_TAG = 0x1f3b3aba;

    /// @dev Length of `GENERIC_EXTRA_ARGS_V2_TAG ++ abi.encode(GenericExtraArgsV2)`: a 4 byte tag + 2 static words.
    uint256 internal constant GENERIC_EXTRA_ARGS_V2_LENGTH = 68;

    error CCIPDecoderAndSanitizer__NonZeroDataLength();
    error CCIPDecoderAndSanitizer__NonZeroGasLimit();
    error CCIPDecoderAndSanitizer__InvalidExtraArgsTag();
    error CCIPDecoderAndSanitizer__NonZeroComputeUnits();
    error CCIPDecoderAndSanitizer__NonEmptyAccounts();
    error CCIPDecoderAndSanitizer__NonZeroWritableBitmap();
    error CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired();
    error CCIPDecoderAndSanitizer__InvalidSVMReceiver();
    error CCIPDecoderAndSanitizer__InvalidExtraArgsLength();

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
        } else if (tag == GENERIC_EXTRA_ARGS_V2_TAG) {
            // extraArgs is `tag ++ abi.encode(GenericExtraArgsV2)` (Client._argsToBytes in chainlink-ccip).
            // Decode the struct from the bytes after the tag, exactly as the CCIP onramp / fee quoter does.
            // The exact length check rejects truncated or padded encodings, so the decoder and CCIP can only
            // ever parse the same two words.
            if (message.extraArgs.length != GENERIC_EXTRA_ARGS_V2_LENGTH) {
                revert CCIPDecoderAndSanitizer__InvalidExtraArgsLength();
            }
            DecoderCustomTypes.GenericExtraArgsV2 memory extraArgs =
                abi.decode(message.extraArgs[4:], (DecoderCustomTypes.GenericExtraArgsV2));

            // Same token-only policy as V1: a zero gas limit (with empty data) means the destination offramp
            // never calls the receiver. Out-of-order execution is pinned on: CCIP v2.0+ lanes force it anyway,
            // and on v1.5/v1.6 lanes ordered execution only couples this vault's messages to each other.
            if (extraArgs.gasLimit != 0) revert CCIPDecoderAndSanitizer__NonZeroGasLimit();
            if (!extraArgs.allowOutOfOrderExecution) revert CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired();

            // Extract sensitive arguments, identical to the V1 branch so EVM leaves authorize both tags.
            sensitiveArguments =
                abi.encodePacked(address(uint160(destinationChainSelector)), abi.decode(message.receiver, (address)));
        } else if (tag == SVM_EXTRA_ARGS_V1_TAG) {
            // POLICY: this decoder only permits pure token transfers to SVM (Solana) destinations. CCIP
            // itself DOES support program execution on SVM (that is what computeUnits / accounts /
            // accountIsWritableBitmap exist for) and the live router accepts executable messages, so the
            // checks below are the only barrier between a token-bridge leaf and destination-side program
            // execution — do not relax them as "redundant". computeUnits must be zero, no accounts may be
            // passed, and the receiver must be the default pubkey (32 zero bytes). The token recipient
            // lives in extraArgs.tokenReceiver (an owner/wallet address; tokens are delivered to its
            // associated token account). The onramp parses extraArgs[4:] the same way.
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
