// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract TempestDecoderAndSanitizer is BaseDecoderAndSanitizer {

    // ================== Rebalancing Symmetric ==================
    
    // Single-sided deposit
    function deposit(uint256, /*amount*/ address receiver, bool /*checkSlippage*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }
    
    // Multi-sided deposit
    function deposits(uint256[] memory, /*amounts*/ address receiver, bool /*checkSlippage*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    function withdraw(
        uint256 /*assets*/,
        address receiver,
        address owner,
        uint256 /*minimumReceive*/,
        bool /*checkSlippage*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner); 
    }

    function redeem(
      uint256 /*shares*/,
      address receiver,
      address owner,
      uint256 /*minimumReceive*/,
      bool /*checkSlippage*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner); 
    }

    function redeemWithoutSwap(
      uint256 /*shares*/,
      address receiver,
      address owner,
      bool /*checkSlippage*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner); 
    }

    // ================== LST/LRT Arbitrage ==================
    
    function deposit(
        uint256 /*amount*/,
        address receiver,
        bytes memory /*merkleProofs*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver); 
    }
    
    function withdraw(
        uint256 /*assets*/,
        address receiver,
        address owner,
        bytes memory /*merkleProofs*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner); 
    }

    function redeem(
        uint256 /*shares*/,
        address receiver,
        address owner,
        bytes memory /*merkleProofs*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner); 
    }
}
