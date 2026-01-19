// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

contract CapCusdBalanceAdapter {
    address feed_cusd_usd;
    address feed_usdc_usd;
    address cusd;

    constructor(address _redstoneCusdFundamentalFeed, address _chainlinkUsdcUsdFeed, address _cusd) {
        feed_cusd_usd = _redstoneCusdFundamentalFeed;
        feed_usdc_usd = _chainlinkUsdcUsdFeed;
        cusd = _cusd;
    }

    /// @dev feed is based on redstone cusd fundamental feed
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        bytes memory payload = abi.encodeWithSignature("latestAnswer()");
        (bool success, bytes memory returnData) = feed_cusd_usd.staticcall(payload);
        require(success, "cusd feed staticcall failed");
        (uint256 cusd_usd) = abi.decode(returnData, (uint256));

        payload = abi.encodeWithSignature("latestAnswer()");
        (success, returnData) = feed_usdc_usd.staticcall(payload);
        require(success, "usdc feed staticcall failed");
        (uint256 usdc_usd) = abi.decode(returnData, (uint256));

        payload = abi.encodeWithSignature("balanceOf()", _user);
        (success, returnData) = cusd.staticcall(payload);
        require(success, "cusd balance staticcall failed");
        (uint256 cusdBalance) = abi.decode(returnData, (uint256));

        return cusdBalance * cusd_usd / usdc_usd;
    }
}
