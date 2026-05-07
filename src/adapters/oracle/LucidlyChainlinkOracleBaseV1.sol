// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {ChainlinkDataFeedLib, AggregatorV3Interface} from "../libraries/ChainlinkDataFeedLib.sol";

/// @title LucidlyChainlinkOracleBaseV1
/// @author Lucidly Labs
/// @notice Lucidly Strategies oracle contract base using Chainlink-compliant feeds.
abstract contract LucidlyChainlinkOracleBaseV1 {
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    AggregatorV3Interface public immutable BASE_FEED_1;
    AggregatorV3Interface public immutable BASE_FEED_2;
    uint256 public immutable SCALE_FACTOR;
    uint8 public immutable OUTPUT_DECIMALS;
    string private _description;

    /// @param baseFeed1 1st chainlink feed. address zero if price = 1
    /// @param baseFeed2 2nd chainlink feed. Address zero if price = 1
    /// @param baseAmountDecimals decimals of the base token (the vault share token, or the token itself if no vault)
    /// @param outputDecimals desired output decimals (e.g., 8 to match chainlink convention)
    constructor(
        AggregatorV3Interface baseFeed1,
        AggregatorV3Interface baseFeed2,
        uint256 baseAmountDecimals,
        uint8 outputDecimals,
        string memory _oracleDescription
    ) {
        BASE_FEED_1 = baseFeed1;
        BASE_FEED_2 = baseFeed2;
        OUTPUT_DECIMALS = outputDecimals;
        _description = _oracleDescription;

        // answer = (baseAmount * feed1 * feed2) / SCALE_FACTOR
        // SCALE_FACTOR = 10**(baseAmountDecimals + feed1Decimals + feed2Decimals - outputDecimals);
        SCALE_FACTOR = 10 ** (baseAmountDecimals + baseFeed1.getDecimals() + baseFeed2.getDecimals() - outputDecimals);
    }

    /// @notice returns the share-to-base amount the oracle multiplies into the feed
    /// @dev must be denominated with `baseAmountDecimals`
    function _getBaseAmount() internal view virtual returns (uint256);

    function decimals() external view returns (uint8) {
        return OUTPUT_DECIMALS;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert("not implemented");
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        uint256 baseAmount = _getBaseAmount();

        uint256 updatedAt = type(uint256).max;
        if (address(BASE_FEED_1) != address(0)) {
            (,,, uint256 ua1,) = BASE_FEED_1.latestRoundData();
            if (ua1 < updatedAt) updatedAt = ua1;
        }
        if (address(BASE_FEED_2) != address(0)) {
            (,,, uint256 ua2,) = BASE_FEED_2.latestRoundData();
            if (ua2 < updatedAt) updatedAt = ua2;
        }
        if (updatedAt == type(uint256).max) updatedAt = block.timestamp;

        uint256 priceRaw = baseAmount * BASE_FEED_1.getPrice() * BASE_FEED_2.getPrice();
        uint256 answerRaw = priceRaw / SCALE_FACTOR;
        require(answerRaw <= uint256(type(int256).max), "answer overflow");
        int256 answer = int256(answerRaw);

        return (0, answer, 0, updatedAt, 0);
    }
}
