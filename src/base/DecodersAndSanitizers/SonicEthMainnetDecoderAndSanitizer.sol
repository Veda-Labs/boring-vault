// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {SonicGatewayDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SonicGatewayDecoderAndSanitizer.sol";
import {MorphoRewardsDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/MorphoRewardsDecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {GearboxDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GearboxDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {FluidRewardsClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidRewardsClaimingDecoderAndSanitizer.sol";

contract SonicEthMainnetDecoderAndSanitizer is
    UniswapV3DecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    FluidFTokenDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    FluidDexDecoderAndSanitizer,
    SonicGatewayDecoderAndSanitizer,
    MorphoRewardsDecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    GearboxDecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    FluidRewardsClaimingDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager, address _odosRouter)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
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

    function wrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function unwrap(uint256)
        external
        pure
        override(EtherFiDecoderAndSanitizer, LidoDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdraw(uint256)
        external
        pure
        override(NativeWrapperDecoderAndSanitizer, GearboxDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
