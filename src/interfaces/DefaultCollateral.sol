// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface DefaultCollateral {
    function balanceOf(address account) external view returns (uint256);
    function withdraw(address recipient, uint256 amount) external;
    function deposit(address recipient, uint256 amount) external;
    function asset() external view returns (ERC20);
    function limit() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
