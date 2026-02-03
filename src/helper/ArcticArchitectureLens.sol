// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault, ERC20} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {AaveV3BufferHelper} from "src/base/Roles/AaveV3BufferHelper.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IPoolExtended is IPool {
    function getReserveATokenAddress(address asset) external view returns (address);
}

contract ArcticArchitectureLens {
    using FixedPointMathLib for uint256;
    using Address for address;

    /**
     * @dev Calculates the total assets held in the BoringVault for a given vault and accountant.
     * @param boringVault The BoringVault contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @return asset The ERC20 asset, `assets` is given in terms of.
     * @return assets The total assets held in the vault.
     */
    function totalAssets(BoringVault boringVault, AccountantWithRateProviders accountant)
        external
        view
        returns (ERC20 asset, uint256 assets)
    {
        uint256 totalSupply = boringVault.totalSupply();
        uint256 rate = accountant.getRate();
        uint8 shareDecimals = boringVault.decimals();
        asset = accountant.base();

        assets = totalSupply.mulDivDown(rate, 10 ** shareDecimals);
    }

    /**
     * @dev Calculates the number of shares that will be received for a given deposit amount in the BoringVault.
     * @param depositAsset The ERC20 asset being deposited.
     * @param depositAmount The amount of the asset being deposited.
     * @param boringVault The BoringVault contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @return shares The number of shares that will be received.
     */
    function previewDeposit(
        ERC20 depositAsset,
        uint256 depositAmount,
        BoringVault boringVault,
        AccountantWithRateProviders accountant
    ) external view returns (uint256 shares) {
        uint8 shareDecimals = boringVault.decimals();

        shares = depositAmount.mulDivDown(10 ** shareDecimals, accountant.getRateInQuote(depositAsset));
    }

    /**
     * @dev Retrieves the balance of shares for a given account in the BoringVault.
     * @param account The address of the account.
     * @param boringVault The BoringVault contract.
     * @return shares The balance of shares for the account.
     */
    function balanceOf(address account, BoringVault boringVault) external view returns (uint256 shares) {
        shares = boringVault.balanceOf(account);
    }

    /**
     * @dev Calculates the balance of a user in terms of asset for a given account in the BoringVault.
     * @param account The address of the account.
     * @param boringVault The BoringVault contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @return assets The balance of assets for the account.
     */
    function balanceOfInAssets(address account, BoringVault boringVault, AccountantWithRateProviders accountant)
        external
        view
        returns (uint256 assets)
    {
        uint256 shares = boringVault.balanceOf(account);
        uint256 rate = accountant.getRate();
        uint8 shareDecimals = boringVault.decimals();

        assets = shares.mulDivDown(rate, 10 ** shareDecimals);
    }

    /**
     * @dev Retrieves the current exchange rate from the AccountantWithRateProviders contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @return rate The current exchange rate.
     */
    function exchangeRate(AccountantWithRateProviders accountant) external view returns (uint256 rate) {
        rate = accountant.getRate();
    }

    /**
     * @dev Checks if a user's deposit meets certain conditions.
     * @param account The address of the user.
     * @param depositAsset The ERC20 asset being deposited.
     * @param depositAmount The amount of the asset being deposited.
     * @param boringVault The BoringVault contract.
     * @param teller The TellerWithMultiAssetSupport contract.
     * @return A boolean indicating if the user's deposit meets the conditions.
     */
    function checkUserDeposit(
        address account,
        ERC20 depositAsset,
        uint256 depositAmount,
        BoringVault boringVault,
        TellerWithMultiAssetSupport teller
    ) external view returns (bool) {
        if (depositAsset.balanceOf(account) < depositAmount) return false;
        if (depositAsset.allowance(account, address(boringVault)) < depositAmount) return false;
        if (teller.isPaused()) return false;
        (bool allowDeposits,,) = teller.assetData(depositAsset);
        if (!allowDeposits) return false;
        return true;
    }

    /**
     * @dev Checks if a user's deposit (with permit) meets certain conditions.
     * @param account The address of the user.
     * @param depositAsset The ERC20 asset being deposited.
     * @param depositAmount The amount of the asset being deposited.
     * @param teller The TellerWithMultiAssetSupport contract.
     * @return A boolean indicating if the user's deposit meets the conditions.
     */
    function checkUserDepositWithPermit(
        address account,
        ERC20 depositAsset,
        uint256 depositAmount,
        TellerWithMultiAssetSupport teller
    ) external view returns (bool) {
        if (depositAsset.balanceOf(account) < depositAmount) return false;
        if (teller.isPaused()) return false;
        (bool allowDeposits,,) = teller.assetData(depositAsset);
        if (!allowDeposits) return false;
        return true;
    }

    /**
     * @dev Retrieves the unlock time for a user's shares in the TellerWithMultiAssetSupport contract.
     * @param account The address of the user.
     * @param teller The TellerWithMultiAssetSupport contract.
     * @return time The unlock time for the user's shares.
     */
    function userUnlockTime(address account, TellerWithMultiAssetSupport teller) external view returns (uint256 time) {
        (,,,, time) = teller.beforeTransferData(account);
    }

    /**
     * @notice Checks if the TellerWithMultiAssetDepositSupport contract is paused.
     */
    function isTellerPaused(TellerWithMultiAssetSupport teller) external view returns (bool) {
        return teller.isPaused();
    }

    /**
     */
    function getWithdrawAsset(address asset, BoringOnChainQueue queue)
        public
        view
        returns (BoringOnChainQueue.WithdrawAsset memory withdrawAsset)
    {
        (
            withdrawAsset.allowWithdraws,
            withdrawAsset.secondsToMaturity,
            withdrawAsset.minimumSecondsToDeadline,
            withdrawAsset.minDiscount,
            withdrawAsset.maxDiscount,
            withdrawAsset.minimumShares,
            withdrawAsset.withdrawCapacity
        ) = queue.withdrawAssets(asset);
    }

    function getWithdrawAssets(
        address[] calldata assets,
        BoringOnChainQueue queue
    )
        external
        view
        returns (BoringOnChainQueue.WithdrawAsset[] memory withdrawAssets)
    {
        uint256 assetsLength = assets.length;
        withdrawAssets = new BoringOnChainQueue.WithdrawAsset[](assetsLength);

        for (uint256 i = 0; i < assetsLength; i++) {
            withdrawAssets[i] = getWithdrawAsset(assets[i], queue);
        }
    }

    /**
     * @notice Helper function to preview the assets out for a given asset and amount of shares.
     * @param queue The BoringOnChainQueue contract.
     * @param assetOut The asset to preview the assets out for.
     * @param amountOfShares The amount of shares to preview the assets out for.
     * @param discount The discount to apply to the assets out.
     * @return amountOfAssets The amount of assets out.
     */
    function previewAssetsOut(BoringOnChainQueue queue, address assetOut, uint128 amountOfShares, uint16 discount)
        external
        view
        returns (uint128 amountOfAssets)
    {
        amountOfAssets = queue.previewAssetsOut(assetOut, amountOfShares, discount);
    }

    struct PreviewWithdrawResult {
        uint256 assetsOut;
        bool withdrawsNotAllowed;
        bool withdrawNotMatured;
        bool deadlinePassed;
        bool noShares;
        bool notEnoughAssetsForWithdraw;
    }

    /**
     * @notice Helper function to preview a users withdraw for a specific asset.
     */
    function previewWithdraw(
        ERC20 asset,
        BoringOnChainQueue.OnChainWithdraw memory req,
        BoringVault boringVault,
        BoringOnChainQueue queue
    ) public view returns (PreviewWithdrawResult memory res) {
        BoringOnChainQueue.WithdrawAsset memory withdrawAsset = getWithdrawAsset(address(asset), queue);

        if (!withdrawAsset.allowWithdraws) res.withdrawsNotAllowed = true;

        uint256 maturity = uint256(req.creationTime) + uint256(req.secondsToMaturity);
        if (block.timestamp < maturity) res.withdrawNotMatured = true;

        uint256 deadline = maturity + uint256(req.secondsToDeadline);
        if (block.timestamp > deadline) res.deadlinePassed = true;

        if (req.amountOfShares == 0) res.noShares = true;

        // In BoringOnChainQueue, amountOfAssets is pre-calculated at request time
        res.assetsOut = req.amountOfAssets;

        if (asset.balanceOf(address(boringVault)) < res.assetsOut) {
            res.notEnoughAssetsForWithdraw = true;
        }
    }

    /**
     * @notice Helper function to preview multiple users withdraw requests.
     */
    function previewWithdraws(
        BoringOnChainQueue.OnChainWithdraw[] calldata requests,
        BoringVault boringVault,
        BoringOnChainQueue queue
    ) external view returns (PreviewWithdrawResult[] memory res) {
        uint256 requestsLength = requests.length;
        res = new PreviewWithdrawResult[](requestsLength);

        for (uint256 i = 0; i < requestsLength; i++) {
            res[i] = previewWithdraw(ERC20(requests[i].assetOut), requests[i], boringVault, queue);
        }
    }

    struct PreviewInstantWithdrawResult {
        uint256 assetsOut;
        bool tellerPaused;
        bool withdrawsNotAllowed;
        bool noShares;
        bool sharesLocked;
        bool notEnoughWithdrawableAssets;
        bool minimumAssetsNotMet;
    }

    /**
     * @notice Helper function to preview an instant withdraw through TellerWithYieldStreaming.
     * @param account The address of the user withdrawing.
     * @param withdrawAsset The asset to withdraw.
     * @param shareAmount The amount of shares to withdraw.
     * @param boringVault The BoringVault contract.
     * @param accountant The AccountantWithRateProviders contract.
     * @param teller The TellerWithYieldStreaming contract.
     */
    function previewInstantWithdraw(
        address account,
        ERC20 withdrawAsset,
        uint256 shareAmount,
        uint256 minimumAssets,
        BoringVault boringVault,
        AccountantWithRateProviders accountant,
        TellerWithYieldStreaming teller
    ) external view returns (PreviewInstantWithdrawResult memory res) {
        if (teller.isPaused()) res.tellerPaused = true;

        (,bool allowWithdraws,) = teller.assetData(withdrawAsset);
        if (!allowWithdraws) res.withdrawsNotAllowed = true;

        if (shareAmount == 0) res.noShares = true;

        // Check if user's shares are locked
        (,,,, uint256 shareUnlockTime) = teller.beforeTransferData(account);
        if (shareUnlockTime > block.timestamp) res.sharesLocked = true;

        // Calculate expected assets out
        {
            uint8 shareDecimals = boringVault.decimals();
            res.assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), 10 ** shareDecimals);
            if (res.assetsOut < minimumAssets) res.minimumAssetsNotMet = true;
        }

        // Withdrawable amount is at least the balance of the asset in the vault
        uint256 withdrawable = withdrawAsset.balanceOf(address(boringVault));
        // Check if there is a buffer helper for the asset
        (, IBufferHelper withdrawBufferHelper) = teller.currentBufferHelpers(withdrawAsset);
        if (address(withdrawBufferHelper) != address(0)) {
            // We only support AaveV3 supply-only buffer helpers for now
            try AaveV3BufferHelper(address(withdrawBufferHelper)).aaveV3Pool() returns (address aaveV3Pool) {
                (uint256 totalCollateralBase,,,,,) = IPool(aaveV3Pool).getUserAccountData(address(boringVault));
                if (totalCollateralBase > 0) {
                    revert("Unsupported calculation: AaveV3 pool has borrowed assets");
                }
                ERC20 aToken = ERC20(IPoolExtended(aaveV3Pool).getReserveATokenAddress(address(withdrawAsset)));
                withdrawable += aToken.balanceOf(address(boringVault));
            } catch {
                revert("Unsupported buffer type: AaveV3 pool not found");
            }
        }

        if (withdrawable < res.assetsOut) {
            res.notEnoughWithdrawableAssets = true;
        }
    }
}
