// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";

/// @notice Veda-controlled fee registry. Assigns tokens to groups and configures per-group-pair fees.
/// @dev Vault admins have no access to this contract. Fees are tiered: like-to-like groups pay less,
///      cross-asset groups pay more. Token group 0 = unassigned/exotic.
contract FeeRegistry is Auth, IFeeRegistry {

    // ========================================= STRUCTS =========================================

    struct FeeConfig {
        uint16 feeBps;
        address feeRecipient;
    }

    // ========================================= CONSTANTS =========================================

    /// @notice Hard cap on any single fee tier — 10%.
    uint16 public constant MAX_FEE_BPS = 1000;

    // ========================================= ERRORS =========================================

    error FeeRegistry__FeeTooHigh();
    error FeeRegistry__InvalidRecipient();

    // ========================================= EVENTS =========================================

    event TokenGroupSet(address indexed token, uint8 groupId);
    event GroupPairFeeSet(uint8 groupA, uint8 groupB, uint16 feeBps, address feeRecipient);
    event DefaultFeeSet(uint16 feeBps, address feeRecipient);

    // ========================================= STATE =========================================

    /// @notice Token → group ID. Group 0 = unassigned/exotic.
    mapping(address token => uint8 groupId) public tokenGroup;

    /// @notice Normalized group pair → fee config. Pair key is order-independent: min(gA,gB) || max(gA,gB).
    mapping(bytes32 groupPairId => FeeConfig) public groupFees;

    /// @notice Fallback fee used when no explicit group pair fee is configured.
    FeeConfig public defaultFee;

    // ========================================= CONSTRUCTOR =========================================

    constructor(address _owner) Auth(_owner, Authority(address(0))) {}

    // ========================================= ADMIN FUNCTIONS =========================================

    /// @notice Assigns a token to a fee group.
    function setTokenGroup(address token, uint8 groupId) external requiresAuth {
        tokenGroup[token] = groupId;
        emit TokenGroupSet(token, groupId);
    }

    /// @notice Sets the fee for a group pair. Order of groupA/groupB does not matter.
    function setGroupPairFee(uint8 groupA, uint8 groupB, uint16 feeBps, address feeRecipient) external requiresAuth {
        if (feeBps > MAX_FEE_BPS) revert FeeRegistry__FeeTooHigh();
        if (feeBps > 0 && feeRecipient == address(0)) revert FeeRegistry__InvalidRecipient();
        groupFees[_pairId(groupA, groupB)] = FeeConfig({feeBps: feeBps, feeRecipient: feeRecipient});
        emit GroupPairFeeSet(groupA, groupB, feeBps, feeRecipient);
    }

    /// @notice Sets the default fee used when no group pair config exists.
    function setDefaultFee(uint16 feeBps, address feeRecipient) external requiresAuth {
        if (feeBps > MAX_FEE_BPS) revert FeeRegistry__FeeTooHigh();
        if (feeBps > 0 && feeRecipient == address(0)) revert FeeRegistry__InvalidRecipient();
        defaultFee = FeeConfig({feeBps: feeBps, feeRecipient: feeRecipient});
        emit DefaultFeeSet(feeBps, feeRecipient);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /// @notice Returns the applicable fee for a swap pair.
    /// @dev Looks up the group pair fee first; falls back to defaultFee if not configured.
    ///      A configured fee is detected by a non-zero feeRecipient — a zero feeRecipient means unconfigured.
    function getFee(address tokenIn, address tokenOut) external view returns (uint16 feeBps, address feeRecipient) {
        uint8 gIn = tokenGroup[tokenIn];
        uint8 gOut = tokenGroup[tokenOut];
        FeeConfig memory cfg = groupFees[_pairId(gIn, gOut)];
        if (cfg.feeRecipient != address(0)) return (cfg.feeBps, cfg.feeRecipient);
        return (defaultFee.feeBps, defaultFee.feeRecipient);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /// @notice Produces an order-normalized pair key so (A,B) == (B,A).
    function _pairId(uint8 a, uint8 b) internal pure returns (bytes32) {
        return a <= b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }
}
