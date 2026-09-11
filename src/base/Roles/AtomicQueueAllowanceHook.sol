// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";

interface IERC20Allowance {
    function allowance(address owner, address spender) external view returns (uint256);
}

interface ILegacyBeforeTransferHook {
    function beforeTransfer(address from) external view;
}

/**
 * @title AtomicQueueAllowanceHook
 * @notice Blocks transfers from accounts with a live approval to a blocked spender.
 * @dev This contract intentionally exposes only the legacy one-argument hook selector.
 *      The vault must call beforeTransfer(address), not the three-argument hook.
 */
contract AtomicQueueAllowanceHook is Auth {
    // ========================================= STATE =========================================

    IERC20Allowance public immutable vault;
    ILegacyBeforeTransferHook public immutable legacyHook;
    address public blockedSpender;

    // ========================================= EVENTS =========================================

    event BlockedSpenderUpdated(address indexed previousSpender, address indexed newSpender);

    // ========================================= ERRORS =========================================

    error AtomicQueueAllowanceHook__ApprovalToBlockedSpender(address from);
    error AtomicQueueAllowanceHook__InvalidAddress();

    // ========================================= CONSTRUCTOR =========================================

    constructor(
        address _owner,
        Authority _authority,
        IERC20Allowance _vault,
        ILegacyBeforeTransferHook _legacyHook,
        address _blockedSpender
    ) Auth(_owner, _authority) {
        if (address(_vault) == address(0) || address(_legacyHook) == address(0) || _blockedSpender == address(0)) {
            revert AtomicQueueAllowanceHook__InvalidAddress();
        }

        vault = _vault;
        legacyHook = _legacyHook;
        blockedSpender = _blockedSpender;

        emit BlockedSpenderUpdated(address(0), _blockedSpender);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Update the spender whose nonzero approvals block transfers.
     * @dev The authority must explicitly grant this selector to the intended role.
     */
    function setBlockedSpender(address _blockedSpender) external requiresAuth {
        if (_blockedSpender == address(0)) revert AtomicQueueAllowanceHook__InvalidAddress();

        address previousSpender = blockedSpender;
        blockedSpender = _blockedSpender;

        emit BlockedSpenderUpdated(previousSpender, _blockedSpender);
    }

    // ========================================= BEFORE TRANSFER HOOK =========================================

    /**
     * @notice Revert while `from` has a nonzero approval to `blockedSpender`.
     * @dev The allowance check executes before the vault's ERC20 allowance decrement.
     *      The legacy teller remains responsible for denyFrom and share-lock enforcement.
     */
    function beforeTransfer(address from) external view {
        if (vault.allowance(from, blockedSpender) != 0) {
            revert AtomicQueueAllowanceHook__ApprovalToBlockedSpender(from);
        }

        legacyHook.beforeTransfer(from);
    }
}
