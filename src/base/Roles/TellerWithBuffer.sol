// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport, ERC20} from "./TellerWithMultiAssetSupport.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

contract TellerWithBuffer is TellerWithMultiAssetSupport {
    IBufferHelper public bufferHelper;

    constructor(address _owner, address _vault, address _accountant, address _weth, address _bufferHelper)
        TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth)
    {
        bufferHelper = IBufferHelper(_bufferHelper);
    }

    function _postDepositHook(ERC20 depositAsset, uint256 depositAmount) internal override {
        if (address(bufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) =
                bufferHelper.getDepositManageCall(address(depositAsset), depositAmount);
            vault.manage(targets, data, values);
        }
    }

    function _preWithdrawHook(ERC20 withdrawAsset, uint256 shareAmount) internal override {
        if (address(bufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) =
                bufferHelper.getWithdrawManageCall(address(withdrawAsset), shareAmount);
            vault.manage(targets, data, values);
        }
    }

    function setBufferHelper(address _bufferHelper) external requiresAuth {
        bufferHelper = IBufferHelper(_bufferHelper);
    }
}
