// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {LidoDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LidoDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {FluidFTokenDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidFTokenDecoderAndSanitizer.sol";
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {FluidRewardsClaimingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/FluidRewardsClaimingDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {DvStETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DvStETHDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {LidoStandardBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/LidoStandardBridgeDecoderAndSanitizer.sol";

contract AlphaSTETHDecoderAndSanitizer is
    ERC4626DecoderAndSanitizer,
    LidoDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    UniswapV4DecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    FluidFTokenDecoderAndSanitizer,
    FluidDexDecoderAndSanitizer,
    FluidRewardsClaimingDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    DvStETHDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    LidoStandardBridgeDecoderAndSanitizer
{
    constructor(
        address _uniswapV3NonFungiblePositionManager,
        address _uniswapV4PositionManager,
        address _odosRouter,
        address _dvStETHVault
    )
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        UniswapV4DecoderAndSanitizer(_uniswapV4PositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
        DvStETHDecoderAndSanitizer(_dvStETHVault)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================

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

    function finalizeWithdrawalTransaction(DecoderCustomTypes.WithdrawalTransaction calldata _tx)
        external
        pure
        override(StandardBridgeDecoderAndSanitizer, LidoStandardBridgeDecoderAndSanitizer)
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }
}
