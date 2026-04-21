// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {AggregatorV3Interface} from "./libraries/interfaces/AggregatorV3Interface.sol";

contract Erc20TvlAdapter {
    address public immutable asset;
    address public immutable base;

    AggregatorV3Interface public immutable assetUsdFeed;
    AggregatorV3Interface public immutable baseUsdFeed;

    uint8 public immutable assetDecimals;
    uint8 public immutable baseDecimals;

    constructor(address _asset, address _assetUsdFeed, address _base, address _baseUsdFeed) {
        asset = _asset;
        base = _base;
        assetUsdFeed = AggregatorV3Interface(_assetUsdFeed);
        baseUsdFeed = AggregatorV3Interface(_baseUsdFeed);
        assetDecimals = ERC20(_asset).decimals();
        baseDecimals = ERC20(_base).decimals();
    }

    function _getPrice1e18(AggregatorV3Interface feed) internal view returns (uint256) {
        (, int256 answer,,,) = feed.latestRoundData();
        require(answer > 0, "invalid price");

        uint8 feedDecimals = feed.decimals();
        uint256 price = uint256(answer);

        if (feedDecimals < 18) return price * (10 ** (18 - feedDecimals));
        if (feedDecimals > 18) return price / (10 ** (feedDecimals - 18));
        return price;
    }

    function _assetToBase(uint256 assetAmount) internal view returns (uint256 baseAmount) {
        uint256 assetUsd = _getPrice1e18(assetUsdFeed);
        uint256 baseUsd = _getPrice1e18(baseUsdFeed);

        baseAmount = (assetAmount * assetUsd * 10 ** baseDecimals) / (10 ** assetDecimals) / baseUsd;
    }

    /// @dev returns user's asset balance valued in base terms
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        uint256 bal = ERC20(asset).balanceOf(_user);
        tvl = _assetToBase(bal);
    }
}
