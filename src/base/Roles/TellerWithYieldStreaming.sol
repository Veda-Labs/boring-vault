// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;
import {TellerWithMultiAssetSupport, ERC20} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
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

    function _erc20Deposit(
        ERC20 depositAsset,
        uint256 depositAmount,
        uint256 minimumMint,
        address from,
        address to,
        Asset memory asset
    ) internal override returns (uint256 shares) {
        uint112 cap = depositCap;
        if (depositAmount == 0) revert TellerWithMultiAssetSupport__ZeroAssets();
        shares = depositAmount.mulDivDown(ONE_SHARE, _getAccountant().getRateInQuoteForDeposit(depositAsset, depositAmount));
        shares = asset.sharePremium > 0 ? shares.mulDivDown(1e4 - asset.sharePremium, 1e4) : shares;
        if (shares < minimumMint) revert TellerWithMultiAssetSupport__MinimumMintNotMet();
        if (cap != type(uint112).max) {
            if (shares + vault.totalSupply() > cap) revert TellerWithMultiAssetSupport__DepositExceedsCap(); 
        }
        
        _getAccountant().recordDeposit(depositAsset, depositAmount); 

        vault.enter(from, depositAsset, depositAmount, to, shares);
    }

    function _getAccountant() internal returns (AccountantWithYieldStreaming) {
        return AccountantWithYieldStreaming(address(accountant)); 
    }

}



