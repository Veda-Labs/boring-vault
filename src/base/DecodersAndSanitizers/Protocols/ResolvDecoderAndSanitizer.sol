// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

abstract contract ResolvDecoderAndSanitizer is BaseDecoderAndSanitizer, ERC4626DecoderAndSanitizer {
    //============================== UsrExternalRequestManager ===============================

    function requestMint(address _depositTokenAddress, uint256, /*_amount*/ uint256 /*_minMintAmount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(_depositTokenAddress);
    }

    function requestBurn(
        uint256, /*_issueTokenAmount*/
        address _withdrawalTokenAddress,
        uint256 /*_minWithdrawalAmount*/
    ) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(_withdrawalTokenAddress);
    }

    function redeem(
        uint256, /*_amount*/
        address _receiver,
        address _withdrawalTokenAddress,
        uint256 /*_minExpectedAmount*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_receiver, _withdrawalTokenAddress);
    }

    //============================== stUSR ===============================

    function deposit(uint256 /*_usrAmount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdraw(uint256 /*_usrAmount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== wstUSR ===============================

    function wrap(uint256 /*_stUSRAmount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function unwrap(uint256 /*_wstUSRAmount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
