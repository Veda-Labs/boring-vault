// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract CompoundV3DecoderAndSanitizer {
    //============================== CompoundV3 ===============================

    function supply(address asset, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(asset);
    }

    function withdraw(address asset, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(asset);
    }

    function claim(address comet, address src, bool /*shouldAccrue*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        // Extract sensitive arguments.
        sensitiveArguments = abi.encodePacked(comet, src);
    }
}
