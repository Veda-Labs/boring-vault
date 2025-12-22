// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract ZircuitSimpleStakingDecoderAndSanitizer {
    //============================== ZIRCUIT SIMPLE STAKING ===============================

    function depositFor(
        address _token,
        address _for,
        uint256 /*_amount*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token, _for);
    }

    function withdraw(
        address _token,
        uint256 /*_amount*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token);
    }
}
