// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault-fixes@75bedc585da451b4ec4690ee8d3e378c6447dfe9 — file:audit/0xmacro-veda-90.pdf
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract CCTPDecoderAndSanitizer is BaseDecoderAndSanitizer {
    /// @dev Circle's CCTP domain id for Solana. Must match ChainValues.cctpSolanaDomainId, which
    /// _addCCTPBridgeToSolanaLeafs uses to build the matching 6-slot leaves.
    uint32 internal constant CCTP_SOLANA_DOMAIN = 5;

    error CCTPDecoderAndSanitizer__InvalidAddress();

    function depositForBurn(
        uint256, /*amount*/
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256, /*maxFee*/
        uint32 /*minFinalityThreshold*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (destinationDomain == CCTP_SOLANA_DOMAIN) {
            // Solana mintRecipient and destinationCaller are full 32 byte pubkeys. mintRecipient is a
            // USDC token account, not a wallet. Commit both halves of each across 2 leaf address slots,
            // the same lossless split CCIPDecoderAndSanitizer uses for SVM receivers, so the leaf pins
            // all 32 bytes. Truncating to 20 bytes would leave 12 bytes strategist controlled, enough
            // to burn USDC to an unmintable recipient.
            addressesFound = abi.encodePacked(
                address(uint160(destinationDomain)),
                address(bytes20(bytes16(mintRecipient))),
                address(bytes20(bytes16(mintRecipient << 128))),
                burnToken,
                address(bytes20(bytes16(destinationCaller))),
                address(bytes20(bytes16(destinationCaller << 128)))
            );
        } else {
            // EVM destinations require zero-padded EVM addresses. CCTP's destination side silently
            // truncates bytes32 to address, so nonzero high bits are rejected here.
            if (uint256(mintRecipient) >> 160 != 0) revert CCTPDecoderAndSanitizer__InvalidAddress();
            if (uint256(destinationCaller) >> 160 != 0) revert CCTPDecoderAndSanitizer__InvalidAddress();

            addressesFound = abi.encodePacked(
                address(uint160(destinationDomain)), address(uint160(uint256(mintRecipient))), burnToken, address(uint160(uint256(destinationCaller)))
            );
        }
    }

    function receiveMessage(
        bytes calldata,
        /*message*/
        bytes calldata /*attestation*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        //nothing to sanitize
        return addressesFound;
    }
}
