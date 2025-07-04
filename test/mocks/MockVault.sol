// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockVault
 * @notice Minimal mock implementation of the IVault interface required by ShareMover tests.
 *         It tracks balances internally and allows unrestricted transfers / permits for simplicity.
 */
contract MockVault {
    // ------------------------------------------------------------------------------------------
    // Storage
    // ------------------------------------------------------------------------------------------

    mapping(address => uint256) internal _balances;
    uint8 internal immutable _decimals;

    bool public shouldRevertPermit;
    bool public permitCalled;

    // ------------------------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------------------------

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    // ------------------------------------------------------------------------------------------
    // IVault-compatible interface
    // ------------------------------------------------------------------------------------------

    function enter(
        address /*from*/, 
        ERC20 /*asset*/, 
        uint256 /*assetAmount*/, 
        address to, 
        uint256 shareAmount
    ) external {
        _balances[to] += shareAmount;
    }

    function exit(
        address /*to*/, 
        ERC20 /*asset*/, 
        uint256 /*assetAmount*/, 
        address from, 
        uint256 shareAmount
    ) external {
        require(_balances[from] >= shareAmount, "MockVault: burn exceeds balance");
        _balances[from] -= shareAmount;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(_balances[from] >= amount, "MockVault: insufficient balance");
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function setPermitBehavior(bool _revert) external {
        shouldRevertPermit = _revert;
    }

    function permit(
        address, /*owner*/
        address, /*spender*/
        uint256, /*value*/
        uint256, /*deadline*/
        uint8, /*v*/
        bytes32, /*r*/
        bytes32 /*s*/
    ) external {
        if (shouldRevertPermit) revert("permit revert");
        permitCalled = true;
    }

    // ------------------------------------------------------------------------------------------
    // Test utilities
    // ------------------------------------------------------------------------------------------

    /// @notice Mint shares to an address (test helper)
    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
    }
} 