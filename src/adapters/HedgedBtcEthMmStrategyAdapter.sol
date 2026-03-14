// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

contract HedgedBtcEthMmStrategyAdapter {
    address strategyAccountantAddress;
    address strategyShareAddress;
    address quoteTokenAddress;

    constructor(address _strategyAccountantAddress, address _strategyShareAddress, address _quoteTokenAddress) {
        strategyAccountantAddress = _strategyAccountantAddress;
        strategyShareAddress = _strategyShareAddress;
        quoteTokenAddress = _quoteTokenAddress;
    }

    /// @dev feed is based on strategy nav from accoutant address
    function getUserTvl(address _user) external view returns (uint256 tvl) {
        bytes memory strategySharePricePayload = abi.encodeWithSignature("getRateInQuote(address)", quoteTokenAddress);
        (bool success, bytes memory data) = strategyAccountantAddress.staticcall(strategySharePricePayload);
        require(success, "getRate staticcall failed");
        uint256 rateInQuote = abi.decode(data, (uint256));

        bytes memory balanceOfPayload = abi.encodeWithSignature("balanceOf(address)", _user);
        (success, data) = strategyShareAddress.staticcall(balanceOfPayload);
        require(success, "balanceOf staticcall failed");
        uint256 balance = abi.decode(data, (uint256));

        tvl = balance * rateInQuote / 1e8;
    }
}
