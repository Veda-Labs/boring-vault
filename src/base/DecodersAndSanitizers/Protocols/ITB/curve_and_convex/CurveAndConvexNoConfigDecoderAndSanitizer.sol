/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

contract CurveAndConvexNoConfigDecoderAndSanitizer {
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
