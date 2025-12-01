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
    ResolvDecoderAndSanitizer
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

    /**
     * @notice StandardBridge and LidoStandardBridge both specify finalizeWithdrawalTransaction
     */
    function finalizeWithdrawalTransaction(DecoderCustomTypes.WithdrawalTransaction calldata _tx)
        external
        pure
        override(StandardBridgeDecoderAndSanitizer, LidoStandardBridgeDecoderAndSanitizer)
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

    /**
     * @notice StandardBridge and LidoStandardBridge both specify proveWithdrawalTransaction
     */
    function proveWithdrawalTransaction(
        DecoderCustomTypes.WithdrawalTransaction calldata _tx,
        uint256, /*_l2OutputIndex*/
        DecoderCustomTypes.OutputRootProof calldata, /*_outputRootProof*/
        bytes[] calldata /*_withdrawalProof*/
    )
        external
        pure
        override(StandardBridgeDecoderAndSanitizer, LidoStandardBridgeDecoderAndSanitizer)
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

    /**
     * @notice TellerDecoderAndSanitizer and ERC4626DecoderAndSanitizer both specify a deposit function
     * ERC4626: deposit(uint256,address)
     * Teller: deposit(address,uint256,uint256)
     * These have different signatures so no conflict exists
     */

    /**
     * @notice ERC4626, BalancerV3, and BalancerV2 all specify a `deposit(uint256,address)`,
     *         all cases are handled the same way.
     */
    function deposit(uint256, address receiver)
        external
        pure
        override(ERC4626DecoderAndSanitizer, BalancerV3DecoderAndSanitizer, BalancerV2DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    /**
     * @notice NativeWrapper and EtherFi both specify a `deposit()`.
     */
    function deposit() external pure override(NativeWrapperDecoderAndSanitizer, EtherFiDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    /**
     * @notice NativeWrapper specifies a `withdraw(uint256)`,
     *         this is handled by NativeWrapper.
     */

    /**
     * @notice ERC4626 and BalancerV3 both specify a `redeem(uint256,address,address)`,
     *         all cases are handled the same way.
     */
    function redeem(uint256, address receiver, address owner)
        external
        pure
        override(ERC4626DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    /**
     * @notice ERC4626 and BalancerV3 both specify a `withdraw(uint256,address,address)`,
     *         all cases are handled the same way.
     */
    function withdraw(uint256, address receiver, address owner)
        external
        pure
        override(ERC4626DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    /**
     * @notice ResolvDecoderAndSanitizer and FluidFTokenDecoderAndSanitizer both specify a `redeem(uint256,address,address)`,
     *         all cases are handled the same way.
     */
    function redeem(uint256, address receiver, address owner, uint256)
        external
        pure
        override(ResolvDecoderAndSanitizer, FluidFTokenDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    /**
     * @notice Multiple decoders specify different withdraw functions
     * NativeWrapper: withdraw(uint256)
     * CurveDecoderAndSanitizer: withdraw(uint256)
     * BalancerV2DecoderAndSanitizer: withdraw(uint256)
     * AaveV3: withdraw(address,uint256,address)
     * MorphoBlue: withdraw(MarketParams,uint256,uint256,address,address)
     */
    function withdraw(uint256)
        external
        pure
        override(NativeWrapperDecoderAndSanitizer, CurveDecoderAndSanitizer, BalancerV2DecoderAndSanitizer, ResolvDecoderAndSanitizer)
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

    // MorphoBlue withdraw function is not virtual, so we don't override it

    /**
     * @notice Multiple decoders specify approve functions
     * BaseDecoderAndSanitizer: approve(address,uint256) - not virtual
     * UniswapV4DecoderAndSanitizer: approve(address,address,uint160,uint48)
     */
    // BaseDecoderAndSanitizer approve is not virtual, so we don't override it

    function approve(address token, address spender, uint160, uint48)
        external
        pure
        override(UniswapV4DecoderAndSanitizer, Permit2DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token, spender);
    }

    /**
     * @notice SymbioticVault and Treehouse both specify deposit(address,uint256)
     * SymbioticVault: deposit(address onBehalfOf, uint256)
     * Treehouse: deposit(address _asset, uint256)
     */
    function deposit(address addressParam, uint256)
        external
        pure
        override(SymbioticVaultDecoderAndSanitizer, TreehouseDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(addressParam);
    }

    /**
     * @notice EtherFi and Lido both specify wrap(uint256)
     */
    function wrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    /**
     * @notice EtherFi and Lido both specify unwrap(uint256)
     */
    function unwrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
