// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
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
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {BalancerV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV3DecoderAndSanitizer.sol";
import {Permit2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Permit2DecoderAndSanitizer.sol";

contract AlphaSTETHDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
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
    LidoStandardBridgeDecoderAndSanitizer,
    BalancerV3DecoderAndSanitizer
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

    function approve(address token, address spender, uint160, /*amount*/ uint48 /*expiraton*/ )
        external
        pure
        override(UniswapV4DecoderAndSanitizer, Permit2DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token, spender);
    }
    function withdraw(uint256) external pure override(NativeWrapperDecoderAndSanitizer, CurveDecoderAndSanitizer) returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
    
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
