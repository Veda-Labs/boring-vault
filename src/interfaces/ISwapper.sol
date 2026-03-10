// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

interface ISwapper {
    function getRouteId(address tokenIn, address tokenOut) external pure returns (bytes32);
    function approvedRoutes(bytes32 routeId) external view returns (bool);

}
