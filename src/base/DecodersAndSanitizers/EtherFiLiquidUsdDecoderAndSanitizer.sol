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
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {EthenaWithdrawDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EthenaWithdrawDecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {CompoundV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CompoundV3DecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {KarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KarakDecoderAndSanitizer.sol";
import {UsualMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UsualMoneyDecoderAndSanitizer.sol";
import {MorphoRewardsDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/MorphoRewardsDecoderAndSanitizer.sol";
import {TermFinanceDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/TermFinanceDecoderAndSanitizer.sol";
import {SpectraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SpectraDecoderAndSanitizer.sol";
import {ResolvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ResolvDecoderAndSanitizer.sol";
import {LevelDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LevelDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SyrupDecoderAndSanitizer.sol";
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol";
import {ElixirClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ElixirClaimingDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {KingClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/KingClaimingDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";

contract EtherFiLiquidUsdDecoderAndSanitizer is
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
    LidoDecoderAndSanitizer,
    EthenaWithdrawDecoderAndSanitizer,
    FluidFTokenDecoderAndSanitizer,
    CompoundV3DecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    KarakDecoderAndSanitizer,
    UsualMoneyDecoderAndSanitizer,
    MorphoRewardsDecoderAndSanitizer,
    TermFinanceDecoderAndSanitizer,
    SpectraDecoderAndSanitizer,
    ResolvDecoderAndSanitizer,
    LevelDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    SyrupDecoderAndSanitizer,
    BalancerV3DecoderAndSanitizer,
    ElixirClaimingDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    FluidDexDecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    KingClaimingDecoderAndSanitizer,
    OFTDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager, address _odosRouter)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================
    /**
     * @notice Teller and Karak specify a `deposit(address,uint256,uint256)`,
     *         all cases are handled the same way.
     */
    function deposit(address vaultOrAsset, uint256, uint256)
        external
        pure
        override(TellerDecoderAndSanitizer, KarakDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(vaultOrAsset);
    }

    /**
     * @notice BalancerV2/3, ERC4626, Spectra, and Curve all specify a `deposit(uint256,address)`,
     *         all cases are handled the same way.
     */
    function deposit(uint256, address receiver)
        external
        pure
        override(
            BalancerV3DecoderAndSanitizer,
            BalancerV2DecoderAndSanitizer,
            ERC4626DecoderAndSanitizer,
            CurveDecoderAndSanitizer
        )
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    /**
     * @notice Gearbox, Resolv both specify a `deposit(uint256)`,
     *         all cases are handled the same way.
     */
    function deposit(uint256 /*amount*/ )
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
     * @notice BalancerV2, NativeWrapper, Curve, Fluid FToken, and Gearbox all specify a `withdraw(uint256)`,
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
            ResolvDecoderAndSanitizer
        )
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
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
     * @notice EtherFi, and Lido all specify a `wrap(uint256)`,
     *         all cases are handled the same way.
     */
    function wrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    /**
     * @notice EtherFi, and Lido all specify a `unwrap(uint256)`,
     *         all cases are handled the same way.
     */
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
     * @notice Spectra, and UniswapV3 all specify a `burn(uint256)`,
     *         all cases are handled the same way.
     */
    function burn(uint256)
        external
        pure
        override(SpectraDecoderAndSanitizer, UniswapV3DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    /**
     * @notice Spectra, and FluidFToken all specify a `redeem(uint256,address,address,uint256)`,
     *         all cases are handled the same way.
     */
    function redeem(uint256, address a, address b, uint256)
        external
        pure
        override(SpectraDecoderAndSanitizer, FluidFTokenDecoderAndSanitizer, ResolvDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(a, b);
    }

    /**
     * @notice Spectra, and FluidFToken all specify a `withdraw(uint256,address,address,uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(uint256, address a, address b, uint256)
        external
        pure
        override(SpectraDecoderAndSanitizer, FluidFTokenDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(a, b);
    }
}
