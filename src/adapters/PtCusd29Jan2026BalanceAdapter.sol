// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

contract PtCusd29Jan2026BalanceAdapter {
    address feed_pt_cusd_cusd;
    address feed_cusd_usd;
    address feed_usdc_usd;
    address pt_cusd;

    constructor(address _feed_pt_cusd_cusd, address _feed_cusd_usd, address _feed_usdc_usd, address _pt_cusd) {
        feed_pt_cusd_cusd = _feed_pt_cusd_cusd;
        feed_cusd_usd = _feed_cusd_usd;
        feed_usdc_usd = _feed_usdc_usd;
        pt_cusd = _pt_cusd;
    }

    /// @dev feed is based on redstone cusd fundamental feed
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        bytes memory payload = abi.encodeWithSignature("latestRoundData()");
        (bool success, bytes memory return_data) = feed_pt_cusd_cusd.staticcall(payload);
        require(success, "pt_cusd feed staticcall failed");
        (, int256 ptcusdcusd,,,) = abi.decode(return_data, (uint80, int256, uint256, uint256, uint80));

        payload = abi.encodeWithSignature("latestAnswer()");
        (success, return_data) = feed_cusd_usd.staticcall(payload);
        require(success, "cusd feed staticcall failed");
        (uint256 cusdusd) = abi.decode(return_data, (uint256));

        payload = abi.encodeWithSignature("latestAnswer()");
        (success, return_data) = feed_usdc_usd.staticcall(payload);
        require(success, "usdc feed staticcall failed");
        (uint256 usdcusd) = abi.decode(return_data, (uint256));

        payload = abi.encodeWithSignature("balanceOf()", _user);
        (success, return_data) = pt_cusd.staticcall(payload);
        require(success, "pt_cusd balance staticcall failed");
        (uint256 pt_stcusd_balance) = abi.decode(return_data, (uint256));

        return pt_stcusd_balance * uint256(ptcusdcusd) * cusdusd / (usdcusd * 1e36);
    }
}
