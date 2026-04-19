// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {ERC4626} from "../../../lib/solmate/src/tokens/ERC4626.sol";
import {AggregatorV3Interface} from "../libraries/ChainlinkDataFeedLib.sol";

/// @title ILucidlyChainlinkOracleV1
/// @author Lucidly Labs
/// @notice interface of LucidlyChainlinkOracleV1
interface ILucidlyChainlinkOracleV1 is AggregatorV3Interface {
    /// @notice Returns the address of the ERC4626 vault used to convert shares to underlying assets
    /// @dev Address zero if the base asset is not a vault token
    function BASE_VAULT() external view returns (ERC4626);

    /// @notice Returns the sample amount of vault shares used for the conversion to assets
    /// @dev Must be 1 if BASE_VAULT is address zero
    function BASE_VAULT_CONVERSION_SAMPLE() external view returns (uint256);

    /// @notice Returns the first Chainlink-compatible price feed
    /// @dev Address zero if not used (price = 1)
    function BASE_FEED_1() external view returns (AggregatorV3Interface);

    /// @notice Returns the second Chainlink-compatible price feed
    /// @dev Address zero if not used (price = 1). Used to chain two feeds together
    function BASE_FEED_2() external view returns (AggregatorV3Interface);

    /// @notice Returns the scale factor used to normalize the final price to the output decimals
    /// @dev Computed at deployment based on vault, feed, and token decimals
    function SCALE_FACTOR() external view returns (uint256);
}

