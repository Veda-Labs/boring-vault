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
    //============================== STRUCTS ===============================
    struct BufferHelpers {
        IBufferHelper depositBufferHelper;
        IBufferHelper withdrawBufferHelper;
    }

    //============================== STATE ===============================
    mapping(ERC20 => BufferHelpers) public currentBufferHelpers;

    mapping(ERC20 => mapping(IBufferHelper => bool)) public allowedBufferHelpers;

    //============================== ERRORS ===============================
    error TellerWithBuffer__BufferHelperNotAllowed(ERC20 asset, IBufferHelper bufferHelper);

    //============================== EVENTS ===============================
    event DepositBufferHelperSet(ERC20 indexed asset, IBufferHelper indexed newDepositBufferHelper);
    event WithdrawBufferHelperSet(ERC20 indexed asset, IBufferHelper indexed newWithdrawBufferHelper);
    event BufferHelperAllowed(ERC20 indexed asset, IBufferHelper indexed bufferHelper);
    event BufferHelperDisallowed(ERC20 indexed asset, IBufferHelper indexed bufferHelper);

    /**
     * @notice Initializes the TellerWithBuffer contract
     * @param _owner The address that will have owner privileges
     * @param _vault The vault contract address this teller will interact with
     * @param _accountant The accountant contract address associated with the vault
     * @param _weth The WETH token address for ETH wrapping/unwrapping operations
     */
    constructor(address _owner, address _vault, address _accountant, address _weth)
        TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth)
    {}

    /**
     * @notice Executes buffer management after a deposit operation
     * @param depositAsset The ERC20 token being deposited
     * @param assetAmount The amount of the asset being deposited
     * @dev This function is called internally after a deposit is processed.
     * If a deposit buffer helper is configured, it will retrieve management calls
     * and execute them through the vault's manage function.
     */
    function _afterDeposit(ERC20 depositAsset, uint256 assetAmount) internal override {
        if (address(currentBufferHelpers[depositAsset].depositBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) = currentBufferHelpers[
                    depositAsset
                ]
                .depositBufferHelper
                .getDepositManageCall(address(depositAsset), assetAmount);
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
        if (address(currentBufferHelpers[withdrawAsset].withdrawBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) = currentBufferHelpers[
                    withdrawAsset
                ]
                .withdrawBufferHelper
                .getWithdrawManageCall(address(withdrawAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }

    /**
     * @notice Updates the deposit buffer helper contract
     * @param _asset The asset to update the buffer helper for
     * @param _depositBufferHelper The new deposit buffer helper contract address
     * @dev Only callable by authorized accounts. This allows for dynamic updates
     * to the deposit management strategy without requiring contract redeployment.
     */
    function setDepositBufferHelper(ERC20 _asset, IBufferHelper _depositBufferHelper) external requiresAuth {
        if (allowedBufferHelpers[_asset][_depositBufferHelper] || _depositBufferHelper == IBufferHelper(address(0))) {
            currentBufferHelpers[_asset].depositBufferHelper = _depositBufferHelper;
            emit DepositBufferHelperSet(_asset, _depositBufferHelper);
        } else {
            revert TellerWithBuffer__BufferHelperNotAllowed(_asset, _depositBufferHelper);
        }
    }

    /**
     * @notice Updates the withdrawal buffer helper contract
     * @param _asset The asset to update the buffer helper for
     * @param _withdrawBufferHelper The new withdrawal buffer helper contract address
     * @dev Only callable by authorized accounts. This allows for dynamic updates
     * to the withdrawal management strategy without requiring contract redeployment.
     */
    function setWithdrawBufferHelper(ERC20 _asset, IBufferHelper _withdrawBufferHelper) external requiresAuth {
        if (allowedBufferHelpers[_asset][_withdrawBufferHelper] || _withdrawBufferHelper == IBufferHelper(address(0))) {
            currentBufferHelpers[_asset].withdrawBufferHelper = _withdrawBufferHelper;
            emit WithdrawBufferHelperSet(_asset, _withdrawBufferHelper);
        } else {
            revert TellerWithBuffer__BufferHelperNotAllowed(_asset, _withdrawBufferHelper);
        }
    }

    /**
     * @notice Allows a buffer helper to be used for a specific asset
     * @param _asset The asset to allow the buffer helper for
     * @param _bufferHelper The buffer helper contract address to allow
     * @dev Only callable by admin to allowlist buffer helpers for a specific asset
     */
    function allowBufferHelper(ERC20 _asset, IBufferHelper _bufferHelper) external requiresAuth {
        allowedBufferHelpers[_asset][_bufferHelper] = true;
        emit BufferHelperAllowed(_asset, _bufferHelper);
    }

    /**
     * @notice Disallows a buffer helper from being used for a specific asset
     * @param _asset The asset to disallow the buffer helper for
     * @param _bufferHelper The buffer helper contract address to disallow
     * @dev Only callable by admin to disallow buffer helpers for a specific asset
     */
    function disallowBufferHelper(ERC20 _asset, IBufferHelper _bufferHelper) external requiresAuth {
        allowedBufferHelpers[_asset][_bufferHelper] = false;
        emit BufferHelperDisallowed(_asset, _bufferHelper);
    }

    /**
     * @notice Returns the version of the contract.
     */
    function version() public pure virtual override returns (string memory) {
        return string(abi.encodePacked("Buffer V0.1, ", super.version()));
    }
}
