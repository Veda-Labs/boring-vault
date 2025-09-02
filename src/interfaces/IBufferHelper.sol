// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

interface IBufferHelper {
    /**
     * @notice Generates management calls to be executed after a deposit operation.
     * @dev Returns arrays of targets, calldata, and values for the vault to execute.
     * @param asset The address of the ERC20 token being deposited.
     * @param amount The amount of the asset being deposited.
     * @return targets Array of contract addresses to call.
     * @return data Array of encoded function calls.
     * @return values Array of ETH values to send with each call.
     */
    function getDepositManageCall(address asset, uint256 amount)
        external
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values);

    /**
     * @notice Generates management calls to be executed before a withdrawal operation.
     * @dev Returns arrays of targets, calldata, and values for the vault to execute.
     * @param asset The address of the ERC20 token being withdrawn.
     * @param amount The amount of the asset being withdrawn.
     * @return targets Array of contract addresses to call.
     * @return data Array of encoded function calls.
     * @return values Array of ETH values to send with each call.
     */
    function getWithdrawManageCall(address asset, uint256 amount)
        external
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values);
}
