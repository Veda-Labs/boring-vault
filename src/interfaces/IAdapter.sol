// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";


interface IAdapter {
    function version() external view returns (uint256);
    function swap(BoringSwapper.SwapConfig calldata swapConfig) external view returns (address, address, uint256, uint256);
}
