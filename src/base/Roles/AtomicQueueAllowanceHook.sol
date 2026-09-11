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
    function beforeTransfer(address from, address to, address operator) external view;
}

/**
 * @title AtomicQueueAllowanceHook
 * @notice Blocks transfers from accounts with a live approval to a blocked spender.
 * @dev Supports both BoringVault beforeTransfer hook selectors. The one-argument
 *      overload is required by legacy vault deployments.
 */
contract AtomicQueueAllowanceHook is Auth {
    IERC20Allowance public immutable vault;
    ILegacyBeforeTransferHook public immutable legacyHook;
    address[] public blockedSpenders;
    mapping(address => bool) public isBlockedSpender;

    uint256 public constant MAX_BLOCKED_SPENDERS = 128;

    // ========================================= EVENTS =========================================

    event BlockedSpenderAdded(address indexed spender);
    event BlockedSpenderRemoved(address indexed spender);

    // ========================================= ERRORS =========================================

    error AtomicQueueAllowanceHook__ApprovalToBlockedSpender(address from, address spender);
    error AtomicQueueAllowanceHook__InvalidAddress();
    error AtomicQueueAllowanceHook__SpenderAlreadyBlocked(address spender);
    error AtomicQueueAllowanceHook__SpenderNotBlocked(address spender);
    error AtomicQueueAllowanceHook__TooManyBlockedSpenders();

    // ========================================= CONSTRUCTOR =========================================

    constructor(
        address _owner,
        Authority _authority,
        IERC20Allowance _vault,
        ILegacyBeforeTransferHook _legacyHook,
        address _blockedSpender
    ) Auth(_owner, _authority) {
        if (address(_vault) == address(0) || address(_legacyHook) == address(0)) {
            revert AtomicQueueAllowanceHook__InvalidAddress();
        }

        vault = _vault;
        legacyHook = _legacyHook;
        _addBlockedSpender(_blockedSpender);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Add a spender whose nonzero approvals block transfers.
     * @dev The authority must explicitly grant this selector to the intended role.
     */
    function addBlockedSpender(address _blockedSpender) external requiresAuth {
        _addBlockedSpender(_blockedSpender);
    }

    /**
     * @notice Remove a spender from the transfer-blocking set.
     * @dev The authority must explicitly grant this selector to the intended role.
     */
    function removeBlockedSpender(address _blockedSpender) external requiresAuth {
        uint256 spendersLength = blockedSpenders.length;
        for (uint256 i; i < spendersLength; ++i) {
            if (blockedSpenders[i] != _blockedSpender) continue;

            uint256 lastIndex = spendersLength - 1;
            if (i != lastIndex) blockedSpenders[i] = blockedSpenders[lastIndex];
            blockedSpenders.pop();
            isBlockedSpender[_blockedSpender] = false;
            emit BlockedSpenderRemoved(_blockedSpender);
            return;
        }

        revert AtomicQueueAllowanceHook__SpenderNotBlocked(_blockedSpender);
    }

    function getBlockedSpenders() external view returns (address[] memory) {
        return blockedSpenders;
    }

    // ========================================= BEFORE TRANSFER HOOK =========================================

    /**
     * @notice Revert while `from` has a nonzero approval to a blocked spender.
     * @dev The allowance check executes before the vault's ERC20 allowance decrement.
     *      The legacy teller remains responsible for denyFrom and share-lock enforcement.
     */
    function beforeTransfer(address from) external view {
        _checkAllowance(from);
        legacyHook.beforeTransfer(from);
    }

    /**
     * @notice Revert while `from` has a nonzero approval to a blocked spender.
     * @dev This overload supports BoringVault deployments that pass the recipient and operator.
     */
    function beforeTransfer(address from, address to, address operator) external view {
        _checkAllowance(from);
        legacyHook.beforeTransfer(from, to, operator);
    }

    function _addBlockedSpender(address _blockedSpender) internal {
        if (_blockedSpender == address(0)) revert AtomicQueueAllowanceHook__InvalidAddress();
        if (isBlockedSpender[_blockedSpender]) {
            revert AtomicQueueAllowanceHook__SpenderAlreadyBlocked(_blockedSpender);
        }
        if (blockedSpenders.length >= MAX_BLOCKED_SPENDERS) {
            revert AtomicQueueAllowanceHook__TooManyBlockedSpenders();
        }

        isBlockedSpender[_blockedSpender] = true;
        blockedSpenders.push(_blockedSpender);
        emit BlockedSpenderAdded(_blockedSpender);
    }

    function _checkAllowance(address from) internal view {
        uint256 spendersLength = blockedSpenders.length;
        for (uint256 i; i < spendersLength; ++i) {
            address spender = blockedSpenders[i];
            if (vault.allowance(from, spender) != 0) {
                revert AtomicQueueAllowanceHook__ApprovalToBlockedSpender(from, spender);
            }
        }
    }
}
