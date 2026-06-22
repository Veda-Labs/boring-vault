// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {IAaveV4Spoke} from "src/interfaces/IAaveV4Spoke.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/**
 * @title AaveV4BufferHelper
 * @author Veda Tech Labs
 * @notice A buffer helper contract that integrates with an Aave V4 spoke for automated yield generation
 * @dev Implements the IBufferHelper interface to provide Aave V4 integration for the TellerWithBuffer contract.
 * Aave V4 identifies reserves by a per-spoke uint256 reserveId rather than the asset address, so the
 * helper is constructed with the reserveIds it serves and derives each reserve's underlying asset from
 * the spoke itself, so an asset/reserve mismatch cannot be configured. A spoke may list the same
 * underlying under several reserveIds against different hubs (the deployed Bluechip spoke does for
 * USDC and USDT), so duplicate underlyings revert: each asset maps to exactly one reserve. The spoke
 * is the approval spender (it transfers supplied funds to its hub), and withdrawn funds are always
 * sent to the caller (the vault).
 *
 * Operational note: the helper always routes through the spoke, so venue states that reject supplies
 * (frozen/paused reserve, hub add cap, inactive/halted spoke) revert teller deposits until the deposit
 * helper is unset, and states that reject withdrawals (paused reserve, inactive/halted spoke) revert
 * instant withdrawals until strategists exit the position. AaveV4BufferLens mirrors the withdraw-side
 * states by quoting zero.
 */
contract AaveV4BufferHelper is IBufferHelper {
    error AaveV4BufferHelper__ZeroAddress();
    error AaveV4BufferHelper__NoReserveIds();
    error AaveV4BufferHelper__DuplicateUnderlying(address underlying);
    error AaveV4BufferHelper__AssetNotConfigured(address asset);

    /// @notice The Aave V4 spoke
    address public immutable aaveV4Spoke;

    /// @notice The associated vault
    address public immutable vault;

    /// @notice Underlying asset => reserveId + 1 on the spoke. Stored offset by one because
    /// reserveId 0 is valid on Aave V4 and 0 marks an unconfigured asset.
    mapping(address => uint256) public reserveIdPlusOne;

    /**
     * @notice Initializes the AaveV4BufferHelper contract
     * @param _aaveV4Spoke The Aave V4 spoke
     * @param _vault The associated vault
     * @param _reserveIds The spoke reserveIds this helper serves; each reserve's underlying asset is
     * read from the spoke, so unlisted reserveIds revert here at deployment
     */
    constructor(address _aaveV4Spoke, address _vault, uint256[] memory _reserveIds) {
        if (_aaveV4Spoke == address(0) || _vault == address(0)) revert AaveV4BufferHelper__ZeroAddress();
        if (_reserveIds.length == 0) revert AaveV4BufferHelper__NoReserveIds();
        aaveV4Spoke = _aaveV4Spoke;
        vault = _vault;
        for (uint256 i; i < _reserveIds.length; ++i) {
            address underlying = IAaveV4Spoke(_aaveV4Spoke).getReserve(_reserveIds[i]).underlying;
            if (reserveIdPlusOne[underlying] != 0) revert AaveV4BufferHelper__DuplicateUnderlying(underlying);
            reserveIdPlusOne[underlying] = _reserveIds[i] + 1;
        }
    }

    /**
     * @notice Returns the spoke reserveId for an asset this helper was configured with
     * @param asset The underlying asset
     * @return reserveId The reserveId on the spoke
     */
    function reserveIdFor(address asset) public view returns (uint256 reserveId) {
        uint256 idPlusOne = reserveIdPlusOne[asset];
        if (idPlusOne == 0) revert AaveV4BufferHelper__AssetNotConfigured(asset);
        reserveId = idPlusOne - 1;
    }

    /**
     * @notice Generates management calls for depositing assets into Aave V4
     * @param asset The ERC20 token address to be supplied to Aave V4
     * @param amount The amount of tokens to supply
     * @return targets Array of contract addresses to call
     * @return data Array of encoded function calls
     * @return values Array of ETH values to send with each call (all 0 for ERC20 operations)
     * @dev This function manages token approvals to cover all cases:
     *
     * - If current allowance >= amount: Only supply to Aave V4 (1 call)
     * - If current allowance == 0: Approve then supply (2 calls)
     * - If current allowance < amount: Reset approval to 0, approve new amount, then supply (3 calls)
     */
    function getDepositManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        uint256 reserveId = reserveIdFor(asset);
        uint256 currentAllowance = ERC20(asset).allowance(vault, aaveV4Spoke);
        if (currentAllowance >= amount) {
            targets = new address[](1);
            targets[0] = aaveV4Spoke;
            data = new bytes[](1);
            data[0] = abi.encodeWithSignature("supply(uint256,uint256,address)", reserveId, amount, vault);
            values = new uint256[](1);
            values[0] = 0;
        } else if (currentAllowance == 0) {
            targets = new address[](2);
            targets[0] = asset;
            targets[1] = aaveV4Spoke;
            data = new bytes[](2);
            data[0] = abi.encodeWithSignature("approve(address,uint256)", aaveV4Spoke, amount);
            data[1] = abi.encodeWithSignature("supply(uint256,uint256,address)", reserveId, amount, vault);
            values = new uint256[](2);
        } else {
            targets = new address[](3);
            targets[0] = asset;
            targets[1] = asset;
            targets[2] = aaveV4Spoke;
            data = new bytes[](3);
            data[0] = abi.encodeWithSignature("approve(address,uint256)", aaveV4Spoke, 0);
            data[1] = abi.encodeWithSignature("approve(address,uint256)", aaveV4Spoke, amount);
            data[2] = abi.encodeWithSignature("supply(uint256,uint256,address)", reserveId, amount, vault);
            values = new uint256[](3);
        }
    }

    /**
     * @notice Generates management calls for withdrawing assets from Aave V4
     * @param asset The ERC20 token address to withdraw from Aave V4
     * @param amount The amount of tokens to withdraw
     * @return targets Array of contract addresses to call
     * @return data Array of encoded function calls
     * @return values Array of ETH values to send with each call (all 0 for ERC20 operations)
     * @dev Withdraws the specified amount of the asset from Aave V4; the spoke sends the funds to the
     * caller, which is the vault since the teller executes these calls via vault.manage.
     */
    function getWithdrawManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        uint256 reserveId = reserveIdFor(asset);
        targets = new address[](1);
        targets[0] = aaveV4Spoke;
        data = new bytes[](1);
        data[0] = abi.encodeWithSignature("withdraw(uint256,uint256,address)", reserveId, amount, vault);
        values = new uint256[](1);
        return (targets, data, values);
    }
}
