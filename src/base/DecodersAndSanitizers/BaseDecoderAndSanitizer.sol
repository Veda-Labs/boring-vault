// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract BaseDecoderAndSanitizer {
    error BaseDecoderAndSanitizer__FunctionSelectorNotSupported();
    //============================== IMMUTABLES ===============================

    function approve(address spender, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }

    function transfer(address _to, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_to);
    }

    function claimFees(address feeAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(feeAsset);
    }

    function claimYield(address yieldAsset) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(yieldAsset);
    }

    function withdrawNonBoringToken(address token, uint256 /*amount*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token);
    }

    function withdrawNativeFromDrone() external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== FALLBACK ===============================
    /**
     * @notice The purpose of this function is to revert with a known error,
     *         so that during merkle tree creation we can verify that a
     *         leafs decoder and sanitizer implments the required function
     *         selector.
     */
    fallback() external {
        revert BaseDecoderAndSanitizer__FunctionSelectorNotSupported();
    }
}
