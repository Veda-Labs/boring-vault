// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "./Protocols/AaveV3DecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "./Protocols/UniswapV3DecoderAndSanitizer.sol";
import {BalancerV2DecoderAndSanitizer} from "./Protocols/BalancerV2DecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "./Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "./Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "./Protocols/CurveDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "./Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {PendleRouterDecoderAndSanitizer} from "./Protocols/PendleRouterDecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "./Protocols/CCIPDecoderAndSanitizer.sol";
import {InfiniDecoderAndSanitizer} from "./Protocols/InfiniDecoderAndSanitizer.sol";
import {SiloDecoderAndSanitizer} from "./Protocols/SiloDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "./Protocols/OdosDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "./Protocols/OneInchDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "./Protocols/OFTDecoderAndSanitizer.sol";
import {MagpieDecoderAndSanitizer} from "./MagpieDecoderAndSanitizer.sol";
import {CapDecoderAndSanitizer} from "./Protocols/CapDecoderAndSanitizer.sol";
import {
    MorphoV1FlashLoanAdapterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/MorphoV1FlashLoanAdapterDecoderAndSanitizer.sol";

contract EthereumUsdStrategyDecoderAndSanitizer is
    UniswapV3DecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    CurveDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer,
    CCIPDecoderAndSanitizer,
    InfiniDecoderAndSanitizer,
    SiloDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    MagpieDecoderAndSanitizer,
    CapDecoderAndSanitizer,
    MorphoV1FlashLoanAdapterDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager, address _odosRouter, address _magpieRouter)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
        MagpieDecoderAndSanitizer(_magpieRouter)
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
     * @notice NativeWrapper specifies a `deposit()`,
     *         all cases are handled the same way.
     */
    function deposit() external pure override(NativeWrapperDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    /**
     * @notice NativeWrapper specifies a `withdraw(uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(uint256)
        external
        pure
        override(BalancerV2DecoderAndSanitizer, CurveDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
