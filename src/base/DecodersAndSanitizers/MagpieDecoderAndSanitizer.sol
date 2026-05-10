// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";

abstract contract MagpieDecoderAndSanitizer is BaseDecoderAndSanitizer {
    /// @dev address of the fly DexAggregator
    address internal immutable magpieRouter;

    constructor(address _magpieRouter) {
        magpieRouter = _magpieRouter;
    }

    function swapWithBackendSignature(
        bytes calldata /*pathDefinition*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        address toAddress;
        address fromAssetAddress;
        address toAssetAddress;

        assembly {
            toAddress := shr(96, calldataload(72)) // toAddress
            fromAssetAddress := shr(96, calldataload(92)) // fromAssetAddress
            toAssetAddress := shr(96, calldataload(112)) // toAssetAddress
        }

        addressesFound = abi.encodePacked(fromAssetAddress, toAssetAddress, toAddress);
    }
}
