// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";


/// @dev some Spectra contracts implement some of the ERC4626 standard, some revert on calling. Ex. A contract might implement `deposit()` and `withdraw()`, but not `mint()` or `redeem()`. `wrap()` and `unwrap()` should therefore be used most of the time. 
abstract contract SpectraDecoderAndSanitizer is BaseDecoderAndSanitizer {

    //============================== Principal Token ===============================
    
    function deposit(uint256 /*amount*/, address receiver) external pure virtual returns (bytes memory addressesFound) {
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

    //============================== Pool Functions ===============================
    
    function exchange(uint256 /*i*/, uint256 /*j*/, uint256 /*dx*/, uint256 /*dy*/) external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    } 

    function add_liquidity(uint256[2] memory /*amounts*/, uint256 /*minOut*/) external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function remove_liquidity(uint256 /*lpAmount*/, uint256[2] memory /*minAmountsOut*/) external pure returns (bytes memory addressesFound) {
        return addressesFound; 
    } 
}
