// SPDX-License-Identifier: SEL-1.0
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault-fixes@e62373a1bc5bd8d0c15a9ccdda3e39f0feedd38a — file:audit/0xmacro-veda-107.pdf
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

// Wormhole MultiTokenNtt executor router ("MultiTokenNttWithExecutor-0.0.1").
// Mainnet 0x03dB430D830601DB368991eE55DAa9A708df7912, Monad 0xFEA937F7124E19124671f1685671d3f04a9Af4E4.
contract WormholeNTTDecoderAndSanitizer {
    error WormholeNTTDecoderAndSanitizer__UnknownRelayInstruction(uint8 instructionType);
    error WormholeNTTDecoderAndSanitizer__InvalidSignedQuote();
    error WormholeNTTDecoderAndSanitizer__NonZeroReferrerFee();
    error WormholeNTTDecoderAndSanitizer__TruncatedRelayInstruction();

    // Wormhole Executor signed quote (EQ01):
    //   [0..4) "EQ01" | [4..24) quoter | [24..56) bytes32 payee | [56..58) srcChain | [58..60) dstChain
    //   [60..68) expiry | [68..100) baseFee, dstGasPrice, srcPrice, dstPrice | [100..165) signature
    bytes4 internal constant WORMHOLE_SIGNED_QUOTE_PREFIX = 0x45513031; // "EQ01"
    uint256 internal constant WORMHOLE_SIGNED_QUOTE_LENGTH = 165;

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
        _checkNoReferrerFee(feeArgs);
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
        _checkNoReferrerFee(feeArgs);
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

    // dbps is an optional integrator (referrer) fee taken out of the bridged amount and sent to feeArgs.payee.
    // A vault bridging its own funds has no referrer to pay, so it must be zero.
    function _checkNoReferrerFee(DecoderCustomTypes.WormholeFeeArgs calldata feeArgs) internal pure {
        if (feeArgs.dbps != 0) revert WormholeNTTDecoderAndSanitizer__NonZeroReferrerFee();
    }

    // Returns the quoter and payee of an EQ01 signed quote. srcChain, dstChain and expiry are checked by the Executor.
    function _decodeSignedQuoteAddresses(bytes calldata signedQuote) internal pure returns (bytes memory) {
        if (
            signedQuote.length != WORMHOLE_SIGNED_QUOTE_LENGTH || bytes4(signedQuote[0:4]) != WORMHOLE_SIGNED_QUOTE_PREFIX
                || bytes12(signedQuote[24:36]) != bytes12(0)
        ) {
            revert WormholeNTTDecoderAndSanitizer__InvalidSignedQuote();
        }
        return abi.encodePacked(address(bytes20(signedQuote[4:24])), address(bytes20(signedQuote[36:56])));
    }

    // RelayInstructions = unbounded array of (uint8 type + body). Layouts per type (Wormhole executor TS SDK):
    //   1 GasInstruction:        uint128 gasLimit | uint128 msgValue                                        (no addresses)
    //   2 GasDropOffInstruction: see WormholeGasDropOffInstruction                                          (destination wallet)
    // Unknown instruction types revert.
    function _decodeRelayInstructionAddresses(bytes calldata instructions) internal pure returns (bytes memory addrs) {
        uint256 offset = 0;
        uint256 len = instructions.length;
        while (offset < len) {
            uint8 instructionType = uint8(instructions[offset]);
            offset += 1;
            if (instructionType == 1) {
                offset += 32;
                if (offset > len) revert WormholeNTTDecoderAndSanitizer__TruncatedRelayInstruction();
            } else if (instructionType == 2) {
                DecoderCustomTypes.WormholeGasDropOffInstruction memory ins = DecoderCustomTypes.WormholeGasDropOffInstruction({
                    dropOff: uint128(bytes16(instructions[offset:offset + 16])), recipient: bytes32(instructions[offset + 16:offset + 48])
                });
                offset += 48;
                addrs = abi.encodePacked(addrs, address(bytes20(bytes16(ins.recipient))), address(bytes20(bytes16(ins.recipient << 128))));
            } else {
                revert WormholeNTTDecoderAndSanitizer__UnknownRelayInstruction(instructionType);
            }
        }
    }
}
