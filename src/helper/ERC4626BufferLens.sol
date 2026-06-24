// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {ERC4626BufferHelper, IBufferHelper} from "src/base/Roles/ERC4626BufferHelper.sol";
import {IBufferLens} from "src/interfaces/IBufferLens.sol";

/// @notice Instantly-withdrawable quoter for a buffer backed by a generic ERC4626 vault.
///         View-only quote for UIs/keepers; not used in any value-moving path.
/// @dev Correctness is delegated to the wrapped vault's `maxWithdraw`: this lens is only as accurate as
///      that implementation. Per EIP-4626, a compliant `maxWithdraw` already factors in both available
///      liquidity AND any temporary withdrawal halt (returning 0 when withdrawals are disabled), so no
///      separate pause/liquidity check is performed here. Only use this lens for vaults whose `maxWithdraw`
///      is known to be liquidity- and pause-aware; vaults that over-report (e.g. ignore downstream
///      illiquidity) will make this lens over-report. Idle vault balance is excluded because the helper
///      routes the full amount through `erc4626.withdraw`, which reverts above `maxWithdraw`.
contract ERC4626BufferLens is IBufferLens {
    /// @notice Thrown when the queried asset is not the ERC4626 vault's underlying asset.
    error ERC4626BufferLens__AssetMismatch(address asset, address expected);

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
            // If buffer helper is not address(0), withdraw buffer is ERC4626
            ERC4626 erc4626Vault = ERC4626BufferHelper(address(withdrawBufferHelper)).ERC_4626_VAULT();
            if (address(erc4626Vault.asset()) != address(asset)) {
                revert ERC4626BufferLens__AssetMismatch(address(asset), address(erc4626Vault.asset()));
            }
            // Delegated to the vault's maxWithdraw (assumed liquidity- and pause-aware per EIP-4626).
            withdrawableAmount = erc4626Vault.maxWithdraw(vault);
        }
    }
}
