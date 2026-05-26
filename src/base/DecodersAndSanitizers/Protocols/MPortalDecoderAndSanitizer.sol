// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

// Current proxy https://etherscan.io/address/0xd925c84b55e4e44a53749ff5f2a5a13f63d128fd#code
// Current implementation https://etherscan.io/address/0xdfc64dbf0e3fcca6871aa2f61f848dbb7843c2e6#code
contract MPortalDecoderAndSanitizer {
    error MPortalDecoderAndSanitizer__NonEmptyBridgeAdapterArgs();

    // Send token using default bridge adapter
    function sendToken(
        uint256, // amount
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        bytes calldata bridgeAdapterArgs
    ) external pure returns (bytes memory addressesFound) {
        if (bridgeAdapterArgs.length > 0) {
            revert MPortalDecoderAndSanitizer__NonEmptyBridgeAdapterArgs();
        }
        // Each bytes32 is split into two 20-byte chunks (first 16 bytes, last 16 bytes) so the full
        // 32 bytes are covered in the Merkle leaf — works for both EVM and non-EVM (e.g. Solana) recipients.
        addressesFound = abi.encodePacked(
            sourceToken,
            address(uint160(destinationChainId)),
            address(bytes20(bytes16(destinationToken))),
            address(bytes20(bytes16(destinationToken << 128))),
            address(bytes20(bytes16(recipient))),
            address(bytes20(bytes16(recipient << 128))),
            address(bytes20(bytes16(refundAddress))),
            address(bytes20(bytes16(refundAddress << 128)))
        );
    }

    // Send token using custom bridge adapter
    function sendToken(
        uint256,
        address sourceToken,
        uint32 destinationChainId,
        bytes32 destinationToken,
        bytes32 recipient,
        bytes32 refundAddress,
        address bridgeAdapter,
        bytes calldata bridgeAdapterArgs
    ) external pure returns (bytes memory addressesFound) {
        if (bridgeAdapterArgs.length > 0) {
            revert MPortalDecoderAndSanitizer__NonEmptyBridgeAdapterArgs();
        }
        addressesFound = abi.encodePacked(
            sourceToken,
            address(uint160(destinationChainId)),
            address(bytes20(bytes16(destinationToken))),
            address(bytes20(bytes16(destinationToken << 128))),
            address(bytes20(bytes16(recipient))),
            address(bytes20(bytes16(recipient << 128))),
            address(bytes20(bytes16(refundAddress))),
            address(bytes20(bytes16(refundAddress << 128))),
            bridgeAdapter
        );
    }
}
