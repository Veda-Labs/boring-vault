// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";

contract BTCNMinterDecoderAndSanitizer {
    function swapExactCollateralForDebt(
        uint256, /*collateralIn*/
        uint256, /*debtOutMin*/
        address to,
        uint256 /*deadline*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(to);
    }

    function swapExactDebtForCollateral(
        uint256, /*debtIn*/
        uint256, /*collateralOutMin*/
        address to,
        uint256 /*deadline*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(to);
    }
}
