// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol";
import {VelodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/VelodromeDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";

contract GoldenGooseBaseDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    BalancerV3DecoderAndSanitizer,
    VelodromeDecoderAndSanitizer, // For Aerodrome (Velodrome V3 fork)
    OdosDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    OFTDecoderAndSanitizer
{
    constructor(
        address _aerodromeNonFungiblePositionManager,
        address _odosRouter
    )
        VelodromeDecoderAndSanitizer(_aerodromeNonFungiblePositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================

    /**
     * @notice TellerDecoderAndSanitizer and BalancerV3 both specify a deposit function
     * BalancerV3: deposit(uint256,address)
     * Teller: deposit(address,uint256,uint256)
     * These have different signatures so no conflict exists
     */

    /**
     * @notice BalancerV3 specifies a `deposit(uint256,address)`.
     */
    function deposit(uint256, address receiver)
        external
        pure
        override(BalancerV3DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    /**
     * @notice NativeWrapper specifies a `deposit()`.
     */
    function deposit() external pure override(NativeWrapperDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    /**
     * @notice Multiple decoders specify different withdraw functions
     * NativeWrapper: withdraw(uint256)
     * VelodromeDecoderAndSanitizer: withdraw(uint256)
     * AaveV3: withdraw(address,uint256,address)
     */
    function withdraw(uint256)
        external
        pure
        override(NativeWrapperDecoderAndSanitizer, VelodromeDecoderAndSanitizer, CurveDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdraw(address asset, uint256, address to)
        external
        pure
        override(AaveV3DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, to);
    }

    /**
     * @notice StandardBridgeDecoderAndSanitizer specifies various bridge functions
     * that need to be exposed for Base chain bridging
     */
}