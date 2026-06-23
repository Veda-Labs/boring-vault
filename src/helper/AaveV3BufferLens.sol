// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {AaveV3BufferHelper, IBufferHelper} from "src/base/Roles/AaveV3BufferHelper.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IBufferLens} from "src/interfaces/IBufferLens.sol";

contract AaveV3BufferLens is IBufferLens {
    /// @notice Amount of `asset` instantly withdrawable from the vault's buffer for `teller`.
    /// @dev Returns 0 when the Aave V3 reserve is paused or inactive (a withdrawal would revert
    /// regardless of liquidity), mirroring AaveV4BufferLens. When the buffer is an Aave V3 reserve,
    /// idle vault balance is intentionally excluded (unlike the idle-ERC20 branch and AaveV4BufferLens):
    /// AaveV3BufferHelper routes the full amount through aaveV3Pool.withdraw, which reverts above the
    /// aToken balance rather than clamping, so idle balance cannot extend a single withdrawal.
    /// View-only quote for UIs/keepers; not used in any value-moving path.
    function getInstantlyWithdrawableAmount(TellerWithBuffer teller, ERC20 asset) external view returns (uint256 withdrawableAmount) {
        (, IBufferHelper withdrawBufferHelper) = teller.currentBufferHelpers(asset);
        address vault = address(teller.vault());
        if (address(withdrawBufferHelper) == address(0)) {
            // If buffer helper is address(0), withdraw buffer is idle ERC20 in the vault
            withdrawableAmount = asset.balanceOf(vault);
        } else {
            // If buffer helper is not address(0), withdraw buffer is Aave V3
            address aaveV3Pool = AaveV3BufferHelper(address(withdrawBufferHelper)).aaveV3Pool();

            // A withdrawal reverts while the reserve is paused or inactive, regardless of liquidity,
            // so nothing is instantly withdrawable. Aave V3 config bitmap: bit 56 = active,
            // bit 60 = paused (frozen, bit 57, still permits withdrawals and is not excluded).
            uint256 reserveConfig = IPool(aaveV3Pool).getConfiguration(address(asset)).data;
            bool isActive = (reserveConfig >> 56) & 1 != 0;
            bool isPaused = (reserveConfig >> 60) & 1 != 0;
            if (!isActive || isPaused) return 0;

            address aTokenAddress = IPool(aaveV3Pool).getReserveData(address(asset)).aTokenAddress;
            // Revert (not return 0) on a misconfigured (asset, helper) pair: an unlisted reserve yields
            // aToken == 0 (TellerWithBuffer does not verify on-chain that the helper's pool lists the
            // asset). Fail loudly — matches the require-on-mismatch pattern in the sibling lenses.
            require(aTokenAddress != address(0), "AaveV3BufferLens: reserve not listed");
            ERC20 aToken = ERC20(aTokenAddress);

            uint256 aTokenBalance = aToken.balanceOf(vault);
            uint256 availableLiquidity = asset.balanceOf(aTokenAddress);
            withdrawableAmount = aTokenBalance > availableLiquidity ? availableLiquidity : aTokenBalance;
        }
    }
}