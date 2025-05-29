// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {ConvexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {PendleRouterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {BTCNMinterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCNMinterDecoderAndSanitizer.sol";
import {MorphoRewardsWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsWrapperDecoderAndSanitizer.sol";
import {MorphoRewardsMerkleClaimerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoRewardsMerkleClaimerDecoderAndSanitizer.sol";
import {ResolvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ResolvDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SyrupDecoderAndSanitizer.sol";
import {SkyMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SkyMoneyDecoderAndSanitizer.sol";
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol";
import {ConvexFXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexFxDecoderAndSanitizer.sol";






contract LiquidBtcDecoderAndSanitizer is
    UniswapV3DecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    ConvexDecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    BTCNMinterDecoderAndSanitizer,
    MorphoRewardsWrapperDecoderAndSanitizer,
    MorphoRewardsMerkleClaimerDecoderAndSanitizer,
    ResolvDecoderAndSanitizer,
    CurveDecoderAndSanitizer,
    FluidDexDecoderAndSanitizer,
    SyrupDecoderAndSanitizer,
    SkyMoneyDecoderAndSanitizer,
    SpectraDecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    ConvexFXDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager, address _odosRouter, address _poolRegistry)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
        ConvexFXDecoderAndSanitizer(_poolRegistry)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
    /**
     * @notice EtherFi, NativeWrapper all specify a `deposit()`,
     *         all cases are handled the same way.
     */
    function deposit()
        external
        pure
        override(EtherFiDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdraw(uint256) external pure override( NativeWrapperDecoderAndSanitizer, ResolvDecoderAndSanitizer, CurveDecoderAndSanitizer, ConvexFXDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function unwrap(uint256) external pure override(EtherFiDecoderAndSanitizer, ResolvDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function wrap(uint256) external pure override(EtherFiDecoderAndSanitizer, ResolvDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function deposit(uint256, address) external pure override(CurveDecoderAndSanitizer, ERC4626DecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeem(
        uint256 /*shares*/,
        address,
        address,
        uint256 /*minAssets*/
    ) external pure override(ResolvDecoderAndSanitizer, SpectraDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function burn(uint256) external pure override( SpectraDecoderAndSanitizer, UniswapV3DecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
