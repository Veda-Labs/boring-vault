// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {ERC4626} from "../../../lib/solmate/src/tokens/ERC4626.sol";
import {LucidlyChainlinkOracleBaseV1} from "./LucidlyChainlinkOracleBaseV1.sol";
import {ChainlinkDataFeedLib, AggregatorV3Interface} from "../libraries/ChainlinkDataFeedLib.sol";

/// @title LucidlyChainlinkErc4626OracleV1
/// @author Lucidly Labs
/// @notice Lucidly Strategies erc4626 oracle contract base using Chainlink-compliant feeds.
contract LucidlyChainlinkErc4626OracleV1 is LucidlyChainlinkOracleBaseV1 {
    ERC4626 public immutable BASE_VAULT;
    uint256 public immutable BASE_VAULT_CONVERSION_SAMPLE;

    /// @param baseVault ERC4626 vault. Pass address zero if the asset is not a vault token.
    /// @param baseVaultConversionSample Sample shares for vault conversion. Must be 1 if no vault
    /// @param baseFeed1 First Chainlink feed. Address zero if price = 1
    /// @param baseFeed2 Second Chainlink feed. Address zero if price = 1
    /// @param baseTokenDecimals Decimals of the base token (the vault share token, or the token itself if no vault)
    /// @param outputDecimals Desired output decimals (e.g., 8 to match Chainlink convention)
    constructor(
        ERC4626 baseVault,
        uint256 baseVaultConversionSample,
        AggregatorV3Interface baseFeed1,
        AggregatorV3Interface baseFeed2,
        uint256 baseTokenDecimals,
        uint8 outputDecimals,
        string memory _oracleDescription
    )
        LucidlyChainlinkOracleBaseV1(
            baseFeed1,
            baseFeed2,
            address(baseVault) != address(0) ? baseTokenDecimals : 0,
            outputDecimals,
            _oracleDescription
        )
    {
        require(address(baseVault) != address(0) || baseVaultConversionSample == 1, "vault conversion sample must be 1");
        require(baseVaultConversionSample != 0, "vault conversion sample is zero");

        BASE_VAULT = baseVault;
        BASE_VAULT_CONVERSION_SAMPLE = baseVaultConversionSample;
    }

    function _getBaseAmount() internal view override returns (uint256) {
        return address(BASE_VAULT) != address(0) ? BASE_VAULT.convertToAssets(BASE_VAULT_CONVERSION_SAMPLE) : 1;
    }
}
