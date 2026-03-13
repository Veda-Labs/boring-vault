// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";


interface IAdapter {

    struct OrderInfo {
        address settlement;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        bytes32 protocolHash;
    }

    function version() external view returns (uint256);
    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address swapper) external view returns (OrderInfo memory);
    function cancelLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address swapper) external view returns (address target, bytes memory data);
}
