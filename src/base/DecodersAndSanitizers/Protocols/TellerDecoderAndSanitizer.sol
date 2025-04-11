// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

abstract contract TellerDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Teller ===============================

    function bulkDeposit(address depositAsset, uint256, /*depositAmount*/ uint256, /*minimumMint*/ address to)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(depositAsset, to);
    }

    function bulkWithdraw(address withdrawAsset, uint256, /*shareAmount*/ uint256, /*minimumAssets*/ address to)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(withdrawAsset, to);
    }

    function deposit(address depositAsset, uint256, /*depositAmount*/ uint256 /*minimumMint*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(depositAsset);
    }

    // BoringOnChainQueue.sol
    function requestOnChainWithdraw(address asset, uint128, uint16, uint24)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset);
    }

    function cancelOnChainWithdraw(DecoderCustomTypes.OnChainWithdraw memory request)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(request.user, request.assetOut);
    }

    function replaceOnChainWithdraw(
        DecoderCustomTypes.OnChainWithdraw memory oldRequest,
        uint16, /*discount*/
        uint24 /*secondsToDeadline*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(oldRequest.user, oldRequest.assetOut);
    }


    // CrossChainTellerWithGenericBridge.sol
    function bridge(uint96 /*shareAmount*/, address to, bytes calldata /*bridgeWildCard*/, address feeToken, uint256 /*maxFee*/) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to, feeToken); 
    } 

    function depositAndBridge(
        address depositAsset,
        uint256 /*depositAmount*/,
        uint256 /*minimumMint*/,
        address to,
        bytes calldata /*bridgeWildCard*/,
        address feeToken,
        uint256 /*maxFee*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(depositAsset, to, feeToken); 
    }
}
