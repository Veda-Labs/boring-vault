// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract LombardBTCocDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== LOMBARD BTCoc ===============================

    function deposit(
        address depositAsset,
        uint256,
        /*assets*/
        address receiver
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(depositAsset, receiver);
    }

    function requestRedeem(
        uint256,
        /*shares*/
        address owner
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(owner);
    }
}
