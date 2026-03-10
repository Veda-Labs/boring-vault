// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";


interface ISwapper {
    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) external pure returns (bytes32);
    function getOracle(ERC20 token, address quoteAsset) external view returns (address);
    function approvedRoutes(bytes32 routeId) external view returns (bool);
    function maxSlippageBpsPerRoute(bytes32 routeId) external view returns (uint256);

}
