// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

/**
 * @title AaveV3BufferHelper
 * @author Veda Tech Labs
 * @notice A buffer helper contract that integrates with Aave V3 lending pool for automated yield generation
 * @dev Implements the IBufferHelper interface to provide Aave V3 integration for the TellerWithBuffer contract.
 * This helper automatically manages token approvals and supply/withdraw operations to maximize yield on deposited assets.
 */
contract AaveV3BufferHelper is IBufferHelper {
    /// @notice Thrown when a critical constructor argument is the zero address.
    error AaveV3BufferHelper__ZeroAddress();

    /// @notice The Aave V3 lending pool
    address public immutable aaveV3Pool;

    /// @notice The associated vault
    address public immutable vault;

    /**
     * @notice Initializes the AaveV3BufferHelper contract
     * @param _aaveV3Pool The Aave V3 lending pool
     * @param _vault The associated vault
     */
    constructor(address _aaveV3Pool, address _vault) {
        // Both are immutable, so a zero address here can never be corrected post-deployment and would
        // silently misroute every deposit / withdraw. Matches the other buffer helpers' guard.
        if (_aaveV3Pool == address(0) || _vault == address(0)) revert AaveV3BufferHelper__ZeroAddress();
        aaveV3Pool = _aaveV3Pool;
        vault = _vault;
    }

    /**
     * @notice Generates management calls for depositing assets into Aave V3
     * @param asset The ERC20 token address to be supplied to Aave V3
     * @param amount The amount of tokens to supply
     * @return targets Array of contract addresses to call
     * @return data Array of encoded function calls
     * @return values Array of ETH values to send with each call (all 0 for ERC20 operations)
     * @dev Always resets the pool allowance to 0, sets the new allowance, then supplies (3 calls).
     *      This single fixed path covers every starting allowance (zero, stale partial, or ample) and
     *      is required for tokens such as USDT that return no value from approve and disallow changing
     *      a non-zero allowance directly to another non-zero value. Mirrors ERC4626BufferHelper /
     *      MorphoMarketBufferHelper / AaveV4BufferHelper.
     */
    function getDepositManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        targets = new address[](3);
        targets[0] = asset;
        targets[1] = asset;
        targets[2] = aaveV3Pool;
        data = new bytes[](3);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", aaveV3Pool, 0);
        data[1] = abi.encodeWithSignature("approve(address,uint256)", aaveV3Pool, amount);
        data[2] = abi.encodeWithSignature("supply(address,uint256,address,uint16)", asset, amount, vault, 0);
        values = new uint256[](3);
    }

    /**
     * @notice Generates management calls for withdrawing assets from Aave V3
     * @param asset The ERC20 token address to withdraw from Aave V3
     * @param amount The amount of tokens to withdraw
     * @return targets Array of contract addresses to call
     * @return data Array of encoded function calls
     * @return values Array of ETH values to send with each call (all 0 for ERC20 operations)
     * @dev Withdraws the specified amount of the asset from Aave V3 and returns it to the vault.
     */
    function getWithdrawManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        targets = new address[](1);
        targets[0] = aaveV3Pool;
        data = new bytes[](1);
        data[0] = abi.encodeWithSignature("withdraw(address,uint256,address)", asset, amount, vault);
        values = new uint256[](1);
        return (targets, data, values);
    }
}
