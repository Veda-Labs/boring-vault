// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract InfinifiDecoderAndSanitizer is BaseDecoderAndSanitizer {


    //======================== Enter ==========================

    function mint(address to, uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(to);
    }

    function mintAndStake(address to, uint256 /*amount*/) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(to);
    }

    function stake(address to, uint256 /*receiptTokens*/) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(to);
    }

    //======================== Exit ===========================

    function unstake(address to, uint256 /*stakedTokens*/) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(to);
    }

    function redeem(address to, uint256 /*amount*/, uint256 /*minAssetsOut*/) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(to);
    }

    function claimRedemption() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
