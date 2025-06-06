// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {EthenaWithdrawDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EthenaWithdrawDecoderAndSanitizer.sol";

abstract contract LevelDecoderAndSanitizer is BaseDecoderAndSanitizer, ERC4626DecoderAndSanitizer, EthenaWithdrawDecoderAndSanitizer {

    //============================== LevelMinting ===============================
    
    /// @dev main entry point for minting (removed in V2)
    function mintDefault(DecoderCustomTypes.LevelOrderV2 memory order) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(order.beneficiary, order.collateral_asset); 
    }
    
    /// @dev new entry point for minting lvlUSD
    function mint(DecoderCustomTypes.LevelOrderV2 memory order) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(order.beneficiary, order.collateral_asset); 
    }

    function initiateRedeem(address asset, uint256 /*lvlUsdAmount*/, uint256 /*minAssetamount*/) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset); 
    }
    
    function completeRedeem(address asset, address beneficiary) external pure virtual returns (bytes memory addressesFound) {
        //this is checked by Level, so if a unsupported token is passed the call will fail, but we sanitize for completeness 
        addressesFound = abi.encodePacked(asset, beneficiary); 
    }
    
    /// @dev only callable if `cooldownDuration` is 0, but included for completeness
    function redeem(DecoderCustomTypes.LevelOrder memory order) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(order.benefactor, order.beneficiary, order.collateral_asset); 
    } 

    //============================== slvlUSD ===============================
    /// @dev compliant with ERC4626 only if `cooldownDuration` is 0, otherwise `cooldownAssets()` or `cooldownShares()` must be used in conjunction with `unstake()`
    
    //function cooldownAssets(uint256 /*assets*/) external pure virtual returns (bytes memory addressesFound) {
    //    return addressesFound; 
    //}

    //function cooldownShares(uint256 /*shares*/) external pure virtual returns (bytes memory addressesFound) {
    //    return addressesFound; 
    //} 

    //function unstake(address receiver) external pure virtual returns (bytes memory addressesFound) {
    //    addressesFound = abi.encodePacked(receiver); 
    //}
}
  
