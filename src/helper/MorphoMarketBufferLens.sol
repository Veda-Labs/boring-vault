// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {MorphoMarketBufferHelper} from "src/base/Roles/MorphoMarketBufferHelper.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {IBufferLens} from "src/interfaces/IBufferLens.sol";
import {IMorpho, Id, Market} from "src/interfaces/IMorpho.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

/// @notice Instantly-withdrawable quoter for a buffer backed by a single Morpho Blue market
///         (MorphoMarketBufferHelper). View-only quote for UIs/keepers; not used in any value-moving path.
/// @dev When the buffer is a Morpho Blue market, idle vault balance is intentionally excluded (matching
///      AaveV3BufferLens / ERC4626BufferLens, unlike AaveV4BufferLens): the helper routes the full amount
///      through `morpho.withdraw`, which reverts above either the vault's supply position or the market's
///      available liquidity rather than clamping, so idle balance cannot extend a single withdrawal.
contract MorphoMarketBufferLens is IBufferLens {
    /// @notice Morpho Blue SharesMathLib virtual amounts. Protocol constants used to convert the vault's
    ///         supply shares back to assets the same way Morpho does (rounding down).
    uint256 internal constant VIRTUAL_SHARES = 1e6;
    uint256 internal constant VIRTUAL_ASSETS = 1;

    /// @notice Thrown when the queried asset is not the market's configured loan token.
    error MorphoMarketBufferLens__LoanTokenMismatch(address asset, address expected);

    function getInstantlyWithdrawableAmount(TellerWithBuffer teller, ERC20 asset)
        external
        view
        returns (uint256 withdrawableAmount)
    {
        (, IBufferHelper withdrawBufferHelper) = teller.currentBufferHelpers(asset);
        address vault = address(teller.vault());
        if (address(withdrawBufferHelper) == address(0)) {
            // If buffer helper is address(0), withdraw buffer is idle ERC20 in the vault
            withdrawableAmount = asset.balanceOf(vault);
        } else {
            // If buffer helper is not address(0), withdraw buffer is a single Morpho Blue market
            MorphoMarketBufferHelper helper = MorphoMarketBufferHelper(address(withdrawBufferHelper));

            // Revert (not return 0) on a misconfigured (asset, helper) pair so a misconfiguration fails
            // loudly rather than returning a quote for the wrong token, matching the other lenses.
            address loanToken = helper.LOAN_TOKEN();
            if (loanToken != address(asset)) {
                revert MorphoMarketBufferLens__LoanTokenMismatch(address(asset), loanToken);
            }

            IMorpho morpho = IMorpho(helper.MORPHO_BLUE());
            DecoderCustomTypes.MarketParams memory marketParams = helper.marketParams();
            Id marketId = Id.wrap(keccak256(abi.encode(marketParams)));

            Market memory market = morpho.market(marketId);

            // The vault's supplied assets, converted from supply shares with Morpho's down-rounding share
            // math. Uses the stored (pre-accrual) market totals — Morpho accrues interest on withdraw — so
            // this slightly understates the position, which is the safe (conservative) direction for a quote.
            uint256 suppliedAssets = Math.mulDiv(
                morpho.position(marketId, vault).supplyShares,
                uint256(market.totalSupplyAssets) + VIRTUAL_ASSETS,
                uint256(market.totalSupplyShares) + VIRTUAL_SHARES
            );

            // Liquidity available to withdraw from the market = supply - borrow, capped by the loan tokens
            // the Morpho singleton actually holds (the singleton pools every market's idle liquidity).
            uint256 marketLiquidity;
            if (market.totalSupplyAssets > market.totalBorrowAssets) {
                marketLiquidity = uint256(market.totalSupplyAssets) - market.totalBorrowAssets;
            }
            marketLiquidity = Math.min(marketLiquidity, asset.balanceOf(address(morpho)));

            withdrawableAmount = Math.min(suppliedAssets, marketLiquidity);
        }
    }
}
