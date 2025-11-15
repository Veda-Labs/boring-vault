// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {LidoStandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LidoStandardBridgeDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol";
import {BalancerV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {DvStETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DvStETHDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {Permit2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Permit2DecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {wSwellUnwrappingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/wSwellUnwrappingDecoderAndSanitizer.sol";
import {SymbioticVaultDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SymbioticVaultDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {TreehouseDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/TreehouseDecoderAndSanitizer.sol";
import {ArbitrumNativeBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ArbitrumNativeBridgeDecoderAndSanitizer.sol";
import {AgglayerDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/AgglayerDecoderAndSanitizer.sol";
import {LineaBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LineaBridgeDecoderAndSanitizer.sol";
import {ResolvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ResolvDecoderAndSanitizer.sol";
import {GearboxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GearboxDecoderAndSanitizer.sol";

contract GoldenGooseDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    LidoStandardBridgeDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    UniswapV4DecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    BalancerV3DecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    FluidDexDecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    DvStETHDecoderAndSanitizer,
    FluidFTokenDecoderAndSanitizer,
    wSwellUnwrappingDecoderAndSanitizer,
    SymbioticVaultDecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    TreehouseDecoderAndSanitizer,
    ArbitrumNativeBridgeDecoderAndSanitizer,
    AgglayerDecoderAndSanitizer,
    LineaBridgeDecoderAndSanitizer,
    ResolvDecoderAndSanitizer,
    GearboxDecoderAndSanitizer
{
    constructor(
        address _uniswapV4PositionManager,
        address _uniswapV3NonFungiblePositionManager,
        address _odosRouter,
        address _dvStETHVault
    )
        UniswapV4DecoderAndSanitizer(_uniswapV4PositionManager)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
        DvStETHDecoderAndSanitizer(_dvStETHVault)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================

    function finalizeWithdrawalTransaction(DecoderCustomTypes.WithdrawalTransaction calldata _tx)
        external
        pure
        override(StandardBridgeDecoderAndSanitizer, LidoStandardBridgeDecoderAndSanitizer)
        returns (bytes memory sensitiveArguments)
        {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
        }

    function proveWithdrawalTransaction(
        DecoderCustomTypes.WithdrawalTransaction calldata _tx,
        uint256,
        DecoderCustomTypes.OutputRootProof calldata,
        bytes[] calldata
    )
        external
        pure
        override(StandardBridgeDecoderAndSanitizer, LidoStandardBridgeDecoderAndSanitizer)
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

    function approve(address token, address spender, uint160, uint48)
        external
        pure
        override(UniswapV4DecoderAndSanitizer, Permit2DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token, spender);
    }

    function redeem(uint256, address receiver, address owner, uint256)
        external
        pure
        override(ResolvDecoderAndSanitizer, FluidFTokenDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    function withdraw(uint256, address receiver, address owner)
        external
        pure
        override(ERC4626DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    function withdraw(uint256)
        external
        pure
        override(BalancerV2DecoderAndSanitizer, CurveDecoderAndSanitizer, GearboxDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer, ResolvDecoderAndSanitizer)
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

    function deposit() external pure override(NativeWrapperDecoderAndSanitizer, EtherFiDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function deposit(uint256, address receiver)
        external
        pure
        override(ERC4626DecoderAndSanitizer, BalancerV3DecoderAndSanitizer, BalancerV2DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    function deposit(address addressParam, uint256)
        external
        pure
        override(SymbioticVaultDecoderAndSanitizer, TreehouseDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(addressParam);
    }

    function deposit(uint256) external pure
        override(GearboxDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

     function wrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function unwrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
