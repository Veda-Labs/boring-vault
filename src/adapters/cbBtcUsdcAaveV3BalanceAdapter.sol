// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMorpho, MarketParams, Id, Market, Position} from "./libraries/IMorpho.sol";
import {ChainlinkDataFeedLib, AggregatorV3Interface} from "./libraries/ChainlinkDataFeedLib.sol";

contract CbBtcUsdcAaveV3BalanceAdapter {
    using ChainlinkDataFeedLib for AggregatorV3Interface;
    address public AAVE_V3_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public CBBTC_USD_CHAINLINK_FEED = 0x2665701293fCbEB223D11A08D826563EDcCE423A;

    
    function cbBtcUsdFeed() public view returns (uint256 price) {
        AggregatorV3Interface feed = AggregatorV3Interface(CBBTC_USD_CHAINLINK_FEED);
        price = feed.getPrice();
    }

    function getUserTvl(address _user) external view returns (uint256 tvl) {
        (uint256 totalCollateralInCbBTC, uint256 totalDebtInCbBTC,,) = _getUserPosition(_user);

        return totalCollateralInCbBTC - totalDebtInCbBTC;
    }

    function getUserPosition(address _user)
        external
        view
        returns (
            uint256 totalCollateralInUsdc,
            uint256 totalDebtInUsdc,
            uint256 totalCollateralBase,
            uint256 totalDebtBase
        )
    {
        (totalCollateralInUsdc, totalDebtInUsdc, totalCollateralBase, totalDebtBase) = _getUserPosition(_user);
    }

    function _getUserPosition(address _user) private view returns (uint256, uint256, uint256, uint256) {
        (bool sucess, bytes memory data) =
            AAVE_V3_POOL.staticcall(abi.encodeWithSignature("getUserAccountData(address)", _user));
        require(sucess, "staticcall failed");

        (uint256 totalCollateralBase, uint256 totalDebtBase,,,,) =
            abi.decode(data, (uint256, uint256, uint256, uint256, uint256, uint256));

        uint256 totalCollateralInCbBTC = (totalCollateralBase * 1e8) / (cbBtcUsdFeed());
        uint256 totalDebtInCbBTC = (totalDebtBase * 1e8) / (cbBtcUsdFeed());

        return (totalCollateralInCbBTC, totalDebtInCbBTC, totalCollateralBase, totalDebtBase);
    }
}
