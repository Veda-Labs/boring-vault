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

    /// @dev Hard ceiling on the constructor-set fee cap.
    uint256 internal constant MAX_FEE_BPS_CEILING = 50;

    /// @dev Caps how much fee authority a strategist can grant Circle per call. The fee charged is
    /// the Circle-attested feeExecuted, bounded onchain only by maxFee, so an oversized maxFee lets
    /// a misbehaving attester skim up to that amount. Immutable, so the cap is tuned by redeploy.
    uint256 internal immutable cctpMaxFeeBps;

    error CCTPDecoderAndSanitizer__InvalidAddress();
    error CCTPDecoderAndSanitizer__FeeTooHigh();
    error CCTPDecoderAndSanitizer__InvalidMaxFeeBps();

    constructor(uint256 _cctpMaxFeeBps) {
        if (_cctpMaxFeeBps > MAX_FEE_BPS_CEILING) revert CCTPDecoderAndSanitizer__InvalidMaxFeeBps();
        cctpMaxFeeBps = _cctpMaxFeeBps;
    }

    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 /*minFinalityThreshold*/
    ) external view virtual returns (bytes memory addressesFound) {
        // The fee charged is whatever Circle attests up to maxFee, so cap the grantable headroom.
        if (maxFee * 10_000 > amount * cctpMaxFeeBps) revert CCTPDecoderAndSanitizer__FeeTooHigh();

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
