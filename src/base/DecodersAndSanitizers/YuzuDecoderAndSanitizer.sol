// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract YuzuDecoderAndSanitizer is ERC4626DecoderAndSanitizer, BaseDecoderAndSanitizer {
    //======================== yzUSD  ==============================

    // Covered by by parent ERC4626 decoder
    /*
    function deposit(uint256 assets, address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver);
    }
    */

    function createRedeemOrder(uint256 tokens, address receiver, address owner)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(receiver, owner);
    }

    function finalizeRedeemOrder(uint256 orderId) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function cancelRedeemOrder(uint256 orderId) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //======================== syzUSD  =============================

    // Covered by by parent ERC4626 decoder
    /*
    function deposit(uint256 assets, address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver);
    }
    */

    function initiateRedeem(uint256 shares, address receiver, address owner)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(receiver, owner);
    }

    function initiateRedeemWithSlippage(uint256 shares, address receiver, address owner, uint256 minAssets)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(receiver, owner);
    }

    function finalizeRedeem(uint256 orderId) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
