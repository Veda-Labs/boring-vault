// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface IFeeRegistry {
    function swapperActive(address swapper) external view returns (bool);
    function getFee(address swapper, address tokenIn, address tokenOut) external view returns (uint16 feeBps);
    function getFeeRecipient(address swapper, ERC20 feeToken) external view returns (address feeRecipient);
    function getCancelFeeDelay(address swapper) external view returns (uint256);
}
