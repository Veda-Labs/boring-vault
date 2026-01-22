// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract YieldBasisDecoderAndSanitizer is ERC4626DecoderAndSanitizer, BaseDecoderAndSanitizer {

    //=============== YB Leveraged Liquidity (LT.vy) ===============

    function deposit(uint256 assets, uint256 debt, uint256 min_shares) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdraw(uint256 shares, uint256 min_assets) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //====================== Liquidity Gauge =======================

    // no restriction on reward address as we want to be able to claim all reward tokens
    function claim(address reward) external pure returns (bytes memory addressesFound) {
        return addressesFound;
    }

    // other required ERC4626 methods provided by parent contract

}
