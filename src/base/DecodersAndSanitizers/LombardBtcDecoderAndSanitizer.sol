// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {BalancerV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {AuraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AuraDecoderAndSanitizer.sol";
import {ConvexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {GearboxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GearboxDecoderAndSanitizer.sol";
import {PendleRouterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {EigenLayerLSTStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {SwellSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SwellSimpleStakingDecoderAndSanitizer.sol";
import {ZircuitSimpleStakingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ZircuitSimpleStakingDecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";
import {ArbitrumNativeBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ArbitrumNativeBridgeDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {CompoundV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CompoundV3DecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {MorphoRewardsDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/MorphoRewardsDecoderAndSanitizer.sol"; 
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol"; 
import {LombardBTCMinterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LombardBtcMinterDecoderAndSanitizer.sol";
import {BTCNMinterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BTCNMinterDecoderAndSanitizer.sol";
import {MorphoRewardsDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/MorphoRewardsDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {ResolvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ResolvDecoderAndSanitizer.sol";
import {ConvexFXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexFXDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {LBTCBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LBTCBridgeDecoderAndSanitizer.sol"; 
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol"; 
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SyrupDecoderAndSanitizer.sol"; 
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol"; 
import {SkyMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SkyMoneyDecoderAndSanitizer.sol"; 
import {DeriveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DeriveDecoderAndSanitizer.sol"; 


contract LombardBtcDecoderAndSanitizer is
    UniswapV3DecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    CurveDecoderAndSanitizer,
    AuraDecoderAndSanitizer,
    ConvexDecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    GearboxDecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    EigenLayerLSTStakingDecoderAndSanitizer,
    SwellSimpleStakingDecoderAndSanitizer,
    ZircuitSimpleStakingDecoderAndSanitizer,
    FluidFTokenDecoderAndSanitizer,
    CCIPDecoderAndSanitizer,
    ArbitrumNativeBridgeDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    CompoundV3DecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    MorphoRewardsDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    ResolvDecoderAndSanitizer,
    ConvexFXDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    LBTCBridgeDecoderAndSanitizer,
    FluidDexDecoderAndSanitizer,
    SyrupDecoderAndSanitizer,
    SpectraDecoderAndSanitizer,
    SkyMoneyDecoderAndSanitizer,
    LombardBTCMinterDecoderAndSanitizer,
    BTCNMinterDecoderAndSanitizer,
    DeriveDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager, address _poolRegistry, address _odosRouter)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        ConvexFXDecoderAndSanitizer(_poolRegistry)
        OdosDecoderAndSanitizer(_odosRouter)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
    /**
     * @notice BalancerV2, ERC4626, and Curve all specify a `deposit(uint256,address)`,
     *         all cases are handled the same way.
     */
    function deposit(uint256, address receiver)
        external
        pure
        override(BalancerV2DecoderAndSanitizer, ERC4626DecoderAndSanitizer, CurveDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    /**
     * @notice Gearbox, Resolv `deposit(uint256)`,
     *         all cases are handled the same way.
     */
    function deposit(uint256 /*amount*/)
        external
        pure
        override(GearboxDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        return addressesFound; 
    }

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

    /**
     * @notice BalancerV2, NativeWrapper, Curve, and Gearbox all specify a `withdraw(uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(uint256)
        external
        pure
        override(
            BalancerV2DecoderAndSanitizer,
            CurveDecoderAndSanitizer,
            NativeWrapperDecoderAndSanitizer,
            GearboxDecoderAndSanitizer,
            ResolvDecoderAndSanitizer,
            ConvexFXDecoderAndSanitizer
        )
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    /**
     * @notice ZircuitSimpleStaking, CompoundV3 both specify a `withdraw(address,uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(address a, uint256)
        external
        pure
        override(ZircuitSimpleStakingDecoderAndSanitizer, CompoundV3DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(a);
    }
    
    /**
     * @notice Spectra, FluidFToken both specify a `withdraw(uint256,address,address,uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(
        uint256, /*assets_*/ 
        address receiver_, 
        address owner_, 
        uint256 /*maxSharesBurn_*/ 
    ) external pure override (FluidFTokenDecoderAndSanitizer, SpectraDecoderAndSanitizer) returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver_, owner_); 
    }

    /**
     * @notice Aura, and Convex all specify a `getReward(address,bool)`,
     *         all cases are handled the same way.
     */
    function getReward(address _addr, bool)
        external
        pure
        override(AuraDecoderAndSanitizer, ConvexDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_addr);
    }

    /**
     * @notice BalancerV2, NativeWrapper, Curve, and Gearbox all specify a `withdraw(uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(address _token, uint256, /*_amount*/ address _receiver)
        external
        pure
        override(AaveV3DecoderAndSanitizer, SwellSimpleStakingDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token, _receiver);
    }
    
    /**
     * @notice Resolv, and FluidFToken all specify a `redeem(uint256,address,address,uint256)`,
     *         all cases are handled the same way.
     */
    function redeem(uint256, address a, address b, uint256)
        external
        pure
        override(FluidFTokenDecoderAndSanitizer, ResolvDecoderAndSanitizer, SpectraDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(a, b); 
    }

    function wrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function unwrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    /**
     * @notice UniswapV3, and Spectra both specify a `burn(uint256)`,
     *         all cases are handled the same way.
     */
    function burn(uint256 /*amount*/) external pure override(UniswapV3DecoderAndSanitizer, SpectraDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}
