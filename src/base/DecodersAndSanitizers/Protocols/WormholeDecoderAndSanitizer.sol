// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

struct ExecutorArgs {
    uint256 value;
    address refundAddress;
    bytes signedQuote;
    bytes instructions;
}

struct FeeArgs {
    uint16 dbps;
    address payee;
}

contract WormholeDecoderAndSanitizer {

    function transfer(
        address multiTokenNtt,
        address token,
        uint256, /*amount*/
        uint16 recipientChain,
        bytes32 recipient,
        bytes32 refundAddress,
        bytes calldata, /*transceiverInstructions*/
        ExecutorArgs calldata executorArgs,
        FeeArgs calldata feeArgs
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        address recipient0 = address(bytes20(bytes16(recipient)));
        address recipient1 = address(bytes20(bytes16(recipient << 128)));

        address refund0 = address(bytes20(bytes16(refundAddress)));
        address refund1 = address(bytes20(bytes16(refundAddress << 128)));

        sensitiveArguments = abi.encodePacked(
            multiTokenNtt,
            token,
            address(uint160(recipientChain)),
            recipient0,
            recipient1,
            refund0,
            refund1,
            executorArgs.refundAddress,
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
        ExecutorArgs calldata executorArgs,
        FeeArgs calldata feeArgs
    ) external pure virtual returns (bytes memory sensitiveArguments) {
        address recipient0 = address(bytes20(bytes16(recipient)));
        address recipient1 = address(bytes20(bytes16(recipient << 128)));

        address refund0 = address(bytes20(bytes16(refundAddress)));
        address refund1 = address(bytes20(bytes16(refundAddress << 128)));

        sensitiveArguments = abi.encodePacked(
            multiTokenNtt,
            address(uint160(recipientChain)),
            recipient0,
            recipient1,
            refund0,
            refund1,
            executorArgs.refundAddress,
            feeArgs.payee
        );
    }
}
