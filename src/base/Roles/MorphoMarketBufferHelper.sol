// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

/**
 * @title MorphoMarketBufferHelper
 * @author Veda Tech Labs
 * @notice A buffer helper contract that integrates with a single Morpho Blue market for automated
 *         yield generation. Only supports the loan-side (supply / withdraw); does not handle
 *         collateral or borrow operations.
 * @dev Implements the IBufferHelper interface to provide Morpho Blue market integration for the
 *      TellerWithBuffer contract. This helper automatically manages token approvals and supply
 *      / withdraw operations on a specific Morpho Blue market.
 *
 *      The Morpho Blue singleton expects the market to be identified by its `MarketParams`
 *      struct (loanToken, collateralToken, oracle, irm, lltv). Those parameters are stored as
 *      immutables on construction so the helper is locked to a single market.
 */
contract MorphoMarketBufferHelper is IBufferHelper {
    //============================== ERRORS ===============================

    /// @notice Thrown when getDepositManageCall is invoked with an asset that does not
    ///         match the market's configured loan token.
    error MorphoMarketBufferHelper__AssetMismatch(address asset, address expected);

    /// @notice Thrown when a critical constructor argument is the zero address.
    error MorphoMarketBufferHelper__ZeroAddress();

    /// @notice The Morpho Blue singleton contract
    address public immutable MORPHO_BLUE;

    /// @notice The associated boring vault
    address public immutable VAULT;

    // -- Market params (immutable, encode a single market) --
    /// @notice The loan token of the Morpho Blue market (the asset that is supplied / withdrawn)
    address public immutable LOAN_TOKEN;
    /// @notice The collateral token of the Morpho Blue market
    address public immutable COLLATERAL_TOKEN;
    /// @notice The oracle of the Morpho Blue market
    address public immutable ORACLE;
    /// @notice The interest rate model of the Morpho Blue market
    address public immutable IRM;
    /// @notice The liquidation loan-to-value ratio of the Morpho Blue market
    uint256 public immutable LLTV;

    /**
     * @notice Initializes the MorphoMarketBufferHelper contract
     * @param morphoBlue The Morpho Blue singleton contract address
     * @param vault The associated boring vault
     * @param loanToken The loan token of the target Morpho Blue market
     * @param collateralToken The collateral token of the target Morpho Blue market
     * @param oracle The oracle of the target Morpho Blue market
     * @param irm The interest rate model of the target Morpho Blue market
     * @param lltv The liquidation loan-to-value ratio of the target Morpho Blue market
     */
    constructor(
        address morphoBlue,
        address vault,
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    ) {
        // Since these parameters are immutable, a zero address here can never be corrected
        // post-deployment. Guard the parameters whose zero value would be unambiguously
        // catastrophic: the Morpho Blue singleton, the boring vault that owns the supply
        // position, and the loan token that is supplied / withdrawn. The remaining market
        // params (collateralToken / oracle / irm / lltv) are intentionally not zero-checked
        // because some Morpho Blue market configurations legitimately use zero values.
        if (morphoBlue == address(0) || vault == address(0) || loanToken == address(0)) {
            revert MorphoMarketBufferHelper__ZeroAddress();
        }

        MORPHO_BLUE = morphoBlue;
        VAULT = vault;
        LOAN_TOKEN = loanToken;
        COLLATERAL_TOKEN = collateralToken;
        ORACLE = oracle;
        IRM = irm;
        LLTV = lltv;
    }

    /**
     * @notice Returns the MarketParams struct describing the Morpho Blue market this helper targets.
     */
    function marketParams() public view returns (DecoderCustomTypes.MarketParams memory) {
        return DecoderCustomTypes.MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
    }

    /**
     * @notice Generates management calls for supplying assets into the Morpho Blue market
     * @param asset The ERC20 token address to be supplied. Must equal the configured LOAN_TOKEN.
     * @param amount The amount of tokens to supply
     * @return targets Array of contract addresses to call
     * @return data Array of encoded function calls
     * @return values Array of ETH values to send with each call (all 0 for ERC20 operations)
     * @dev Always resets approval to 0, sets new approval, then supplies to the Morpho Blue
     *      singleton (3 calls). The 3-call pattern is required for tokens (e.g. USDT) that
     *      disallow changing a non-zero allowance directly to another non-zero value.
     *
     *      Supply uses the `assets`-denominated form: assets = amount, shares = 0.
     *      No callback data is sent.
     *
     *      Reverts if `asset != LOAN_TOKEN` so that a misconfigured teller registration cannot
     *      silently approve / supply the wrong token.
     */
    function getDepositManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        if (asset != LOAN_TOKEN) revert MorphoMarketBufferHelper__AssetMismatch(asset, LOAN_TOKEN);
        targets = new address[](3);
        targets[0] = asset;
        targets[1] = asset;
        targets[2] = MORPHO_BLUE;
        data = new bytes[](3);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", MORPHO_BLUE, 0);
        data[1] = abi.encodeWithSignature("approve(address,uint256)", MORPHO_BLUE, amount);
        data[2] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            marketParams(),
            amount,
            uint256(0),
            VAULT,
            bytes("")
        );
        values = new uint256[](3);
    }

    /**
     * @notice Generates management calls for withdrawing assets from the Morpho Blue market
     * @param asset The ERC20 token address to withdraw. Must equal the configured LOAN_TOKEN.
     * @param amount The amount of the loan asset to withdraw
     * @return targets Array of contract addresses to call
     * @return data Array of encoded function calls
     * @return values Array of ETH values to send with each call (all 0 for ERC20 operations)
     * @dev Withdraws the specified amount of the loan asset from the configured Morpho Blue
     *      market back to the boring vault. Withdraw uses the `assets`-denominated form:
     *      assets = amount, shares = 0. `onBehalf` and `receiver` are both the boring vault.
     *
     *      Reverts if `asset != LOAN_TOKEN` so that a misconfigured teller registration cannot
     *      silently route a withdrawal of one asset into the wrong Morpho market.
     */
    function getWithdrawManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        if (asset != LOAN_TOKEN) revert MorphoMarketBufferHelper__AssetMismatch(asset, LOAN_TOKEN);
        targets = new address[](1);
        targets[0] = MORPHO_BLUE;
        data = new bytes[](1);
        data[0] = abi.encodeWithSignature(
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            marketParams(),
            amount,
            uint256(0),
            VAULT,
            VAULT
        );
        values = new uint256[](1);
        return (targets, data, values);
    }
}
