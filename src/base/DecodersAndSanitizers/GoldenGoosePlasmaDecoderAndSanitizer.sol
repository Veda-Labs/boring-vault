// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {RedSnwapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RedSnwapperDecoderAndSanitizer.sol";
import {GlueXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GlueXDecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {FluidRewardsClaimingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidRewardsClaimingDecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {GearboxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GearboxDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";

/**
 * @title GoldenGoosePlasmaDecoderAndSanitizer
 * @notice Decoder and sanitizer for the Golden Goose vault on Plasma network
 * @dev Supports:
 *      - Native XPL wrapping/unwrapping
 *      - Aave V3 (supply wstETH/weETH, borrow USDT/WETH)
 *      - Swaps via Red Snwapper and GlueX (USDT0/wstETH/weETH/WETH/XPL/FLUID)
 *      - Fluid fUSDT0 vault and FLUID rewards claiming (swap to WETH)
 *      - Euler vaults (TelosC Surge, K3 Kapital, Re7 USDT0 Core)
 *      - Gearbox Edge UltraYield and GEAR rewards (swap to WETH)
 *      - Merkl rewards claiming
 *      - CCIP bridging (wstETH to Mainnet)
 *      - LayerZero OFT bridging (WETH and weETH to Mainnet)
 */
contract GoldenGoosePlasmaDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    RedSnwapperDecoderAndSanitizer,
    GlueXDecoderAndSanitizer,
    FluidFTokenDecoderAndSanitizer,
    FluidRewardsClaimingDecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    GearboxDecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    CCIPDecoderAndSanitizer
{
    //============================== HANDLE FUNCTION COLLISIONS ===============================

    /**
     * @notice Multiple decoders specify different deposit functions:
     * - NativeWrapper: deposit()
     * - FluidFToken: deposit(uint256,address,uint256)
     * - Gearbox: deposit(uint256)
     */
    function deposit() external pure override(NativeWrapperDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function deposit(uint256)
        external
        pure
        override(GearboxDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function deposit(uint256, address receiver_, uint256)
        external
        pure
        override(FluidFTokenDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_);
    }

    /**
     * @notice Multiple decoders specify different withdraw functions:
     * - NativeWrapper: withdraw(uint256)
     * - AaveV3: withdraw(address,uint256,address)
     * - FluidFToken: withdraw(uint256,address,address,uint256)
     * - Gearbox: withdraw(uint256)
     */
    function withdraw(uint256)
        external
        pure
        override(NativeWrapperDecoderAndSanitizer, GearboxDecoderAndSanitizer)
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

    function withdraw(uint256, address receiver_, address owner_, uint256)
        external
        pure
        override(FluidFTokenDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, owner_);
    }

    /**
     * @notice FluidFToken specifies mint function:
     * - FluidFToken: mint(uint256,address,uint256)
     */
    function mint(uint256, address receiver_, uint256)
        external
        pure
        override(FluidFTokenDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_);
    }

    /**
     * @notice FluidFToken specifies redeem function:
     * - FluidFToken: redeem(uint256,address,address,uint256)
     */
    function redeem(uint256, address receiver_, address owner_, uint256)
        external
        pure
        override(FluidFTokenDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, owner_);
    }
}
