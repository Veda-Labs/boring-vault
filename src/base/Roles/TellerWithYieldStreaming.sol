// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21; import {TellerWithMultiAssetSupport, ERC20} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";

//NOTE: TEST CONTRACT -- NOT FINAL
contract TellerWithYieldStreaming is TellerWithMultiAssetSupport {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    constructor(address _owner, address _vault, address _accountant, address _weth) 
        TellerWithMultiAssetSupport(
            _owner,
            _vault,
            _accountant,
            _weth
        ) {}


    /**
     * @notice Allows off ramp role to withdraw from this contract.
     * @dev Callable by SOLVER_ROLE.
     */
    function bulkWithdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        override
        requiresAuth
        returns (uint256 assetsOut)
    {
        //TODO we need to get the order of operations correct here, something is off
        if (isPaused) revert TellerWithMultiAssetSupport__Paused();
        Asset memory asset = assetData[withdrawAsset];
        if (!asset.allowWithdraws) revert TellerWithMultiAssetSupport__AssetNotSupported();

        if (shareAmount == 0) revert TellerWithMultiAssetSupport__ZeroShares();
        assetsOut = shareAmount.mulDivDown(_getAccountant().getRateInBase(), ONE_SHARE);
        if (assetsOut < minimumAssets) revert TellerWithMultiAssetSupport__MinimumAssetsNotMet();

        vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
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

         // Update vested yield before deposit
        _getAccountant().updateVestedYield();

        uint112 cap = depositCap;
        if (depositAmount == 0) revert TellerWithMultiAssetSupport__ZeroAssets();
        shares = depositAmount.mulDivDown(ONE_SHARE, _getAccountant().getRateInBase());
        shares = asset.sharePremium > 0 ? shares.mulDivDown(1e4 - asset.sharePremium, 1e4) : shares;
        if (shares < minimumMint) revert TellerWithMultiAssetSupport__MinimumMintNotMet();
        if (cap != type(uint112).max) {
            if (shares + vault.totalSupply() > cap) revert TellerWithMultiAssetSupport__DepositExceedsCap(); 
        }

        vault.enter(from, depositAsset, depositAmount, to, shares);
    }

    function _getAccountant() internal returns (AccountantWithYieldStreaming) {
        return AccountantWithYieldStreaming(address(accountant)); 
    }
}
