// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

contract RoycoJrSyrupUsdcBalanceAdapter {
    address immutable jr_tranche_address;
    address immutable syrup_usdc_address;

    constructor(address _jr_tranche_address, address _syrup_usdc_address) {
        jr_tranche_address = _jr_tranche_address;
        syrup_usdc_address = _syrup_usdc_address;
    }

    /// @dev Junior tranche shares -> syrupUSDC -> USDC. All preview-based, no oracles.
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        bytes memory payload = abi.encodeWithSignature("balanceOf(address)", _user);
        (bool success, bytes memory returnData) = jr_tranche_address.staticcall(payload);
        require(success, "JT balance staticcall failed");
        uint256 jtShares = abi.decode(returnData, (uint256));
        if (jtShares == 0) return 0;

        payload = abi.encodeWithSignature("previewRedeem(uint256)", jtShares);
        (success, returnData) = jr_tranche_address.staticcall(payload);
        require(success, "JT previewRedeem staticcall failed");
        (uint256 syrupAmount,) = abi.decode(returnData, (uint256, address));
        if (syrupAmount == 0) return 0;

        payload = abi.encodeWithSignature("previewRedeem(uint256)", syrupAmount);
        (success, returnData) = syrup_usdc_address.staticcall(payload);
        require(success, "syrupUSDC previewRedeem staticcall failed");
        tvl = abi.decode(returnData, (uint256));
    }
}
