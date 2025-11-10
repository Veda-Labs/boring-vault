// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract TellerDecoderAndSanitizer {
    //============================== ERRORS ===============================
    error TellerDecoderAndSanitizer__BridgeWildCardLengthMustBe32Bytes();

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

    function deposit(address depositAsset, uint256, /*depositAmount*/ uint256, /*minimumMint*/ address referrer)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(depositAsset, referrer);
    }

    function withdraw(address withdrawAsset, uint256, /*shareAmount*/ uint256 /*minimumAssets*/, address to)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(withdrawAsset, to);
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
    function bridge(
        uint96, /*shareAmount*/
        address to,
        bytes calldata bridgeWildCard,
        address feeToken,
        uint256 /*maxFee*/
    ) external pure virtual returns (bytes memory addressesFound) {
        if (bridgeWildCard.length != 32) revert TellerDecoderAndSanitizer__BridgeWildCardLengthMustBe32Bytes();

        address bridgeWildCard0;
        assembly {
            // Allocate memory
            let memPtr := mload(0x40)
            calldatacopy(memPtr, bridgeWildCard.offset, 32)
            bridgeWildCard0 := mload(memPtr)
        }

        bridgeWildCard0 = address(uint160(bridgeWildCard0));

        addressesFound = abi.encodePacked(to, bridgeWildCard0, feeToken);
    }

    function depositAndBridge(
        address depositAsset,
        uint256, /*depositAmount*/
        uint256, /*minimumMint*/
        address to,
        bytes calldata bridgeWildCard,
        address feeToken,
        uint256 /*maxFee*/
    ) external pure virtual returns (bytes memory addressesFound) {
        if (bridgeWildCard.length != 32) revert TellerDecoderAndSanitizer__BridgeWildCardLengthMustBe32Bytes();

        address bridgeWildCard0;
        assembly {
            // Allocate memory
            let memPtr := mload(0x40)
            calldatacopy(memPtr, bridgeWildCard.offset, 32)
            bridgeWildCard0 := mload(memPtr)
        }
        bridgeWildCard0 = address(uint160(bridgeWildCard0));

        addressesFound = abi.encodePacked(depositAsset, to, bridgeWildCard0, feeToken);
    }

    function depositAndBridge(
        address depositAsset,
        uint256, /*depositAmount*/
        uint256, /*minimumMint*/
        address to,
        bytes calldata bridgeWildCard,
        address feeToken,
        uint256, /*maxFee*/
        address referrer
    ) external pure virtual returns (bytes memory addressesFound) {
        if (bridgeWildCard.length != 32) revert TellerDecoderAndSanitizer__BridgeWildCardLengthMustBe32Bytes();

        address bridgeWildCard0;
        assembly {
            // Allocate memory
            let memPtr := mload(0x40)
            calldatacopy(memPtr, bridgeWildCard.offset, 32)
            bridgeWildCard0 := mload(memPtr)
        }
        bridgeWildCard0 = address(uint160(bridgeWildCard0));

        addressesFound = abi.encodePacked(depositAsset, to, bridgeWildCard0, feeToken, referrer);
    }
}
