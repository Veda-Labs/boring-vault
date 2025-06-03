// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract ERC4626DecoderAndSanitizer {
    //============================== ERC4626 ===============================

    function deposit(uint256, address receiver) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function mint(uint256, address receiver) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function withdraw(uint256, address receiver, address owner)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    function redeem(uint256, address receiver, address owner)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver, owner);
    }
}
