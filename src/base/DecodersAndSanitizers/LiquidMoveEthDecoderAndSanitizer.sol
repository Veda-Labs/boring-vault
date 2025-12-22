// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import { OneInchDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import { LidoDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import { EtherFiDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {
    NativeWrapperDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";

contract LiquidMoveEthDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer
{
    // Handle function signature conflicts
    function deposit()
        external
        pure
        virtual
        override (EtherFiDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function wrap(uint256)
        external
        pure
        virtual
        override (EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function unwrap(uint256)
        external
        pure
        virtual
        override (EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdraw(uint256)
        external
        pure
        virtual
        override (NativeWrapperDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
