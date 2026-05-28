// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {BTCbDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCbDecoderAndSanitizer.sol";
import {BTCKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCKDecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {EigenLayerLSTStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";

contract EtherFiDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    BTCbDecoderAndSanitizer,
    BTCKDecoderAndSanitizer,
    FluidDexDecoderAndSanitizer,
    EigenLayerLSTStakingDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    UniswapV4DecoderAndSanitizer
{
    constructor(address _fluidFactory, address _posm)
        FluidDexDecoderAndSanitizer(_fluidFactory)
        UniswapV4DecoderAndSanitizer(_posm)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================

    function deposit(uint256 /*amount*/)
        external
        pure
        override(BTCbDecoderAndSanitizer, BTCKDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function redeem(uint256 /*amount*/)
        external
        pure
        override(BTCbDecoderAndSanitizer, BTCKDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function mint(bytes calldata payload, bytes calldata /*proof*/)
        external
        pure
        override(BTCbDecoderAndSanitizer, BTCKDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        (,,,,, bytes memory msgBody) =
            abi.decode(payload[4:], (bytes32, uint256, bytes32, address, address, bytes));
        bytes32 recipientWord;
        assembly {
            recipientWord := mload(add(msgBody, 0x44))
        }
        addressesFound = abi.encodePacked(address(uint160(uint256(recipientWord))));
    }

    function mintV1(bytes calldata payload, bytes calldata /*proof*/)
        external
        pure
        override(BTCbDecoderAndSanitizer, BTCKDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        (uint256 toChain, address receiver,,,, address token) =
            abi.decode(payload[4:], (uint256, address, uint256, bytes32, uint256, address));
        addressesFound = abi.encodePacked(address(uint160(toChain)), receiver, token);
    }
}
