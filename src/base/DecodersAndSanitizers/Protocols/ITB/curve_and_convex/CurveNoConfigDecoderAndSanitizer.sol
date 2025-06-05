// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

abstract contract CurveNoConfigDecoderAndSanitizer {
    function addLiquidityAllCoinsAndStake(address _pool, uint256[] memory, address _gauge, uint256)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_pool, _gauge);
    }

    function unstakeAndRemoveLiquidityAllCoins(address _pool, uint256, address _gauge, uint256[] memory)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_pool, _gauge);
    }
}
