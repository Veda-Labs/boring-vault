// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract TreehouseDecoderAndSanitizer {
    //============================== Treehouse ===============================

    // Example TX: https://etherscan.io/tx/0x1e1f604ae5b9e634213b5bcf952257a5db9e370005b82986e6c6c5449f142a30
    function deposit(
        address _asset,
        uint256 /*_amount*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_asset);
    }

    // Call on redemption contract https://etherscan.io/address/0x0618dbdb3be798346e6d9c08c3c84658f94ad09f#writeContract
    function redeem(
        uint96 /*_shares*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    // Call on redemption contract https://etherscan.io/address/0x0618dbdb3be798346e6d9c08c3c84658f94ad09f#writeContract
    function finalizeRedeem(
        uint256 /*_redeemIndex*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
