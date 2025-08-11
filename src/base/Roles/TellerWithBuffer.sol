// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport, ERC20} from "./TellerWithMultiAssetSupport.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

/**
 * @title TellerWithBuffer
 * @author Veda Tech Labs
 * @notice A teller contract that integrates with buffer helpers to manage deposits and withdrawals
 * @dev Extends TellerWithMultiAssetSupport to add automatic yield and withdrawal buffer capabilities.
 * The buffer helpers can trigger additional vault management calls during these operations.
 */
contract TellerWithBuffer is TellerWithMultiAssetSupport {
    /// @notice Buffer helper contract for managing deposits
    IBufferHelper public depositBufferHelper;

    /// @notice Buffer helper contract for managing withdrawals
    IBufferHelper public withdrawBufferHelper;

    /**
     * @notice Initializes the TellerWithBuffer contract
     * @param _owner The address that will have owner privileges
     * @param _vault The vault contract address this teller will interact with
     * @param _accountant The accountant contract address associated with the vault
     * @param _weth The WETH token address for ETH wrapping/unwrapping operations
     * @param _depositBufferHelper The buffer helper contract for deposit management
     * @param _withdrawBufferHelper The buffer helper contract for withdrawal management
     */
    constructor(
        address _owner,
        address _vault,
        address _accountant,
        address _weth,
        address _depositBufferHelper,
        address _withdrawBufferHelper
    ) TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth) {
        depositBufferHelper = IBufferHelper(_depositBufferHelper);
        withdrawBufferHelper = IBufferHelper(_withdrawBufferHelper);
    }

    /**
     * @notice Executes buffer management after a deposit operation
     * @param depositAsset The ERC20 token being deposited
     * @param assetAmount The amount of the asset being deposited
     * @dev This function is called internally after a deposit is processed.
     * If a deposit buffer helper is configured, it will retrieve management calls
     * and execute them through the vault's manage function.
     */
    function _afterDeposit(ERC20 depositAsset, uint256 assetAmount) internal override {
        if (address(depositBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) =
                depositBufferHelper.getDepositManageCall(address(depositAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }

    /**
     * @notice Executes buffer management before a withdrawal operation
     * @param withdrawAsset The ERC20 token being withdrawn
     * @param assetAmount The amount of the asset being withdrawn
     * @dev This function is called internally before a withdrawal is processed.
     * If a withdraw buffer helper is configured, it will retrieve management calls
     * and execute them through the vault's manage function.
     */
    function _beforeWithdraw(ERC20 withdrawAsset, uint256 assetAmount) internal override {
        if (address(withdrawBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) =
                withdrawBufferHelper.getWithdrawManageCall(address(withdrawAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }

    /**
     * @notice Updates the deposit buffer helper contract
     * @param _depositBufferHelper The new deposit buffer helper contract address
     * @dev Only callable by authorized accounts. This allows for dynamic updates
     * to the deposit management strategy without requiring contract redeployment.
     */
    function setDepositBufferHelper(address _depositBufferHelper) external requiresAuth {
        depositBufferHelper = IBufferHelper(_depositBufferHelper);
    }

    /**
     * @notice Updates the withdrawal buffer helper contract
     * @param _withdrawBufferHelper The new withdrawal buffer helper contract address
     * @dev Only callable by authorized accounts. This allows for dynamic updates
     * to the withdrawal management strategy without requiring contract redeployment.
     */
    function setWithdrawBufferHelper(address _withdrawBufferHelper) external requiresAuth {
        withdrawBufferHelper = IBufferHelper(_withdrawBufferHelper);
    }
}
