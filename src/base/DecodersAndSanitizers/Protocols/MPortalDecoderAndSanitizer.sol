// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

// Current proxy https://etherscan.io/address/0xd925c84b55e4e44a53749ff5f2a5a13f63d128fd#code
// Current implementation (mainnet) https://etherscan.io/address/0xf1c63a35b68a5513b97e05fa2e111d7cc55beaee#code
// Current implementation (Monad) 0x6c0815281be10c9b929f6de50983fa0c61148da6
// WormholeBridgeAdapter (mainnet + Monad) 0xaCffEC28C4eEe21C889a4e6C0704c540Ed9D4fDd
contract MPortalDecoderAndSanitizer {
    error MPortalDecoderAndSanitizer__NonEmptyBridgeAdapterArgs();
    error MPortalDecoderAndSanitizer__InvalidSignedQuote();

    // Wormhole Executor signed quote (EQ01), passed as bridgeAdapterArgs to the WormholeBridgeAdapter:
    //   [0..4) "EQ01" | [4..24) quoter | [24..56) bytes32 payee | [56..58) srcChain | [58..60) dstChain
    //   [60..68) expiry | [68..100) baseFee, dstGasPrice, srcPrice, dstPrice | [100..165) signature
    bytes4 internal constant WORMHOLE_SIGNED_QUOTE_PREFIX = 0x45513031; // "EQ01"
    uint256 internal constant WORMHOLE_SIGNED_QUOTE_LENGTH = 165;

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

        // Empty args: adapters that take no args (e.g. Hyperlane). Non-empty args are only accepted as a
        // Wormhole Executor signed quote. The Executor does not verify the quote signature onchain and pays
        // the whole msg.value to the quote's payee, so the payee (and the quoter) must be pinned in the leaf.
        if (bridgeAdapterArgs.length > 0) {
            addressesFound = abi.encodePacked(addressesFound, _decodeWormholeSignedQuote(bridgeAdapterArgs));
        }
    }

    // Returns the quoter and payee of an EQ01 signed quote. srcChain, dstChain and expiry are enforced by the
    // Executor; fees, prices and the signature are not used onchain.
    function _decodeWormholeSignedQuote(bytes calldata signedQuote) internal pure returns (bytes memory) {
        if (
            signedQuote.length != WORMHOLE_SIGNED_QUOTE_LENGTH || bytes4(signedQuote[0:4]) != WORMHOLE_SIGNED_QUOTE_PREFIX
                || bytes12(signedQuote[24:36]) != bytes12(0)
        ) {
            revert MPortalDecoderAndSanitizer__InvalidSignedQuote();
        }
        return abi.encodePacked(address(bytes20(signedQuote[4:24])), address(bytes20(signedQuote[36:56])));
    }
}
