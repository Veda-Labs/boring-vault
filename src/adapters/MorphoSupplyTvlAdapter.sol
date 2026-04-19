// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {IMorpho, MarketParams, Id, Market, Position} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {SharesMathLib} from "../../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {ChainlinkDataFeedLib, AggregatorV3Interface} from "./libraries/ChainlinkDataFeedLib.sol";

contract MorphoSupplyTvlAdapter {
    using MorphoBalancesLib for IMorpho;
    using SharesMathLib for uint256;

    IMorpho public morpho;
    Id public immutable marketId;
    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address public immutable collateralToken;
    address public immutable loanToken;
    address public immutable baseToken;

    AggregatorV3Interface public immutable collateralUsdFeed;
    AggregatorV3Interface public immutable debtUsdFeed;
    AggregatorV3Interface public immutable baseUsdFeed;

    uint8 public immutable collateralDecimals;
    uint8 public immutable loanDecimals;
    uint8 public immutable baseDecimals;

    constructor(
        bytes32 _marketId,
        address _collateralUsdFeed,
        address _debtUsdFeed,
        address _baseUsdFeed,
        address _baseToken
    ) {
        marketId = Id.wrap(_marketId);
        morpho = IMorpho(MORPHO);

        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        collateralToken = marketParams.collateralToken;
        loanToken = marketParams.loanToken;

        collateralUsdFeed = AggregatorV3Interface(_collateralUsdFeed);
        debtUsdFeed = AggregatorV3Interface(_debtUsdFeed);
        baseUsdFeed = AggregatorV3Interface(_baseUsdFeed);
        baseToken = _baseToken;

        collateralDecimals = ERC20(collateralToken).decimals();
        loanDecimals = ERC20(loanToken).decimals();
        baseDecimals = ERC20(_baseToken).decimals();
    }

    function _assetToBase(uint256 assetAmount, uint8 assetDecimals, AggregatorV3Interface assetUsdFeed)
        internal
        view
        returns (uint256 baseAmount)
    {
        uint256 assetUsd = _getPrice1e18(assetUsdFeed);
        uint256 baseUsd = _getPrice1e18(baseUsdFeed);

        // assetAmount * assetUsd / 10^assetDecimals = USD value (1e18 scaled)
        // divide by usdcUsd to get base amount
        // result scaled to base decimals
        baseAmount = (assetAmount * assetUsd * 10 ** baseDecimals) / (10 ** assetDecimals) / baseUsd;
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

    /// @dev should return position value in base terms
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        (uint256 collateral, uint256 debt, uint256 supplied) = getUserPositionValues(_user);
        tvl = (collateral) + supplied - debt;
    }

    /// @dev should return position values in base terms
    function getUserPositionValues(address _user)
        public
        view
        returns (uint256 collateral, uint256 debt, uint256 supplied)
    {
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets, uint256 totalBorrowShares) =
            morpho.expectedMarketBalances(marketParams);

        Position memory userPosition = morpho.position(marketId, _user);

        uint256 collateralInCollateralTokenAmount = userPosition.collateral;
        uint256 suppliedInDebtTokenAmount = userPosition.supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);
        uint256 debtInDebtTokenAmount =
            uint256(userPosition.borrowShares).toAssetsUp(totalBorrowAssets, totalBorrowShares);

        collateral = _assetToBase(collateralInCollateralTokenAmount, collateralDecimals, collateralUsdFeed);
        supplied = _assetToBase(suppliedInDebtTokenAmount, loanDecimals, debtUsdFeed);
        debt = _assetToBase(debtInDebtTokenAmount, loanDecimals, debtUsdFeed);
    }
}
