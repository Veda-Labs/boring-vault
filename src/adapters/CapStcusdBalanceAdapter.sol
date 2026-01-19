// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

contract CapStcusdBalanceAdapter {
    address feed_stcusd_cusd;
    address feed_cusd_usd;
    address feed_usdc_usd;
    address stcusd;

    constructor(address _feed_stcusd_cusd, address _feed_cusd_usd, address _feed_usdc_usd, address _stcusd) {
        feed_stcusd_cusd = _feed_stcusd_cusd;
        feed_cusd_usd = _feed_cusd_usd;
        feed_usdc_usd = _feed_usdc_usd;
        stcusd = _stcusd;
    }

    /// @dev feed is based on redstone cusd fundamental feed
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        bytes memory payload = abi.encodeWithSignature("latestRoundData()");
        (bool success, bytes memory returnData) = feed_stcusd_cusd.staticcall(payload);
        require(success, "stcusd feed staticcall failed");
        (, int256 stcusdcusd,,,) = abi.decode(returnData, (uint80, int256, uint256, uint256, uint80));

        payload = abi.encodeWithSignature("latestAnswer()");
        (success, returnData) = feed_cusd_usd.staticcall(payload);
        require(success, "cusd feed staticcall failed");
        (uint256 cusdusd) = abi.decode(returnData, (uint256));

        payload = abi.encodeWithSignature("latestAnswer()");
        (success, returnData) = feed_usdc_usd.staticcall(payload);
        require(success, "usdc feed staticcall failed");
        (uint256 usdcusd) = abi.decode(returnData, (uint256));

        payload = abi.encodeWithSignature("balanceOf()", _user);
        (success, returnData) = stcusd.staticcall(payload);
        require(success, "stcusd balance staticcall failed");
        (uint256 stcusdBalance) = abi.decode(returnData, (uint256));

        return stcusdBalance * uint256(stcusdcusd) * cusdusd / (usdcusd * 1e18);
    }
}
