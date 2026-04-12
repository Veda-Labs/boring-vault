// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ChainlinkDataFeedLib, AggregatorV3Interface} from "./libraries/ChainlinkDataFeedLib.sol";

contract WethUsdcAaveV3BalanceAdapter {
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    error StaticCallFailed(string label);

    address public immutable AAVE_V3_POOL;
    address public immutable WSTETH_USD_CHAINLINK_FEED;
    address public immutable WETH_USD_CHAINLINK_FEED;
    address public immutable USDC_USD_CHAINLINK_FEED;
    address public immutable SYUSD_VAULT;
    address public immutable SYUSD_ACCOUNTANT;

    address public constant AAVE_COLLAT_WSTETH = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;
    address public constant AAVE_DEBT_USDC = 0x72E95b8931767C79bA4EeE721354d6E99a61D004;

    constructor(
        address aaveV3Pool,
        address wstethUsdFeed_,
        address wethUsdFeed_,
        address usdcUsdFeed_,
        address syusdVault,
        address syusdAccountant
    ) {
        AAVE_V3_POOL = aaveV3Pool;
        WSTETH_USD_CHAINLINK_FEED = wstethUsdFeed_;
        WETH_USD_CHAINLINK_FEED = wethUsdFeed_;
        USDC_USD_CHAINLINK_FEED = usdcUsdFeed_;
        SYUSD_VAULT = syusdVault;
        SYUSD_ACCOUNTANT = syusdAccountant;
    }

    function wstEthUsdPrice() public view returns (uint256) {
        (bool success, bytes memory data) =
            WSTETH_USD_CHAINLINK_FEED.staticcall(abi.encodeWithSignature("latestAnswer()"));
        if (!success) revert StaticCallFailed("wstethusd/latestAnswer");
        uint256 price = uint256(abi.decode(data, (int256)));
        require(price >= 0, "negative answer");
        return price;
    }
    function wethUsdPrice() public view returns (uint256) {
        (bool success, bytes memory data) =
            WETH_USD_CHAINLINK_FEED.staticcall(abi.encodeWithSignature("latestAnswer()"));
        if (!success) revert StaticCallFailed("wethusd/latestAnswer");
        uint256 price = uint256(abi.decode(data, (int256)));
        require(price >= 0, "negative answer");
        return price;
    }

    function usdcUsdPrice() public view returns (uint256) {
        (bool success, bytes memory data) =
            USDC_USD_CHAINLINK_FEED.staticcall(abi.encodeWithSignature("latestAnswer()"));
        if (!success) revert StaticCallFailed("usdcusd/latestAnswer");
        uint256 price = uint256(abi.decode(data, (int256)));
        require(price >= 0, "negative answer");
        return price;
    }

    /// @notice Returns net TVL of a user denominated in WETH (18 decimals).
    function getUserTvl(address user) external view returns (uint256) {
        (uint256 collateral, uint256 debt, uint256 credit) = getUserPosition(user);
        return collateral - debt + credit;
    }

    /// @notice Returns the full position breakdown for a user, all in WETH (18 decimals).
    function getUserPosition(address user)
        public
        view
        returns (uint256 totalCollateralInWeth, uint256 totalDebtInWeth, uint256 totalCreditInWeth)
    {
        uint256 wstEthPrice = wstEthUsdPrice(); // [8 dec]
        uint256 wethPrice = wethUsdPrice(); // [8 dec]
        uint256 usdcPrice = usdcUsdPrice(); // [8 dec]

        totalCollateralInWeth = _getAaveCollateral(user, wethPrice, wstEthPrice);
        totalDebtInWeth = _getAaveDebt(user, usdcPrice, wethPrice);
        totalCreditInWeth = _getSyUsdCredit(user, usdcPrice, wethPrice);
    }

    /// @dev Returns user's wstETH collateral in weth units [18 dec].
    function _getAaveCollateral(address user, uint256 wethPrice, uint256 wstEthPrice) internal view returns (uint256) {
        (bool success, bytes memory data) =
            AAVE_COLLAT_WSTETH.staticcall(abi.encodeWithSignature("balanceOf(address)", user));
        if (!success) revert StaticCallFailed("wsteth/balanceOf");

        uint256 wstEthBalance = abi.decode(data, (uint256)); // [18 dec]
        uint256 collateralInUsd = (wstEthBalance * wstEthPrice) / 1e18; // [8 dec]
        uint256 collateralInWeth = (collateralInUsd * 1e18) / wethPrice; // [18 dec]
        return collateralInWeth;
    }

    /// @dev Returns user's USDC debt converted to weth [18 dec].
    ///      usdcDebtBalance [6] * usdcPrice [8] / 1e6 → debtInUsd [8]
    ///      debtInUsd [8] * 1e18 / wethPrice [8]        → debtInWeth [18]
    function _getAaveDebt(address user, uint256 usdcPrice, uint256 wethPrice) internal view returns (uint256) {
        (bool success, bytes memory data) =
            AAVE_DEBT_USDC.staticcall(abi.encodeWithSignature("balanceOf(address)", user));
        if (!success) revert StaticCallFailed("usdc-debt/balanceOf");
        uint256 usdcDebtBalance = abi.decode(data, (uint256)); // [6 dec]

        uint256 debtInUsd = (usdcDebtBalance * usdcPrice) / 1e6;
        return (debtInUsd * 1e18) / wethPrice;
    }

    /// @dev Returns user's syUSD vault balance converted to weth [18 dec].
    ///      syUsdBalance [6] * syUsdRate [6] / 1e6  → creditInUsdc [6]
    ///      creditInUsdc [6] * usdcPrice  [8] / 1e6 → creditInUsd  [8]
    ///      creditInUsd  [8] * 1e18 / wethPrice [8]   → creditInWeth [18]
    function _getSyUsdCredit(address user, uint256 usdcPrice, uint256 wethPrice) internal view returns (uint256) {
        (bool balSuccess, bytes memory balData) =
            SYUSD_VAULT.staticcall(abi.encodeWithSignature("balanceOf(address)", user));
        if (!balSuccess) revert StaticCallFailed("syusd/balanceOf");
        uint256 syUsdBalance = abi.decode(balData, (uint256)); // [6 dec]

        (bool rateSuccess, bytes memory rateData) = SYUSD_ACCOUNTANT.staticcall(abi.encodeWithSignature("getRate()"));
        if (!rateSuccess) revert StaticCallFailed("syusd/getRate");
        uint256 syUsdRate = abi.decode(rateData, (uint256)); // [6 dec]

        uint256 creditInUsdc = (syUsdBalance * syUsdRate) / 1e6;
        uint256 creditInUsd = (creditInUsdc * usdcPrice) / 1e6;
        return (creditInUsd * 1e18) / wethPrice;
    }
}
