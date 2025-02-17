// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";


abstract contract SpectraDecoderAndSanitizer is 
    BaseDecoderAndSanitizer, 
    ERC4626DecoderAndSanitizer, 
    CurveDecoderAndSanitizer 
{
    //Spectra pools are Curve Pools with 2 coins, sw-ERC4626, and PT
    //functions for interacting with it are already in the Curve Decoder
    //add_liquidity, remove_liquidity

    //============================== Principal Token ===============================
    
    function deposit(uint256, address receiver) external pure override (ERC4626DecoderAndSanitizer, CurveDecoderAndSanitizer) returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver); 
    }
    
    function depositIBT(uint256 /*ibts*/, address receiver) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver); 
    }

     function depositIBT(
        uint256 /*ibts*/,
        address ptReceiver,
        address ytReceiver,
        uint256 /*minShares*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(ptReceiver, ytReceiver); 
    }

    function redeemForIBT(
        uint256 /*shares*/,
        address receiver,
        address owner
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner); 
    }

    function redeemForIBT(
        uint256 /*shares*/,
        address receiver,
        address owner,
        uint256 /*minIbts*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner); 
    }

    function withdrawIBT(
        uint256 /*ibts*/,
        address receiver,
        address owner
    ) external pure returns (bytes memory addressesFound) { 
        addressesFound = abi.encodePacked(receiver, owner); 
    }

   function withdrawIBT(
        uint256 /*ibts*/,
        address receiver,
        address owner,
        uint256 /*maxShares*/
    ) external pure returns (bytes memory addressesFound) {  
        addressesFound = abi.encodePacked(receiver, owner); 
    }

    function updateYield(address _user) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_user); 
    }

    function claimYield(address _receiver, uint256 /*_minAssets*/) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_receiver); 
    }
    
    //============================== Yield Token ===============================
    
    function burn(uint256 /*amount*/) external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    //============================== swTokens ===============================

    function wrap(uint256, /*vaultShares*/ address receiver) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver); 
    }

    function unwrap(uint256, /*vaultShares*/ address receiver, address owner) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner); 
    }
}
