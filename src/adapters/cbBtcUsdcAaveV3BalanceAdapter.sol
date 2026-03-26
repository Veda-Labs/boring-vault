// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {ChainlinkDataFeedLib, AggregatorV3Interface} from "./libraries/ChainlinkDataFeedLib.sol";

contract CbBtcUsdcAaveV3BalanceAdapter {
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    // --- Errors ---
    error StaticCallFailed(string label);

    // --- Immutables ---
    address public immutable AAVE_V3_POOL;
    address public immutable CBBTC_USD_CHAINLINK_FEED;
    address public immutable USDC_USD_CHAINLINK_FEED;
    address public immutable SYUSD_VAULT;
    address public immutable SYUSD_ACCOUNTANT;

    // --- Constants ---
    address public constant AAVE_COLLAT_CBBTC = 0x5c647cE0Ae10658ec44FA4E11A51c96e94efd1Dd;
    address public constant AAVE_DEBT_USDC    = 0x72E95b8931767C79bA4EeE721354d6E99a61D004;

    constructor(
        address aaveV3Pool,
        address cbBtcUsdFeed_,
        address usdcUsdFeed_,
        address syusdVault,
        address syusdAccountant
    ) {
        AAVE_V3_POOL             = aaveV3Pool;
        CBBTC_USD_CHAINLINK_FEED = cbBtcUsdFeed_;
        USDC_USD_CHAINLINK_FEED  = usdcUsdFeed_;
        SYUSD_VAULT              = syusdVault;
        SYUSD_ACCOUNTANT         = syusdAccountant;
    }

    // --- Price feeds ---

    function cbBtcUsdPrice() public view returns (uint256) {
        return AggregatorV3Interface(CBBTC_USD_CHAINLINK_FEED).getPrice();
    }

    function usdcUsdPrice() public view returns (uint256) {
        return AggregatorV3Interface(USDC_USD_CHAINLINK_FEED).getPrice();
    }

    // --- Public interface ---

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
        uint256 btcPrice  = cbBtcUsdPrice(); // [8 dec]
        uint256 usdcPrice = usdcUsdPrice();  // [8 dec]

        totalCollateralInCbBTC = _getAaveCollateral(user);
        totalDebtInCbBTC       = _getAaveDebt(user, usdcPrice, btcPrice);
        totalCreditInCbBTC     = _getSyUsdCredit(user, usdcPrice, btcPrice);
    }

    // --- Internal helpers (each gets its own stack frame) ---

    /// @dev Returns user's cbBTC collateral in cbBTC units [8 dec].
    function _getAaveCollateral(address user) internal view returns (uint256) {
        (bool success, bytes memory data) =
            AAVE_COLLAT_CBBTC.staticcall(abi.encodeWithSignature("balanceOf(address)", user));
        if (!success) revert StaticCallFailed("cbbtc/balanceOf");
        return abi.decode(data, (uint256)); // [8 dec]
    }

    /// @dev Returns user's USDC debt converted to cbBTC [8 dec].
    ///      usdcDebtBalance [6] * usdcPrice [8] / 1e6 → debtInUsd [8]
    ///      debtInUsd [8] * 1e8 / btcPrice [8]        → debtInCbBTC [8]
    function _getAaveDebt(address user, uint256 usdcPrice, uint256 btcPrice)
        internal
        view
        returns (uint256)
    {
        (bool success, bytes memory data) =
            AAVE_DEBT_USDC.staticcall(abi.encodeWithSignature("balanceOf(address)", user));
        if (!success) revert StaticCallFailed("usdc-debt/balanceOf");
        uint256 usdcDebtBalance = abi.decode(data, (uint256)); // [6 dec]

        uint256 debtInUsd = (usdcDebtBalance * usdcPrice) / 1e6;
        return (debtInUsd * 1e8) / btcPrice;
    }

    /// @dev Returns user's syUSD vault balance converted to cbBTC [8 dec].
    ///      syUsdBalance [6] * syUsdRate [6] / 1e6  → creditInUsdc [6]
    ///      creditInUsdc [6] * usdcPrice  [8] / 1e6 → creditInUsd  [8]
    ///      creditInUsd  [8] * 1e8 / btcPrice [8]   → creditInCbBTC [8]
    function _getSyUsdCredit(address user, uint256 usdcPrice, uint256 btcPrice)
        internal
        view
        returns (uint256)
    {
        (bool balSuccess, bytes memory balData) =
            SYUSD_VAULT.staticcall(abi.encodeWithSignature("balanceOf(address)", user));
        if (!balSuccess) revert StaticCallFailed("syusd/balanceOf");
        uint256 syUsdBalance = abi.decode(balData, (uint256)); // [6 dec]

        (bool rateSuccess, bytes memory rateData) =
            SYUSD_ACCOUNTANT.staticcall(abi.encodeWithSignature("getRate()"));
        if (!rateSuccess) revert StaticCallFailed("syusd/getRate");
        uint256 syUsdRate = abi.decode(rateData, (uint256)); // [6 dec]

        uint256 creditInUsdc = (syUsdBalance * syUsdRate) / 1e6;
        uint256 creditInUsd  = (creditInUsdc  * usdcPrice) / 1e6;
        return (creditInUsd * 1e8) / btcPrice;
    }
}