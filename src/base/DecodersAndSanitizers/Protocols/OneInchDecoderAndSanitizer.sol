// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract OneInchDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error OneInchDecoderAndSanitizer__PermitNotSupported();

    //============================== ONEINCH ===============================

    function swap(
        address executor,
        DecoderCustomTypes.SwapDescription calldata desc,
        bytes calldata permit,
        bytes calldata
    ) external pure returns (bytes memory addressesFound) {
        if (permit.length > 0) revert OneInchDecoderAndSanitizer__PermitNotSupported();
        addressesFound = abi.encodePacked(executor, desc.srcToken, desc.dstToken, desc.srcReceiver, desc.dstReceiver);
    }

    function uniswapV3Swap(uint256, uint256, uint256[] calldata pools)
        external
        pure
        returns (bytes memory addressesFound)
    {
        for (uint256 i; i < pools.length; ++i) {
            addressesFound = abi.encodePacked(addressesFound, uint160(pools[i]));
        }
    }
}
