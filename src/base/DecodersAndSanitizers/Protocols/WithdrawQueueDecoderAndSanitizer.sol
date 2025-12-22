// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";

contract WithdrawQueueDecoderAndSanitizer {
    // BoringOnChainQueue.sol
    function requestOnChainWithdraw(address asset, uint128, uint16, uint24)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset);
    }
}
