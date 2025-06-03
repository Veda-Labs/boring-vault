// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract LBTCBridgeDecoderAndSanitizer {
    //============================== LBTC Wrapper Bridge ===============================

    function deposit(bytes32 toChain, bytes32 toAddress, uint64 /*amount*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        address toChain0 = address(bytes20(bytes16(toChain)));
        address toChain1 = address(bytes20(bytes16(toChain << 128)));

        address toAddress0 = address(bytes20(bytes16(toAddress)));
        address toAddress1 = address(bytes20(bytes16(toAddress << 128)));

        addressesFound = abi.encodePacked(toChain0, toChain1, toAddress0, toAddress1);
    }
}
