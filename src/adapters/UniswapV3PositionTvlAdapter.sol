// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {PositionValue, INonfungiblePositionManager, IUniswapV3Pool} from "./libraries/PositionValue.sol";
import {AggregatorV3Interface} from "./libraries/ChainlinkDataFeedLib.sol";

interface INpmOwner {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract UniswapV3PositionTvlAdapter {
    INonfungiblePositionManager public immutable positionManager;
    IUniswapV3Pool public immutable pool;
    uint256 public immutable tokenId;

    address public immutable token0;
    address public immutable token1;
    address public immutable baseToken;

    AggregatorV3Interface public immutable token0UsdFeed;
    AggregatorV3Interface public immutable token1UsdFeed;
    AggregatorV3Interface public immutable baseUsdFeed;

    uint8 public immutable token0Decimals;
    uint8 public immutable token1Decimals;
    uint8 public immutable baseDecimals;

    constructor(
        address _positionManager,
        address _pool,
        uint256 _tokenId,
        address _token0UsdFeed,
        address _token1UsdFeed,
        address _baseToken,
        address _baseUsdFeed
    ) {
        positionManager = INonfungiblePositionManager(_positionManager);
        pool = IUniswapV3Pool(_pool);
        tokenId = _tokenId;

        (,, address _token0, address _token1,,,,,,,,) = positionManager.positions(_tokenId);
        (address p0, address p1) = (_pool0(_pool), _pool1(_pool));
        require(p0 == _token0 && p1 == _token1, "pool/position mismatch");

        token0 = _token0;
        token1 = _token1;
        baseToken = _baseToken;

        token0UsdFeed = AggregatorV3Interface(_token0UsdFeed);
        token1UsdFeed = AggregatorV3Interface(_token1UsdFeed);
        baseUsdFeed = AggregatorV3Interface(_baseUsdFeed);

        token0Decimals = ERC20(_token0).decimals();
        token1Decimals = ERC20(_token1).decimals();
        baseDecimals = ERC20(_baseToken).decimals();
    }

    function _pool0(address p) private view returns (address) {
        (bool ok, bytes memory d) = p.staticcall(abi.encodeWithSignature("token0()"));
        require(ok, "pool.token0");
        return abi.decode(d, (address));
    }

    function _pool1(address p) private view returns (address) {
        (bool ok, bytes memory d) = p.staticcall(abi.encodeWithSignature("token1()"));
        require(ok, "pool.token1");
        return abi.decode(d, (address));
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

    function _assetToBase(uint256 assetAmount, uint8 assetDecimals, AggregatorV3Interface assetUsdFeed)
        internal
        view
        returns (uint256 baseAmount)
    {
        uint256 assetUsd = _getPrice1e18(assetUsdFeed);
        uint256 baseUsd = _getPrice1e18(baseUsdFeed);

        baseAmount = (assetAmount * assetUsd * 10 ** baseDecimals) / (10 ** assetDecimals) / baseUsd;
    }

    /// @dev returns the NFT position value (principal + tokensOwed + uncollected fees) in baseToken units; 0 if user isn't the owner
    function getUserTvl(address user) external view returns (uint256 tvl) {
        if (INpmOwner(address(positionManager)).ownerOf(tokenId) != user) return 0;

        (uint256 amount0, uint256 amount1) = PositionValue.total(positionManager, pool, tokenId);

        tvl =
            _assetToBase(amount0, token0Decimals, token0UsdFeed) + _assetToBase(amount1, token1Decimals, token1UsdFeed);
    }
}
