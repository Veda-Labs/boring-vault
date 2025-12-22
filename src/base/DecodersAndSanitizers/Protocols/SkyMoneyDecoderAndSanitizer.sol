// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract SkyMoneyDecoderAndSanitizer {
    //Dai Converter
    function daiToUsds(
        address recipient,
        uint256 /*amount/*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(recipient);
    }

    function usdsToDai(
        address recipient,
        uint256 /*amount*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(recipient);
    }

    //USDS LitePSM USDC & DAI LitePSM USDC
    //where Gem == 'USDC' and amounts are in USDC decimals
    function sellGem(
        address recipient,
        uint256 /*gemAmt*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(recipient);
    }

    function buyGem(
        address recipient,
        uint256 /*gemAmt*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(recipient);
    }
}
