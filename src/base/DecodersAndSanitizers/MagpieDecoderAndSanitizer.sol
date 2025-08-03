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

            // let hasPermit := gt(shr(248, calldataload(209)), 0)

            // switch hasPermit
            // case 1 {
            //     hasAffiliate := shr(248, calldataload(277))
            //     if eq(hasAffiliate, 1) {
            //         affiliateAddress := shr(96, calldataload(278))
            //     }
            // }
            // default {
            //     hasAffiliate := shr(248, calldataload(210))
            //     if eq(hasAffiliate, 1) {
            //         affiliateAddress := shr(96, calldataload(211))
            //     }
            // }
        }

        addressesFound = abi.encodePacked(fromAssetAddress, toAssetAddress, toAddress);
    }
}
