// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract FluidFTokenDecoderAndSanitizer {
    //============================== Fluid FToken ===============================

    function deposit(uint256, /*assets_*/ address receiver_, uint256 /*minAmountOut_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_);
    }

    function mint(uint256, /*shares_*/ address receiver_, uint256 /*maxAssets_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_);
    }

    function withdraw(uint256, /*assets_*/ address receiver_, address owner_, uint256 /*maxSharesBurn_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, owner_);
    }

    function redeem(uint256, /*shares_*/ address receiver_, address owner_, uint256 /*minAmountOut_*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, owner_);
    }
}
