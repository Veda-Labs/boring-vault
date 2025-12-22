// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { ERC20 } from "@solmate/tokens/ERC20.sol";

interface PriceRouter {
    function getValue(ERC20 baseAsset, uint256 amount, ERC20 quoteAsset) external view returns (uint256 value);
}
