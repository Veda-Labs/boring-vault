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
import {IMorpho, Id, Market, MarketParams} from "src/interfaces/IMorpho.sol";

interface IMorphoV2Vault is IERC4626 {
    function liquidityAdapter() external view returns (address);
    function liquidityData() external view returns (bytes memory);
}

interface IMorphoMarketV1LiquidityAdapter {
    function morpho() external view returns (IMorpho);
    function adaptiveCurveIrm() external view returns (address);
    function allocation(MarketParams memory) external view returns (uint256);
    function expectedSupplyAssets(bytes32) external view returns (uint256);
}

interface IMorphoVaultV1LiquidityAdapter {
    function morphoVaultV1() external view returns (address);
    function allocation() external view returns (uint256);
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

            // Get the currently configured liquidity adapter sleeve.
            IMorphoV2Vault morphoV2Vault = IMorphoV2Vault(address(erc4626Vault));
            address liquidityAdapterAddress = morphoV2Vault.liquidityAdapter();
            if (liquidityAdapterAddress != address(0)) {
                withdrawableAmount += _getConfiguredLiquidity(
                    asset, liquidityAdapterAddress, morphoV2Vault.liquidityData()
                );
            }

            // Withdrawable cannot exceed this Boring Vault's ERC4626 share claim.
            if (withdrawableAmount > vaultAssets) {
                withdrawableAmount = vaultAssets;
            }
        }
    }

    function _getConfiguredLiquidity(ERC20 asset, address liquidityAdapterAddress, bytes memory liquidityData)
        internal
        view
        returns (uint256)
    {
        IMorphoVaultV1LiquidityAdapter morphoVaultV1Adapter = IMorphoVaultV1LiquidityAdapter(liquidityAdapterAddress);
        try morphoVaultV1Adapter.morphoVaultV1() returns (address morphoVaultV1) {
            return _getConfiguredVaultV1Liquidity(
                asset, morphoVaultV1Adapter, IERC4626(morphoVaultV1), liquidityAdapterAddress, liquidityData
            );
        } catch {
            return _getConfiguredMarketLiquidity(asset, liquidityAdapterAddress, liquidityData);
        }
    }

    function _getConfiguredVaultV1Liquidity(
        ERC20 asset,
        IMorphoVaultV1LiquidityAdapter liquidityAdapter,
        IERC4626 morphoVaultV1,
        address liquidityAdapterAddress,
        bytes memory liquidityData
    ) internal view returns (uint256) {
        if (liquidityData.length != 0) return 0;
        if (liquidityAdapter.allocation() == 0) return 0;
        if (address(morphoVaultV1) == address(0)) return 0;
        if (morphoVaultV1.asset() != address(asset)) return 0;

        return morphoVaultV1.maxWithdraw(liquidityAdapterAddress);
    }

    function _getConfiguredMarketLiquidity(ERC20 asset, address liquidityAdapterAddress, bytes memory liquidityData)
        internal
        view
        returns (uint256)
    {
        if (liquidityData.length == 0) return 0;

        if (liquidityData.length != 160) return 0;

        MarketParams memory marketParams = abi.decode(liquidityData, (MarketParams));
        IMorphoMarketV1LiquidityAdapter liquidityAdapter = IMorphoMarketV1LiquidityAdapter(liquidityAdapterAddress);
        if (marketParams.loanToken != address(asset)) return 0;
        if (marketParams.irm != liquidityAdapter.adaptiveCurveIrm()) return 0;
        if (liquidityAdapter.allocation(marketParams) == 0) return 0;

        IMorpho morpho = liquidityAdapter.morpho();
        bytes32 marketId = keccak256(abi.encode(marketParams));
        Market memory market = morpho.market(Id.wrap(marketId));

        if (market.totalSupplyAssets <= market.totalBorrowAssets) return 0;

        uint256 marketLiquidity = uint256(market.totalSupplyAssets) - market.totalBorrowAssets;
        uint256 morphoTokenLiquidity = asset.balanceOf(address(morpho));
        marketLiquidity = marketLiquidity > morphoTokenLiquidity ? morphoTokenLiquidity : marketLiquidity;

        uint256 adapterSupplyAssets = liquidityAdapter.expectedSupplyAssets(marketId);
        return marketLiquidity > adapterSupplyAssets ? adapterSupplyAssets : marketLiquidity;
    }
}
