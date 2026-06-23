// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {AaveV4BufferHelper} from "src/base/Roles/AaveV4BufferHelper.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {IBufferLens} from "src/interfaces/IBufferLens.sol";
import {IAaveV4Spoke} from "src/interfaces/IAaveV4Spoke.sol";
import {IAaveV4Hub} from "src/interfaces/IAaveV4Hub.sol";

contract AaveV4BufferLens is IBufferLens {
    /// @dev Spoke reserve flag bits: paused 0x01, frozen 0x02, borrowable 0x04, receiveShares 0x08.
    /// Only paused blocks withdrawals (frozen reserves still allow them).
    uint8 internal constant RESERVE_PAUSED_FLAG = 0x01;

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
            // If buffer helper is not address(0), withdraw buffer is an Aave V4 spoke reserve
            AaveV4BufferHelper aaveV4BufferHelper = AaveV4BufferHelper(address(withdrawBufferHelper));
            IAaveV4Spoke spoke = IAaveV4Spoke(aaveV4BufferHelper.aaveV4Spoke());
            // Revert (not return 0) when the asset is not a configured reserve for this helper:
            // reserveIdFor reverts on an unconfigured asset, and the require catches an underlying
            // mismatch — a misconfiguration should fail loudly, not silently return a quote.
            uint256 reserveId = aaveV4BufferHelper.reserveIdFor(address(asset));
            IAaveV4Spoke.Reserve memory reserve = spoke.getReserve(reserveId);
            require(reserve.underlying == address(asset), "AaveV4BufferLens: reserve asset mismatch");

            // Withdrawals revert outright when the reserve is paused on the spoke or the spoke is
            // inactive/halted on the hub, regardless of liquidity.
            if (reserve.flags & RESERVE_PAUSED_FLAG != 0) return 0;
            IAaveV4Hub.SpokeConfig memory spokeConfig =
                IAaveV4Hub(reserve.hub).getSpokeConfig(reserve.assetId, address(spoke));
            if (!spokeConfig.active || spokeConfig.halted) return 0;

            // With a zero spoke position every teller withdrawal reverts in the hub (zero-amount
            // remove), even when the vault holds idle balance, because the helper always routes
            // through Spoke.withdraw.
            uint256 suppliedAssets = spoke.getUserSuppliedAssets(reserveId, vault);
            if (suppliedAssets == 0) return 0;

            // getAssetLiquidity is the authoritative single-withdrawal bound: per IAaveV4Hub, Hub.remove
            // reverts above it regardless of the hub's ERC20 balance, so it already reflects any hub-side
            // limit on a withdrawal. The remaining SpokeConfig fields (addCap, drawCap, riskPremiumThreshold)
            // and the unused reserve flags (frozen/borrowable/receiveShares) gate supplies/borrows, not a
            // single user withdrawal, so they are intentionally not consulted for this quote.
            uint256 availableLiquidity = IAaveV4Hub(reserve.hub).getAssetLiquidity(reserve.assetId);
            if (suppliedAssets > availableLiquidity) {
                // Hub.remove reverts above the hub's available liquidity and the helper forwards
                // the full requested amount to Spoke.withdraw, so idle balance cannot extend the
                // bound here.
                withdrawableAmount = availableLiquidity;
            } else {
                // Spoke.withdraw clamps to the supplied balance (unlike Aave V3, which reverts
                // above it), so a teller withdrawal beyond the position succeeds with the vault's
                // idle balance covering the difference.
                withdrawableAmount = suppliedAssets + asset.balanceOf(vault);
            }
        }
    }
}
