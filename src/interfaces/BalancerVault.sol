// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault@939c77e25473dff3ed18fa104f004f7afd13452e — https://macroaudits.com/library/audits/sevenSeas-4
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

interface BalancerVault {
    function flashLoan(address, address[] memory tokens, uint256[] memory amounts, bytes calldata userData) external;
    function swap(
        DecoderCustomTypes.SingleSwap memory singleSwap,
        DecoderCustomTypes.FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external returns (uint256 amountCalculated);
}
