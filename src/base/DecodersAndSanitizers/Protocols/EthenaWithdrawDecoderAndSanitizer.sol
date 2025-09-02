// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract EthenaWithdrawDecoderAndSanitizer {
    //============================== Ethena Withdraw ===============================

    function cooldownAssets(uint256 /*assets*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to do.
    }

    function cooldownShares(uint256 /*shares*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to do.
    }

    function unstake(address receiver) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }
}
