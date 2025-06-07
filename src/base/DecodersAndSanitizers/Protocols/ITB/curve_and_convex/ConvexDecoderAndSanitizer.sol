// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

abstract contract ConvexDecoderAndSanitizer {
    function addLiquidityAllCoinsAndStakeConvex(address _pool, uint256[] memory, uint256 _convex_pool_id, uint256)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_pool, address(uint160(_convex_pool_id)));
    }

    function unstakeAndRemoveLiquidityAllCoinsConvex(address _pool, uint256, uint256 _convex_pool_id, uint256[] memory)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_pool, address(uint160(_convex_pool_id)));
    }
}
