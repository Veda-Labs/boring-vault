// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface AggregationRouterV5 {
    struct SwapDescription {
        ERC20 srcToken;
        ERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    function swap(address executor, SwapDescription calldata desc, bytes calldata permit, bytes calldata data)
        external
        payable
        returns (uint256 returnAmount, uint256 spentAmount);
}
