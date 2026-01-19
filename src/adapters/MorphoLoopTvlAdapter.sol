// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMorpho, MarketParams, Id, Market, Position} from "./libraries/IMorpho.sol";

contract MorphoLoopTvlAdapter {
    IMorpho private morpho;
    Id public immutable marketId;
    address public constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public MORPHO_CHAINLINK_ORACLE;

    constructor(bytes32 _marketId) {
        marketId = Id.wrap(_marketId);
        morpho = IMorpho(MORPHO);
        MarketParams memory marketParams = morpho.idToMarketParams(marketId);
        MORPHO_CHAINLINK_ORACLE = marketParams.oracle;
    }

    /// @dev should return TVL in USDC terms
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        (uint256 collateral, uint256 debt, uint256 supplied) = getUserPositionValues(_user);
        tvl = (collateral) + supplied - debt;
    }

    /// @dev should return position values in USDC terms
    function getUserPositionValues(address _user)
        public
        view
        returns (uint256 collateral, uint256 debt, uint256 supplied)
    {
        Market memory marketState = morpho.market(marketId);
        Position memory userPosition = morpho.position(marketId, _user);

        bytes memory payload = abi.encodeWithSignature("price()");
        (bool success, bytes memory returnData) = address(MORPHO_CHAINLINK_ORACLE).staticcall(payload);
        require(success, "staticcall failed");
        uint256 rate = abi.decode(returnData, (uint256));

        supplied = (userPosition.supplyShares * marketState.totalSupplyAssets) / marketState.totalSupplyShares;
        debt = (userPosition.borrowShares * marketState.totalBorrowAssets) / marketState.totalBorrowShares;
        collateral = userPosition.collateral;
        collateral = (collateral * rate) / 1e36;
        // converting everything in usdc terms
    }
}
