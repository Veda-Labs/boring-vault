// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract GoldiVaultDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== GoldiVault ===============================

    function deposit(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeemOwnership(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeemYield(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function compound() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== PointsGoldiVaultStreaming ===============================

    function buyYT(uint256, /*ytAmount*/ uint256, /*dtAmountMax*/ uint256 /*amountOutMin*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function sellYT(uint256, /*ytAmount*/ uint256, /*dtAmountMin*/ uint256 /*amountInMax*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
