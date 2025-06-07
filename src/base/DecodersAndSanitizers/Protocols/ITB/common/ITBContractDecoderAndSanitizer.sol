// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

import "./WithdrawableDecoderAndSanitizer.sol";
import "./Ownable2StepDecoderAndSanitizer.sol";

/// @title Decoder and sanitizer for ITBContract
/// @author IntoTheBlock Corp
abstract contract ITBContractDecoderAndSanitizer is WithdrawableDecoderAndSanitizer, Ownable2StepDecoderAndSanitizer {
    function approveToken(address _token, address _guy, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_token, _guy);
    }

    function revokeToken(address _token, address _guy) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_token, _guy);
    }
}
