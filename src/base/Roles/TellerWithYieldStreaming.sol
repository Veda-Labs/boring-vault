// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {TellerWithBuffer, ERC20} from "src/base/Roles/TellerWithBuffer.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";

contract TellerWithYieldStreaming is TellerWithBuffer {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    constructor(
        address _owner,
        address _vault,
        address _accountant,
        address _weth
    ) TellerWithBuffer(_owner, _vault, _accountant, _weth) {
        _getAccountant().lastVirtualSharePrice(); // Reverts if the accountant doesn't support lastVirtualSharePrice()
    }

    /**
     * @notice Allows off ramp role to withdraw from this contract.
     * @dev Publicly callable.
     */
    function withdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        override
        requiresAuth
        nonReentrant
        returns (uint256 assetsOut)
    {
        //update vested yield before withdraw
        _getAccountant().updateExchangeRate();
        beforeTransfer(msg.sender, address(0), msg.sender);
        assetsOut = _withdraw(withdrawAsset, shareAmount, minimumAssets, to);

        emit Withdraw(address(withdrawAsset), shareAmount);
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
        if (vault.totalSupply() == 0) {
            _getAccountant().setFirstDepositTimestamp(); 
        }
        _handleDenyList(from, to, msg.sender);
        uint112 cap = depositCap;
        if (depositAmount == 0) revert TellerWithMultiAssetSupport__ZeroAssets();
        shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(depositAsset) + 1); 
        shares = asset.sharePremium > 0 ? shares.mulDivDown(1e4 - asset.sharePremium, 1e4) : shares;
        if (shares < minimumMint) revert TellerWithMultiAssetSupport__MinimumMintNotMet();
        if (cap != type(uint112).max) {
            if (shares + vault.totalSupply() > cap) revert TellerWithMultiAssetSupport__DepositExceedsCap();
        }
        vault.enter(from, depositAsset, depositAmount, to, shares);
        _afterDeposit(depositAsset, depositAmount);
    }

    /**
     * @notice Allows off ramp role to withdraw from this contract.
     * @dev Callable by SOLVER_ROLE.
     */
    function bulkWithdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        override
        requiresAuth
        nonReentrant
        returns (uint256 assetsOut) {
        _getAccountant().updateExchangeRate();
        assetsOut = _withdraw(withdrawAsset, shareAmount, minimumAssets, to);
        emit BulkWithdraw(address(withdrawAsset), shareAmount);
    }

    /**
     * @notice Helper function to cast from base accountant type to yield streaming accountant
     */
    function _getAccountant() internal view returns (AccountantWithYieldStreaming) {
        return AccountantWithYieldStreaming(address(accountant));
    }

    /**
     * @notice Returns the version of the contract.
     */
    function version() public pure virtual override returns (string memory) {
        return string(abi.encodePacked("Yield Streaming V0.1, ", super.version()));
    }
}
