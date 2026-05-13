// SPDX-License-Identifier: SEL-1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract FluidFTokenDecoderAndSanitizer {
    //============================== Fluid FToken ===============================

    function deposit(uint256, /*assets_*/ address receiver_, uint256 /*minAmountOut_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_);
    }

    function mint(uint256, /*shares_*/ address receiver_, uint256 /*maxAssets_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_);
    }

    function withdraw(uint256, /*assets_*/ address receiver_, address owner_, uint256 /*maxSharesBurn_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, owner_);
    }

    function redeem(uint256, /*shares_*/ address receiver_, address owner_, uint256 /*minAmountOut_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, owner_);
    }
}
