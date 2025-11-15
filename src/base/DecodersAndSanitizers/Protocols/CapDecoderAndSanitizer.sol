// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract CapDecoderAndSanitizer is ERC4626DecoderAndSanitizer {

    //============================== cUSD ===============================
    // note that these cUSD methads have different signatures than the erc4626 methods of the same name used for stcUSD

    function mint(
        address _asset,
        uint256 /*_amountIn*/,
        uint256 /*_minAmountOut*/,
        address _receiver,
        uint256 /*_deadline*/
    ) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(_asset, _receiver);
    }

    function burn(
        address _asset,
        uint256 /*_amountIn*/,
        uint256 /*_minAmountOut*/,
        address _receiver,
        uint256 /*_deadline*/
    ) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(_asset, _receiver);
    }

    function redeem(
        uint256 /*_amountIn*/,
        uint256[] calldata /*_minAmountsOut*/,
        address _receiver,
        uint256 /*_deadline*/
    ) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(_receiver);
    }

    //============================== stcUSD ===============================
    // ERC4626DecoderAndSanitizer

}
