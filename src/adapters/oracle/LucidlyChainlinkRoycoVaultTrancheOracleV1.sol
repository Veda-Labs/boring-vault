// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
import {LucidlyChainlinkOracleBaseV1} from "./LucidlyChainlinkOracleBaseV1.sol";
import {AggregatorV3Interface} from "../libraries/ChainlinkDataFeedLib.sol";

interface IRoycoVaultTranche {
    /**
     * @notice Returns the raw NAV of the tranche's invested assets
     * @dev The raw NAV represents the pure value of the tranche's assets before any coverage adjustments or yield sharing
     * @return nav The raw NAV of the tranche's invested assets, denominated in the kernel's NAV units
     */
    function getRawNAV() external view returns (uint256);

    function totalSupply() external view returns (uint256);
}

/// @title LucidlyChainlinkRoycoVaultTrancheOracleV1
/// @author Lucidly Labs
/// @notice Lucidly Strategies royco vault tranche oracle contract base using Chainlink-compliant feeds.
contract LucidlyChainlinkRoycoVaultTrancheOracleV1 is LucidlyChainlinkOracleBaseV1 {
    IRoycoVaultTranche public immutable TRANCHE;

    /// @param tranche royco tranche address
    /// @param baseFeed1 1st chainlink feed. address zero if price = 1
    /// @param baseFeed2 2nd chainlink feed. address zero if price = 1
    /// @param outputDecimals desired output decimals (e.g., 8 to match chainlink convention)
    constructor(
        IRoycoVaultTranche tranche,
        AggregatorV3Interface baseFeed1,
        AggregatorV3Interface baseFeed2,
        uint8 outputDecimals,
        string memory _oracleDescription
    ) LucidlyChainlinkOracleBaseV1(baseFeed1, baseFeed2, 18, outputDecimals, _oracleDescription) {
        require(address(tranche) != address(0), "tranche is zero");
        require(ERC20(address(tranche)).decimals() == 18, "tranche must be 18 dec");
        TRANCHE = tranche;
    }

    function _getBaseAmount() internal view override returns (uint256) {
        uint256 supply = TRANCHE.totalSupply();
        require(supply != 0, "tranche supply zero");
        return (TRANCHE.getRawNAV() * 1e18) / supply;
    }
}
