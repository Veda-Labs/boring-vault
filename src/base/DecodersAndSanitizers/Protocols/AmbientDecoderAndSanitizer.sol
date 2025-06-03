// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract AmbientDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error AmbientDecoderAndSanitizer__UnsupportedCallPath();

    //============================== CrocSwapDex ===============================

    // NOTE: this is disabled on ETH and Scroll according to their docs and swaps should be routed through either the Router or using `userCmd()`
    // NOTE: the router exposes the same abi as the function below, just at a higher gas cost.
    function swap(
        address base,
        address quote,
        uint256, /*poolIdx*/
        bool, /*isBuy*/
        bool, /*inBaseQty*/
        uint128, /*qty*/
        uint16, /*tip*/
        uint128, /*limitPrice*/
        uint128, /*minOut*/
        uint8 /*reserveFlags*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(base, quote);
    }

    function userCmd(uint16 callpath, bytes calldata cmd) external pure virtual returns (bytes memory addressesFound) {
        // NOTE: LP warmpath seems to be 128 (on FE execution) or 2 (https://github.com/CrocSwap/CrocSwap-protocol/blob/33f339d014d21c47b1e20c9c998d1c12d85976f7/contracts/mixins/StorageLayout.sol#L184) in the contract itself.
        // swap is 1, knockout is 7, confirmed by FE execution.
        //
        //
        // This should be all the functionality a strategist would need
        if (callpath == 1) {
            (
                address base,
                address quote,
                /*uint256 poolIdx*/
                ,
                /*bool, isBuy*/
                ,
                /*bool, /*inBaseQty*/
                ,
                /*uint128, /*qty*/
                ,
                /*uint16, /*tip*/
                ,
                /*uint128, /*limitPrice*/
                ,
                /*uint128, /*minOut*/
                ,
                /*uint8 /*reserveFlags*/
            ) = abi.decode(cmd, (address, address, uint256, bool, bool, uint128, uint16, uint128, uint128, uint8));

            addressesFound = abi.encodePacked(base, quote);
        } else if (callpath == 128 || callpath == 2) {
            //handle concentrated LP positions and ambient (full range) positions
            (
                /*uint8 code*/
                ,
                address base,
                address quote,
                /*uint256 poolIdx*/
                ,
                /*int24 bidTick*/
                ,
                /*int24 askTick*/
                ,
                /*uint128 liq*/
                ,
                /*uint128 limitLower*/
                ,
                /*uint128 limitHigher*/
                ,
                /*uint8 reserveFlags*/
                ,
                address lpConduit
            ) = abi.decode(
                cmd, (uint8, address, address, uint256, int24, int24, uint128, uint128, uint128, uint8, address)
            );

            addressesFound = abi.encodePacked(base, quote, lpConduit);
        } else if (callpath == 7) {
            //knockout position
            //args are further decoded into ((uint128 qty, bool insideMid) = abi.decode(args, (uint128,bool))); and not needed for sanitation
            (
                /*uint8 code*/
                ,
                address base,
                address quote,
                /*uint256 poolIdx*/
                ,
                /*int24 idTick*/
                ,
                /*int24 askTick*/
                ,
                /*bool isBid*/
                ,
                /*uint8 reserveFlags*/
                ,
                /*bytes memory args*/
            ) = abi.decode(cmd, (uint8, address, address, uint256, int24, int24, bool, uint8, bytes));

            addressesFound = abi.encodePacked(base, quote);
        } else {
            revert AmbientDecoderAndSanitizer__UnsupportedCallPath();
        }
    }
}
