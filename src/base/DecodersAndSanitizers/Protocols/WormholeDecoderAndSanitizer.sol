// SPDX-License-Identifier: SEL-1.0
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract WormholeDecoderAndSanitizer {

    error WormholeDecoderAndSanitizer__UnknownRelayInstruction(uint8 instructionType);

    function transfer(
        address multiTokenNtt,
        address token,
        uint256, /*amount*/
        uint16 recipientChain,
        bytes32 recipient,
        bytes32 refundAddress,
        bytes calldata, /*transceiverInstructions*/
        DecoderCustomTypes.WormholeExecutorArgs calldata executorArgs,
        DecoderCustomTypes.WormholeFeeArgs calldata feeArgs
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        // Grouped into one packed value to keep the outer encodePacked's live stack slots low (avoids stack too deep).
        bytes memory recipientAndRefund = abi.encodePacked(
            address(bytes20(bytes16(recipient))),
            address(bytes20(bytes16(recipient << 128))),
            address(bytes20(bytes16(refundAddress))),
            address(bytes20(bytes16(refundAddress << 128)))
        );

        sensitiveArguments = abi.encodePacked(
            multiTokenNtt,
            token,
            address(uint160(recipientChain)),
            recipientAndRefund,
            executorArgs.refundAddress,
            _decodeSignedQuoteAddresses(executorArgs.signedQuote),
            _decodeRelayInstructionAddresses(executorArgs.instructions),
            feeArgs.payee
        );
    }

    function transferETH(
        address multiTokenNtt,
        uint256, /*amount*/
        uint16 recipientChain,
        bytes32 recipient,
        bytes32 refundAddress,
        bytes calldata, /*transceiverInstructions*/
        DecoderCustomTypes.WormholeExecutorArgs calldata executorArgs,
        DecoderCustomTypes.WormholeFeeArgs calldata feeArgs
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        bytes memory recipientAndRefund = abi.encodePacked(
            address(bytes20(bytes16(recipient))),
            address(bytes20(bytes16(recipient << 128))),
            address(bytes20(bytes16(refundAddress))),
            address(bytes20(bytes16(refundAddress << 128)))
        );

        sensitiveArguments = abi.encodePacked(
            multiTokenNtt,
            address(uint160(recipientChain)),
            recipientAndRefund,
            executorArgs.refundAddress,
            _decodeSignedQuoteAddresses(executorArgs.signedQuote),
            _decodeRelayInstructionAddresses(executorArgs.instructions),
            feeArgs.payee
        );
    }

    // Parses the SignedQuote blob into a struct (see WormholeSignedQuote layout) and returns its addresses:
    // the EVM quoter. The payee is the quoter's own payout address (not attacker-controlled), so it is not sanitized.
    function _decodeSignedQuoteAddresses(bytes calldata signedQuote) internal pure returns (bytes memory) {
        DecoderCustomTypes.WormholeSignedQuote memory quote = DecoderCustomTypes.WormholeSignedQuote({
            prefix: bytes4(signedQuote[0:4]),
            quoter: address(bytes20(signedQuote[4:24])),
            payee: bytes32(signedQuote[24:56])
        });
        return abi.encodePacked(quote.quoter);
    }

    // RelayInstructions = unbounded array of (uint8 type + body). Layouts per type (Wormhole executor TS SDK):
    //   1 GasInstruction:        uint128 gasLimit | uint128 msgValue                                        (no addresses)
    //   2 GasDropOffInstruction: see WormholeGasDropOffInstruction                                          (destination wallet)
    // Unknown types revert to fail safe — an unknown opcode may hide additional addresses.
    function _decodeRelayInstructionAddresses(bytes calldata instructions) internal pure returns (bytes memory addrs) {
        uint256 offset = 0;
        uint256 len = instructions.length;
        while (offset < len) {
            uint8 instructionType = uint8(instructions[offset]);
            offset += 1;
            if (instructionType == 1) {
                offset += 32;
            } else if (instructionType == 2) {
                DecoderCustomTypes.WormholeGasDropOffInstruction memory ins = DecoderCustomTypes
                    .WormholeGasDropOffInstruction({
                    dropOff: uint128(bytes16(instructions[offset:offset + 16])),
                    recipient: bytes32(instructions[offset + 16:offset + 48])
                });
                offset += 48;
                addrs = abi.encodePacked(
                    addrs,
                    address(bytes20(bytes16(ins.recipient))),
                    address(bytes20(bytes16(ins.recipient << 128)))
                );
            } else {
                revert WormholeDecoderAndSanitizer__UnknownRelayInstruction(instructionType);
            }
        }
    }
}
