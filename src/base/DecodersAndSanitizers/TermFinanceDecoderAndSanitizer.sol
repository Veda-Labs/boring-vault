// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract TermFinanceDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== TERM FINANCE ===============================

    function lockOffers(DecoderCustomTypes.TermAuctionOfferSubmission[] calldata offerSubmissions)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i = 0; i < offerSubmissions.length; i++) {
            addressesFound = abi.encodePacked(addressesFound, offerSubmissions[i].offeror);
            addressesFound = abi.encodePacked(addressesFound, offerSubmissions[i].purchaseToken);
        }
    }

    function unlockOffers(bytes32[] calldata offerIds) external pure virtual returns (bytes memory addressesFound) {}

    function revealOffers(bytes32[] calldata ids, uint256[] calldata prices, uint256[] calldata nonces)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {}

    function redeemTermRepoTokens(address redeemer, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(redeemer);
    }
}
