// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";

contract BTCKDecoderAndSanitizer {
    //on LBTC
    function deposit(
        uint256 /*amount*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function mint(
        bytes calldata,
        /*payload*/
        bytes calldata /*proof*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    //on LBTC
    function redeem(
        uint256 /*amount*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    //on BTCK
    function mintV1(
        bytes calldata,
        /*payload*/
        bytes calldata /*proof*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
