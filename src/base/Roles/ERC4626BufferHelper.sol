// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";

/**
 * @title ERC4626BufferHelper
 * @author Veda Tech Labs
 * @notice A buffer helper contract that integrates with any ERC4626 vault for automated yield generation
 * @dev Implements the IBufferHelper interface to provide ERC4626 integration for the TellerWithBuffer contract.
 * This helper automatically manages token approvals and deposit/withdraw operations to maximize yield on deposited assets.
 */
contract ERC4626BufferHelper is IBufferHelper {
    /// @notice The ERC4626 vault
    ERC4626 public immutable ERC_4626_VAULT;

    /// @notice The associated boring vault
    address public immutable VAULT;

    /**
     * @notice Initializes the ERC4626BufferHelper contract
     * @param _erc4626Vault The ERC4626 vault to deposit into / withdraw from
     * @param _vault The associated boring vault
     */
    constructor(address _erc4626Vault, address _vault) {
        ERC_4626_VAULT = ERC4626(_erc4626Vault);
        VAULT = _vault;
    }

    /**
     * @notice Generates management calls for depositing assets into the ERC4626 vault
     * @param asset The ERC20 token address to be deposited into the ERC4626 vault
     * @param amount The amount of tokens to deposit
     * @return targets Array of contract addresses to call
     * @return data Array of encoded function calls
     * @return values Array of ETH values to send with each call (all 0 for ERC20 operations)
     * @dev This function manages token approvals to cover all cases:
     *
     * - If current allowance >= amount: Only deposit into the ERC4626 vault (1 call)
     * - If current allowance == 0: Approve then deposit (2 calls)
     * - If 0 < current allowance < amount: Reset approval to 0, approve new amount, then deposit (3 calls)
     */
    function getDepositManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        address erc4626VaultAddress = address(ERC_4626_VAULT);
        uint256 currentAllowance = ERC20(asset).allowance(VAULT, erc4626VaultAddress);
        if (currentAllowance >= amount) {
            targets = new address[](1);
            targets[0] = erc4626VaultAddress;
            data = new bytes[](1);
            data[0] = abi.encodeWithSignature("deposit(uint256,address)", amount, VAULT);
            values = new uint256[](1);
            values[0] = 0;
        } else if (currentAllowance == 0) {
            targets = new address[](2);
            targets[0] = asset;
            targets[1] = erc4626VaultAddress;
            data = new bytes[](2);
            data[0] = abi.encodeWithSignature("approve(address,uint256)", erc4626VaultAddress, amount);
            data[1] = abi.encodeWithSignature("deposit(uint256,address)", amount, VAULT);
            values = new uint256[](2);
        } else {
            targets = new address[](3);
            targets[0] = asset;
            targets[1] = asset;
            targets[2] = erc4626VaultAddress;
            data = new bytes[](3);
            data[0] = abi.encodeWithSignature("approve(address,uint256)", erc4626VaultAddress, 0);
            data[1] = abi.encodeWithSignature("approve(address,uint256)", erc4626VaultAddress, amount);
            data[2] = abi.encodeWithSignature("deposit(uint256,address)", amount, VAULT);
            values = new uint256[](3);
        }
    }

    /**
     * @notice Generates management calls for withdrawing assets from the ERC4626 vault
     * @param amount The amount of tokens to withdraw
     * @return targets Array of contract addresses to call
     * @return data Array of encoded function calls
     * @return values Array of ETH values to send with each call (all 0 for ERC20 operations)
     * @dev Withdraws the specified amount of the underlying asset from the ERC4626 vault back to the boring vault.
     */
    function getWithdrawManageCall(
        address,
        /* asset */
        uint256 amount
    )
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        targets = new address[](1);
        targets[0] = address(ERC_4626_VAULT);
        data = new bytes[](1);
        data[0] = abi.encodeWithSignature("withdraw(uint256,address,address)", amount, VAULT, VAULT);
        values = new uint256[](1);
        return (targets, data, values);
    }
}
