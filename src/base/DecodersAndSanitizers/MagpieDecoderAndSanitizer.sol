// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";

abstract contract MagpieDecoderAndSanitizer is BaseDecoderAndSanitizer {
    // Reference to the OdosRouterV2 contract
    address internal immutable magpieRouter; //temp

    struct SwapData {
        address toAddress;
        address fromAssetAddress;
        address toAssetAddress;
        uint256 deadline;
        uint256 amountOutMin;
        uint256 swapFee;
        uint256 amountIn;
        bool hasPermit;
        bool hasAffiliate;
        address affiliateAddress;
        uint256 affiliateFee;
    }

    constructor(address _magpieRouter) {
        magpieRouter = _magpieRouter;
    }

    function swapWithMagpieSignature(bytes calldata /*pathDefinition*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        address toAddress;
        address fromAssetAddress;
        address toAssetAddress;
        address affiliateAddress;
        bool hasAffiliate;

        assembly {
            toAddress := shr(96, calldataload(72)) // toAddress
            fromAssetAddress := shr(96, calldataload(92)) // fromAssetAddress
            toAssetAddress := shr(96, calldataload(112)) // toAssetAddress
        }

        addressesFound = abi.encodePacked(fromAssetAddress, toAssetAddress, toAddress);
    }
}
