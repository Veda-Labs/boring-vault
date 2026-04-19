// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
import {ERC4626} from "../../../lib/solmate/src/tokens/ERC4626.sol";
import {ILucidlyChainlinkOracleV1} from "./ILucidlyChainlinkOracleV1.sol";
import {ChainlinkDataFeedLib, AggregatorV3Interface} from "../libraries/ChainlinkDataFeedLib.sol";

/// @title LucidlyChainlinkOracleV1
/// @author Lucidly Labs
/// @notice Lucidly Strategies oracle using Chainlink-compliant feeds.
contract LucidlyChainlinkOracleV1 is ILucidlyChainlinkOracleV1 {
    using ChainlinkDataFeedLib for AggregatorV3Interface;

    ERC4626 public immutable BASE_VAULT;
    uint256 public immutable BASE_VAULT_CONVERSION_SAMPLE;
    AggregatorV3Interface public immutable BASE_FEED_1;
    AggregatorV3Interface public immutable BASE_FEED_2;
    uint256 public immutable SCALE_FACTOR;
    uint8 public immutable OUTPUT_DECIMALS;
    string private _description;

    /// @param baseVault ERC4626 vault. Pass address zero if the asset is not a vault token.
    /// @param baseVaultConversionSample Sample shares for vault conversion. Must be 1 if no vault.
    /// @param baseFeed1 First Chainlink feed. Address zero if price = 1.
    /// @param baseFeed2 Second Chainlink feed. Address zero if price = 1.
    /// @param baseTokenDecimals Decimals of the base token (the vault share token, or the token itself if no vault).
    /// @param outputDecimals Desired output decimals (e.g., 8 to match Chainlink convention).
    constructor(
        ERC4626 baseVault,
        uint256 baseVaultConversionSample,
        AggregatorV3Interface baseFeed1,
        AggregatorV3Interface baseFeed2,
        uint256 baseTokenDecimals,
        uint8 outputDecimals,
        string memory _oracleDescription
    ) {
        require(address(baseVault) != address(0) || baseVaultConversionSample == 1, "vault conversion sample must be 1");
        require(baseVaultConversionSample != 0, "vault conversion sample is zero");

        BASE_VAULT = baseVault;
        BASE_VAULT_CONVERSION_SAMPLE = baseVaultConversionSample;
        BASE_FEED_1 = baseFeed1;
        BASE_FEED_2 = baseFeed2;
        OUTPUT_DECIMALS = outputDecimals;
        _description = _oracleDescription;

        // We need to scale from input decimals to outputDecimals:
        // When vault is set: SCALE_FACTOR = 10^(baseTokenDecimals + feed1Decimals + feed2Decimals - outputDecimals)
        // When no vault:     SCALE_FACTOR = 10^(feed1Decimals + feed2Decimals - outputDecimals)
        // Then: answer = (vaultAssets * feed1 * feed2) / SCALE_FACTOR
        uint256 vaultOutputDecimals = address(baseVault) != address(0) ? baseTokenDecimals : 0;
        SCALE_FACTOR = 10 ** (vaultOutputDecimals + baseFeed1.getDecimals() + baseFeed2.getDecimals() - outputDecimals);
    }

    function decimals() external view returns (uint8) {
        return OUTPUT_DECIMALS;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80) external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert("not implemented");
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        uint256 vaultAssets =
            address(BASE_VAULT) != address(0) ? BASE_VAULT.convertToAssets(BASE_VAULT_CONVERSION_SAMPLE) : 1;

        uint256 priceRaw = vaultAssets * BASE_FEED_1.getPrice() * BASE_FEED_2.getPrice();
        int256 answer = int256(priceRaw / SCALE_FACTOR);

        return (0, answer, 0, block.timestamp, 0);
    }
}
