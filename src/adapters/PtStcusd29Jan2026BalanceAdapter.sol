// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

contract PtStcusd29Jan2026BalancerAdapter {
    address feed_pt_stcusd_stcusd;
    address feed_stcusd_cusd;
    address feed_cusd_usd;
    address feed_usdc_usd;
    address pt_stcusd;

    constructor(
        address _redstoneCusdFundamentalFeed,
        address _chainlinkUsdcUsdFeed,
        address _pt_stcusd,
        address _feed_pt_stcusd_stcusd,
        address _feed_stcusd_cusd,
        address _feed_cusd_usd,
        address _feed_usdc_usd
    ) {
        feed_pt_stcusd_stcusd = _feed_pt_stcusd_stcusd;
        feed_stcusd_cusd = _feed_stcusd_cusd;
        feed_cusd_usd = _redstoneCusdFundamentalFeed;
        feed_usdc_usd = _chainlinkUsdcUsdFeed;
        pt_stcusd = _pt_stcusd;
    }

    /// @dev feed is based on redstone cusd fundamental feed
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        bytes memory payload = abi.encodeWithSignature("latestRoundData()");
        (bool success, bytes memory return_data) = feed_pt_stcusd_stcusd.staticcall(payload);
        require(success, "pt_stcusd feed staticcall failed");
        (, int256 ptstcusdstcusd,,,) = abi.decode(return_data, (uint80, int256, uint256, uint256, uint80));

        payload = abi.encodeWithSignature("latestRoundData()");
        (success, return_data) = feed_stcusd_cusd.staticcall(payload);
        require(success, "stcusd feed staticcall failed");
        (, int256 stcusdcusd,,,) = abi.decode(return_data, (uint80, int256, uint256, uint256, uint80));

        payload = abi.encodeWithSignature("latestAnswer()");
        (success, return_data) = feed_cusd_usd.staticcall(payload);
        require(success, "cusd feed staticcall failed");
        (uint256 cusdusd) = abi.decode(return_data, (uint256));

        payload = abi.encodeWithSignature("latestAnswer()");
        (success, return_data) = feed_usdc_usd.staticcall(payload);
        require(success, "usdc feed staticcall failed");
        (uint256 usdcusd) = abi.decode(return_data, (uint256));

        payload = abi.encodeWithSignature("balanceOf()", _user);
        (success, return_data) = pt_stcusd.staticcall(payload);
        require(success, "pt_stcusd balance staticcall failed");
        (uint256 pt_stcusd_balance) = abi.decode(return_data, (uint256));

        return pt_stcusd_balance * uint256(ptstcusdstcusd) * uint256(stcusdcusd) * cusdusd / (usdcusd * 1e36);
    }
}
