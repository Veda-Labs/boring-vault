// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/// @notice Minimal Safe Guard interface (Safe v1.3.0+).
///         The Safe calls checkTransaction before execution and checkAfterExecution after.
///         Must also implement ERC-165 to be accepted by Safe's setGuard.
interface IGuard {
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external;

    function checkAfterExecution(bytes32 txHash, bool success) external;
}

/// @title SafeApproveHashGuard
/// @author Veda Tech Labs
/// @notice A Safe transaction guard that enforces on-chain signature collection.
///
///         When installed on a Safe, this guard rejects any transaction where one or more
///         signers used off-chain ECDSA signing (v = 27/28), eth_sign (v > 30), or
///         EIP-1271 contract signatures (v = 0). Only the "approved hash" signature type
///         (v = 1) is permitted, which requires each signer to have called
///         Safe.approveHash(txHash) on-chain before execution.
///
///         This forces all approvals to be visible on-chain, providing a monitoring window
///         where suspicious approvals can be detected before threshold is reached.
///
///         Safe signature encoding reference (each signature is 65 bytes):
///           v = 0  -> EIP-1271 contract signature  (BLOCKED)
///           v = 1  -> Approved hash (on-chain)      (ALLOWED)
///           v = 27 -> ECDSA signature               (BLOCKED)
///           v = 28 -> ECDSA signature               (BLOCKED)
///           v > 30 -> eth_sign prefixed signature    (BLOCKED)
contract SafeApproveHashGuard is IGuard {
    uint8 internal constant APPROVE_HASH_V = 1;
    bytes4 internal constant ERC165_INTERFACE_ID = 0x01ffc9a7;

    error SafeApproveHashGuard__OnlyApproveHashSignatures();
    error SafeApproveHashGuard__InvalidSignatureLength();

    /// @notice Called by the Safe before executing a transaction. Reverts unless every signature
    ///         in the packed signatures blob uses the approved-hash encoding (v == 1).
    /// @dev    Safe packs signatures as contiguous 65-byte chunks: r (32) | s (32) | v (1).
    ///         We iterate via pointer arithmetic, stepping by 65 bytes to reach each v byte.
    ///
    ///         Memory layout of `bytes memory signatures`:
    ///           [signatures]       -> 32 bytes: length (sigLength)
    ///           [signatures + 0x20] -> start of signature data
    ///
    ///         For signature i, the v byte sits at:
    ///           signatures + 0x20 (length prefix) + i*65 (signature offset) + 64 (v position)
    ///
    ///         We pre-compute the first v pointer as signatures + 0x60 (= 0x20 + 64) and
    ///         derive the end pointer as ptr + sigLength (since sigLength = n * 65, this
    ///         lands exactly one stride past the last v byte). This avoids division and
    ///         multiplication entirely -- the loop body is a single pointer increment.
    function checkTransaction(
        address,
        uint256,
        bytes memory,
        uint8,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory signatures,
        address
    ) external pure override {
        assembly {
            let sigLength := mload(signatures)

            // Signatures must be non-empty and a multiple of 65 bytes (one complete signature each).
            if or(iszero(sigLength), mod(sigLength, 65)) {
                mstore(0x00, 0xe660d24600000000000000000000000000000000000000000000000000000000) // InvalidSignatureLength()
                revert(0x00, 0x04)
            }

            // ptr  = address of the first v byte in memory.
            // end  = one stride (65 bytes) past the last v byte.
            // step = 65 bytes per signature.
            let ptr := add(signatures, 0x60)
            let end := add(ptr, sigLength)

            // Walk each signature's v byte. If any v != 1, the signer did not use approveHash.
            for {} lt(ptr, end) { ptr := add(ptr, 65) } {
                // byte(0, mload(ptr)) reads the single byte at ptr (most-significant byte of the 32-byte word).
                if iszero(eq(byte(0, mload(ptr)), 1)) {
                    mstore(0x00, 0x01c8f9aa00000000000000000000000000000000000000000000000000000000) // OnlyApproveHashSignatures()
                    revert(0x00, 0x04)
                }
            }
        }
    }

    /// @notice Post-execution hook. No-op -- this guard only validates pre-execution.
    function checkAfterExecution(bytes32, bool) external pure override {}

    /// @notice ERC-165 introspection. Safe calls this during setGuard to verify the
    ///         contract implements the Guard interface (0xe6d7a83a).
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IGuard).interfaceId || interfaceId == ERC165_INTERFACE_ID;
    }
}
