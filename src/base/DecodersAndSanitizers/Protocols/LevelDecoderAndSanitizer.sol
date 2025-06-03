// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {EthenaWithdrawDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/EthenaWithdrawDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract LevelDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    EthenaWithdrawDecoderAndSanitizer
{
    //============================== LevelMinting ===============================

    /// @dev main entry point for minting
    function mintDefault(DecoderCustomTypes.LevelOrder memory order)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        //(/*orderType*/, address benefactor, address beneficiary, address collateralAsset, /*collateralAmount*/, /*lvlUsdAmount*/) = abi.decode

        addressesFound = abi.encodePacked(order.benefactor, order.beneficiary, order.collateral_asset);
    }

    /// @dev if for some reason, the default route ever broke, `mint()` can be used for a custom route
    /// this is highly unlikely, but is included (just in case)
    function mint(DecoderCustomTypes.LevelOrder memory order, DecoderCustomTypes.Route memory route)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(order.benefactor, order.beneficiary, order.collateral_asset);

        for (uint256 i = 0; i < route.addresses.length;) {
            addressesFound = abi.encodePacked(addressesFound, route.addresses[i]);

            unchecked {
                i++;
            }
        }
    }

    function initiateRedeem(DecoderCustomTypes.LevelOrder memory order)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(order.benefactor, order.beneficiary, order.collateral_asset);
    }

    function completeRedeem(address collateralToken) external pure virtual returns (bytes memory addressesFound) {
        //this is checked by Level, so if a unsupported token is passed the call will fail, but we sanitize for completeness
        addressesFound = abi.encodePacked(collateralToken);
    }

    /// @dev only callable if `cooldownDuration` is 0, but included for completeness
    function redeem(DecoderCustomTypes.LevelOrder memory order)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
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
