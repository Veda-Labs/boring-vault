// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {AccountantWithRateProviders} from "../../base/Roles/AccountantWithRateProviders.sol";
import {LucidlyChainlinkOracleBaseV1} from "./LucidlyChainlinkOracleBaseV1.sol";
import {ChainlinkDataFeedLib, AggregatorV3Interface} from "../libraries/ChainlinkDataFeedLib.sol";

/// @title LucidlyChainlinkBoringVaultOracleV1
/// @author Lucidly Labs
/// @notice Lucidly Strategies boringVault oracle contract base using Chainlink-compliant feeds.
contract LucidlyChainlinkBoringVaultOracleV1 is LucidlyChainlinkOracleBaseV1 {
    AccountantWithRateProviders public immutable ACCOUNTANT;

    /// @param accountant boringVault accountant. `decimals()` must equal the base asset's decimals
    /// @param baseFeed1 1st chainlink feed. address zero if price = 1
    /// @param baseFeed2 2nd chainlink feed. address zero if price = 1
    /// @param outputDecimals desired output decimals (e.g., 8 to match chainlink convention)
    constructor(
        AccountantWithRateProviders accountant,
        AggregatorV3Interface baseFeed1,
        AggregatorV3Interface baseFeed2,
        uint8 outputDecimals,
        string memory _oracleDescription
    ) LucidlyChainlinkOracleBaseV1(baseFeed1, baseFeed2, accountant.decimals(), outputDecimals, _oracleDescription) {
        require(address(accountant) != address(0), "accountant is zero");
        ACCOUNTANT = accountant;
    }

    /// @dev uses `getRateSafe` so the oracle reverts when the accountant is paused
    /// (which is the safety lever for a suspect rate).
    function _getBaseAmount() internal view override returns (uint256) {
        return ACCOUNTANT.getRateSafe();
    }
}

