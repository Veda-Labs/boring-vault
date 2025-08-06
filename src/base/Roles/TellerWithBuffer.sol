// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport, ERC20} from "./TellerWithMultiAssetSupport.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

contract TellerWithBuffer is TellerWithMultiAssetSupport {
    IBufferHelper public depositBufferHelper;
    IBufferHelper public withdrawBufferHelper;

    constructor(address _owner, address _vault, address _accountant, address _weth, address _depositBufferHelper, address _withdrawBufferHelper)
        TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth)
    {
        depositBufferHelper = IBufferHelper(_depositBufferHelper);
        withdrawBufferHelper = IBufferHelper(_withdrawBufferHelper);
    }

    function _afterDeposit(ERC20 depositAsset, uint256 assetAmount) internal override {
        if (address(depositBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) =
                depositBufferHelper.getDepositManageCall(address(depositAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }

    function _beforeWithdraw(ERC20 withdrawAsset, uint256 assetAmount) internal override {
        if (address(withdrawBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) =
                withdrawBufferHelper.getWithdrawManageCall(address(withdrawAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }

    function setDepositBufferHelper(address _depositBufferHelper) external requiresAuth {
        depositBufferHelper = IBufferHelper(_depositBufferHelper);
    }

    function setWithdrawBufferHelper(address _withdrawBufferHelper) external requiresAuth {
        withdrawBufferHelper = IBufferHelper(_withdrawBufferHelper);
    }
}
