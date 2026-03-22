// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

contract SiUsdBalanceAdapter {
    address immutable siusd_address;

    constructor(address _siusd_address) {
        siusd_address = _siusd_address;
    }

    /// @dev feed is based on siusd fundamental feed
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        bytes memory payload = abi.encodeWithSignature("balanceOf(address)", _user);
        (bool success, bytes memory returnData) = siusd_address.staticcall(payload);
        require(success, "siUSD balance staticcall failed");
        uint256 shares = abi.decode(returnData, (uint256));

        payload = abi.encodeWithSignature("previewRedeem(uint256)", shares);
        (success, returnData) = siusd_address.staticcall(payload);
        require(success, "siUSD previewRedeem staticcall failed");
        uint256 iusdAmount = abi.decode(returnData, (uint256));
        uint256 usdcAmount = iusdAmount / 1e12;
        tvl = usdcAmount > 0 ? usdcAmount - 1 : 0;
    }
}
