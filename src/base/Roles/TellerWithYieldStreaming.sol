// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {TellerWithBuffer, ERC20} from "src/base/Roles/TellerWithBuffer.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";

contract TellerWithYieldStreaming is TellerWithBuffer {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    constructor(
        address _owner,
        address _vault,
        address _accountant,
        address _weth,
        address _depositBufferHelper,
        address _withdrawBufferHelper
    ) TellerWithBuffer(_owner, _vault, _accountant, _weth, _depositBufferHelper, _withdrawBufferHelper) {}

    /**
     * @notice Allows off ramp role to withdraw from this contract.
     * @dev Publicly callable.
     */
    function bulkWithdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        override
        requiresAuth
        returns (uint256 assetsOut)
    {
        //update vested yield before withdraw
        _getAccountant().updateExchangeRate();

        if (isPaused) revert TellerWithMultiAssetSupport__Paused();
        Asset memory asset = assetData[withdrawAsset];
        if (!asset.allowWithdraws) revert TellerWithMultiAssetSupport__AssetNotSupported();

        if (shareAmount == 0) revert TellerWithMultiAssetSupport__ZeroShares();
        assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), ONE_SHARE);
        if (assetsOut < minimumAssets) revert TellerWithMultiAssetSupport__MinimumAssetsNotMet();
        _beforeWithdraw(withdrawAsset, assetsOut);
        vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
        _getAccountant().updateCumulative();
        emit BulkWithdraw(address(withdrawAsset), shareAmount);
    }

    function _erc20Deposit(
        ERC20 depositAsset,
        uint256 depositAmount,
        uint256 minimumMint,
        address from,
        address to,
        Asset memory asset
    ) internal override returns (uint256 shares) {
        //update vested yield before deposit
        _getAccountant().updateExchangeRate();
        shares = super._erc20Deposit(depositAsset, depositAmount, minimumMint, from, to, asset);
        _getAccountant().updateCumulative();
    }

    /**
     * @notice Helper function to cast from base accountant type to yield streaming accountant
     */
    function _getAccountant() internal view returns (AccountantWithYieldStreaming) {
        return AccountantWithYieldStreaming(address(accountant));
    }
}
