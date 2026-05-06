// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IMorpho, MarketParams, Id, Position} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {SharesMathLib} from "../../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {ChainlinkDataFeedLib, AggregatorV3Interface} from "./libraries/ChainlinkDataFeedLib.sol";

contract CbBtcUsdcMorphoBalanceAdapter {
    using ChainlinkDataFeedLib for AggregatorV3Interface;
    using MorphoBalancesLib for IMorpho;
    using SharesMathLib for uint256;

    error StaticCallFailed(string label);

    Id public immutable MORPHO_MARKET_ID;
    address public immutable CBBTC_USD_CHAINLINK_FEED;
    address public immutable USDC_USD_CHAINLINK_FEED;
    address public immutable SYUSD_VAULT;
    address public immutable SYUSD_ACCOUNTANT;

    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    constructor(
        bytes32 morphoMarketId,
        address cbBtcUsdFeed_,
        address usdcUsdFeed_,
        address syusdVault,
        address syusdAccountant
    ) {
        MORPHO_MARKET_ID = Id.wrap(morphoMarketId);
        CBBTC_USD_CHAINLINK_FEED = cbBtcUsdFeed_;
        USDC_USD_CHAINLINK_FEED = usdcUsdFeed_;
        SYUSD_VAULT = syusdVault;
        SYUSD_ACCOUNTANT = syusdAccountant;
    }

    function cbBtcUsdPrice() public view returns (uint256) {
        return AggregatorV3Interface(CBBTC_USD_CHAINLINK_FEED).getPrice();
    }

    function usdcUsdPrice() public view returns (uint256) {
        (bool success, bytes memory data) =
            USDC_USD_CHAINLINK_FEED.staticcall(abi.encodeWithSignature("latestAnswer()"));
        if (!success) revert StaticCallFailed("usdcusd/latestAnswer");
        uint256 price = uint256(abi.decode(data, (int256)));
        require(price >= 0, "negative answer");
        return price;
    }

    /// @notice Returns net TVL of a user denominated in cbBTC (8 decimals).
    function getUserTvl(address user) external view returns (uint256) {
        (uint256 collateral, uint256 debt, uint256 credit) = getUserPosition(user);
        return collateral - debt + credit;
    }

    /// @notice Returns the full position breakdown for a user, all in cbBTC (8 decimals).
    function getUserPosition(address user)
        public
        view
        returns (uint256 totalCollateralInCbBTC, uint256 totalDebtInCbBTC, uint256 totalCreditInCbBTC)
    {
        uint256 btcPrice = cbBtcUsdPrice(); // [8 dec]
        uint256 usdcPrice = usdcUsdPrice(); // [8 dec]

        totalCollateralInCbBTC = _getMorphoCollateral(user);
        totalDebtInCbBTC = _getMorphoDebt(user, usdcPrice, btcPrice);
        totalCreditInCbBTC = _getSyUsdCredit(user, usdcPrice, btcPrice);
    }

    /// @dev Returns user's cbBTC collateral in cbBTC units [8 dec].
    function _getMorphoCollateral(address user) internal view returns (uint256) {
        Position memory userPosition = IMorpho(MORPHO).position(MORPHO_MARKET_ID, user);
        return uint256(userPosition.collateral); // [8 dec]
    }

    /// @dev Returns user's USDC debt converted to cbBTC [8 dec].
    ///      usdcDebtBalance [6] * usdcPrice [8] / 1e6 → debtInUsd [8]
    ///      debtInUsd [8] * 1e8 / btcPrice [8]        → debtInCbBTC [8]
    function _getMorphoDebt(address user, uint256 usdcPrice, uint256 btcPrice) internal view returns (uint256) {
        IMorpho morpho = IMorpho(MORPHO);
        MarketParams memory marketParams = morpho.idToMarketParams(MORPHO_MARKET_ID);
        (,, uint256 totalBorrowAssets, uint256 totalBorrowShares) = morpho.expectedMarketBalances(marketParams);

        Position memory userPosition = morpho.position(MORPHO_MARKET_ID, user);
        uint256 usdcDebtBalance =
            uint256(userPosition.borrowShares).toAssetsUp(totalBorrowAssets, totalBorrowShares); // [6 dec]

        uint256 debtInUsd = (usdcDebtBalance * usdcPrice) / 1e6;
        return (debtInUsd * 1e8) / btcPrice;
    }

    /// @dev Returns user's syUSD vault balance converted to cbBTC [8 dec].
    ///      syUsdBalance [6] * syUsdRate [6] / 1e6  → creditInUsdc [6]
    ///      creditInUsdc [6] * usdcPrice  [8] / 1e6 → creditInUsd  [8]
    ///      creditInUsd  [8] * 1e8 / btcPrice [8]   → creditInCbBTC [8]
    function _getSyUsdCredit(address user, uint256 usdcPrice, uint256 btcPrice) internal view returns (uint256) {
        (bool balSuccess, bytes memory balData) =
            SYUSD_VAULT.staticcall(abi.encodeWithSignature("balanceOf(address)", user));
        if (!balSuccess) revert StaticCallFailed("syusd/balanceOf");
        uint256 syUsdBalance = abi.decode(balData, (uint256)); // [6 dec]

        (bool rateSuccess, bytes memory rateData) = SYUSD_ACCOUNTANT.staticcall(abi.encodeWithSignature("getRate()"));
        if (!rateSuccess) revert StaticCallFailed("syusd/getRate");
        uint256 syUsdRate = abi.decode(rateData, (uint256)); // [6 dec]

        uint256 creditInUsdc = (syUsdBalance * syUsdRate) / 1e6;
        uint256 creditInUsd = (creditInUsdc * usdcPrice) / 1e6;
        return (creditInUsd * 1e8) / btcPrice;
    }
}
