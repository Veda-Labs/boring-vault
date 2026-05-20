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

interface IMorphoV2Vault is IERC4626 {
    function liquidityAdapter() external view returns (address);
    function liquidityData() external view returns (bytes memory);
}

interface ILiquidityAdapter {
    function morpho() external view returns (IMorpho);
    function expectedSupplyAssets(bytes32) external view returns (uint256);
}

contract MorphoV2ERC4626BufferLens is IBufferLens {
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

            uint256 vaultAssets = erc4626Vault.previewRedeem(erc4626Vault.balanceOf(vault));

            // Withdrawable is at least idle capital in the ERC4626 vault.
            withdrawableAmount = asset.balanceOf(address(erc4626Vault));

            // Get the currently configured liquidity adapter market.
            IMorphoV2Vault morphoV2Vault = IMorphoV2Vault(address(erc4626Vault));
            address liquidityAdapterAddress = morphoV2Vault.liquidityAdapter();
            if (liquidityAdapterAddress != address(0)) {
                withdrawableAmount += _getConfiguredMarketLiquidity(
                    asset, liquidityAdapterAddress, morphoV2Vault.liquidityData()
                );
            }

            // Withdrawable cannot exceed this Boring Vault's ERC4626 share claim.
            if (withdrawableAmount > vaultAssets) {
                withdrawableAmount = vaultAssets;
            }
        }
    }

    function _getConfiguredMarketLiquidity(ERC20 asset, address liquidityAdapterAddress, bytes memory liquidityData)
        internal
        view
        returns (uint256)
    {
        if (liquidityData.length == 0) return 0;

        ILiquidityAdapter liquidityAdapter = ILiquidityAdapter(liquidityAdapterAddress);
        IMorpho morpho = liquidityAdapter.morpho();
        bytes32 marketId = keccak256(liquidityData);
        Market memory market = morpho.market(Id.wrap(marketId));

        if (market.totalSupplyAssets <= market.totalBorrowAssets) return 0;

        uint256 marketLiquidity = uint256(market.totalSupplyAssets) - market.totalBorrowAssets;
        uint256 morphoTokenLiquidity = asset.balanceOf(address(morpho));
        marketLiquidity = marketLiquidity > morphoTokenLiquidity ? morphoTokenLiquidity : marketLiquidity;

        uint256 adapterSupplyAssets = liquidityAdapter.expectedSupplyAssets(marketId);
        return marketLiquidity > adapterSupplyAssets ? adapterSupplyAssets : marketLiquidity;
    }
}
