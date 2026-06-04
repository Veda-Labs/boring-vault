// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract CCTPDecoderAndSanitizer is BaseDecoderAndSanitizer {

    error CCTPDecoderAndSanitizer__InvalidAddress();

    function depositForBurn(
        uint256, /*amount*/
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256, /*maxFee*/
        uint32 /*minFinalityThreshold*/
    ) external pure virtual returns (bytes memory addressesFound) {
        if (uint256(mintRecipient) >> 160 != 0) revert CCTPDecoderAndSanitizer__InvalidAddress();
        if (uint256(destinationCaller) >> 160 != 0) revert CCTPDecoderAndSanitizer__InvalidAddress();

        addressesFound = abi.encodePacked(
            address(uint160(destinationDomain)),
            address(uint160(uint256(mintRecipient))),
            burnToken,
            address(uint160(uint256(destinationCaller)))
        );
    }

    function receiveMessage(bytes calldata /*message*/, bytes calldata /*attestation*/)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        //nothing to sanitize
        return addressesFound;
    }
}
