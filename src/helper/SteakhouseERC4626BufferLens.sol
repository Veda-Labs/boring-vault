// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {ERC4626BufferHelper, IBufferHelper} from "src/base/Roles/ERC4626BufferHelper.sol";
import {IBufferLens} from "src/interfaces/IBufferLens.sol";
import {IMorpho, Id, Market} from "src/interfaces/IMorpho.sol";

interface ISteakhouseVault is IERC4626 {
    function liquidityAdapter() external view returns (address);
}

interface ILiquidityAdapter {
    function marketIdsLength() external view returns (uint256);
    function marketIds(uint256) external view returns (Id);
    function morpho() external view returns (IMorpho);
}

contract SteakhouseERC4626BufferLens is IBufferLens {
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
            require(erc4626Vault.asset() == asset, "ERC4626BufferLens: Vault asset mismatch");

            // Withdrawable is at least idle capital
            withdrawableAmount = asset.balanceOf(address(erc4626Vault));

            // Get liquidity adapter and Morpho markets
            ISteakhouseVault steakhouseVault = ISteakhouseVault(address(erc4626Vault));
            ILiquidityAdapter liquidityAdapter = ILiquidityAdapter(steakhouseVault.liquidityAdapter());
            IMorpho morpho = liquidityAdapter.morpho();
            uint256 marketIdsLength = liquidityAdapter.marketIdsLength();
            // Get total supplied/borrowed
            uint256 overallSupplyAssets;
            uint256 overallBorrowAssets;
            for (uint256 i = 0; i < marketIdsLength; i++) {
                Id marketId = liquidityAdapter.marketIds(i);
                Market memory market = morpho.market(marketId);
                overallSupplyAssets += market.totalSupplyAssets;
                overallBorrowAssets += market.totalBorrowAssets;
            }
            // If more is borrowed than supplied, there is no liquidity in the markets. Else add supplied less borrowed
            if (overallSupplyAssets > overallBorrowAssets) {
                withdrawableAmount += overallSupplyAssets - overallBorrowAssets;
            }
            // Withdrawable cannot be more than vault's reported totalAssets
            uint256 totalVaultAssets = steakhouseVault.totalAssets();
            if (withdrawableAmount > totalVaultAssets) {
                withdrawableAmount = totalVaultAssets;
            }
        }
    }
}
