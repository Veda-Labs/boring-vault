// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @notice Veda-controlled fee registry. Fees are configured per swapper instance, tiered by token group pair.
/// @dev Vault admins have no access to this contract. Token group 0 = unassigned/exotic.
///      getFee() uses msg.sender as the swapper key — callers must be registered BoringSwapper instances.
contract FeeRegistry is Auth, IFeeRegistry {

    // ========================================= ERRORS =========================================

    error FeeRegistry__FeeTooHigh();
    error FeeRegistry__InvalidRecipient();

    // ========================================= EVENTS =========================================

    event MaxFeeBpsUpdated(uint16 newMaxFeeBps);
    event SwapperActiveUpdated(address indexed swapper, bool active);
    event TokenGroupSet(address indexed swapper, address indexed token, uint8 groupId);
    event GroupPairFeeSet(address indexed swapper, uint8 groupA, uint8 groupB, uint16 feeBps);
    event FeeTokenRecipientSet(address indexed swapper, ERC20 token, address feeRecipient);
    event DefaultFeeSet(address indexed swapper, uint16 feeBps);
    event DefaultFeeRecipientSet(address indexed swapper, address feeRecipient);

    // ========================================= STATE =========================================

    /// @notice Global cap on any fee tier. Settable by registry admin.
    uint16 public maxFeeBps;

    /// @notice Whether fee collection is active for a given swapper.
    mapping(address swapper => bool active) public swapperActive;

    /// @notice swapper -> token -> group ID. Group 0 = unassigned/exotic.
    mapping(address swapper => mapping(address token => uint8 groupId)) public tokenGroup;

    /// @notice swapper -> normalized group pair -> fee amount. Allows configuration of fees per token pair. 
    mapping(address swapper => mapping(bytes32 groupPairId => uint16 feeBps)) public groupFees;

    /// @notice swapper -> fallback fee used when no explicit group pair fee is configured.
    mapping(address swapper => uint16 feeBps) public defaultFee;
    
    /// @notice swapper -> default feeRecipient
    mapping(address swapper => address feeRecipient) public defaultRecipient; 

    /// @notice swapper -> feeToken -> fee recipient. Allows configuration of fee recipient per feeToken. 
    mapping(address swapper => mapping(ERC20 feeToken => address feeRecipient)) public feeTokenRecipient;

    // ========================================= CONSTRUCTOR =========================================

    constructor(address _owner, uint16 _maxFeeBps) Auth(_owner, Authority(address(0))) {
        maxFeeBps = _maxFeeBps;
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /// @notice Enables or disables fee collection for a specific swapper.
    function setSwapperActive(address swapper, bool active) external requiresAuth {
        swapperActive[swapper] = active;
        emit SwapperActiveUpdated(swapper, active);
    }

    /// @notice Updates the global cap on fee tiers.
    function setMaxFeeBps(uint16 newMaxFeeBps) external requiresAuth {
        maxFeeBps = newMaxFeeBps;
        emit MaxFeeBpsUpdated(newMaxFeeBps);
    }

    /// @notice Assigns a token to a fee group for a specific swapper.
    function setTokenGroup(address swapper, address token, uint8 groupId) external requiresAuth {
        tokenGroup[swapper][token] = groupId;
        emit TokenGroupSet(swapper, token, groupId);
    }

    /// @notice Sets the fee for a group pair on a specific swapper. Order of groupA/groupB does not matter.
    function setGroupPairFee(address swapper, uint8 groupA, uint8 groupB, uint16 feeBps) external requiresAuth {
        if (feeBps > maxFeeBps) revert FeeRegistry__FeeTooHigh();
        groupFees[swapper][_pairId(groupA, groupB)] = feeBps;
        emit GroupPairFeeSet(swapper, groupA, groupB, feeBps);
    }

    /// @notice Sets the fee for a group pair on a specific swapper. Order of groupA/groupB does not matter.
    function setFeeTokenRecipient(address swapper, ERC20 feeToken, address feeRecipient) external requiresAuth {
        if (feeRecipient == address(0)) revert FeeRegistry__InvalidRecipient();
        feeTokenRecipient[swapper][feeToken] = feeRecipient;
        emit FeeTokenRecipientSet(swapper, feeToken, feeRecipient);
    }

    /// @notice Sets the default fee for a specific swapper, used when no group pair config exists.
    function setDefaultFee(address swapper, uint16 feeBps) external requiresAuth {
        if (feeBps > maxFeeBps) revert FeeRegistry__FeeTooHigh();
        defaultFee[swapper] =  feeBps;
        emit DefaultFeeSet(swapper, feeBps);
    }

    /// @notice Sets the default fee for a specific swapper, used when no group pair config exists.
    function setDefaultFeeRecipient(address swapper, address feeRecipient) external requiresAuth {
        if (feeRecipient == address(0)) revert FeeRegistry__InvalidRecipient();
        defaultRecipient[swapper] = feeRecipient;
        emit DefaultFeeRecipientSet(swapper, feeRecipient);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /// @notice Returns the applicable fee for a swap pair
    /// @dev Looks up group pair fee first; falls back to defaultFee if not configured.
    function getFee(address swapper, address tokenIn, address tokenOut) external view returns (uint16) {
        uint8 groupIdIn = tokenGroup[swapper][tokenIn];
        uint8 groupIdOut = tokenGroup[swapper][tokenOut];
        uint16 feeBps = groupFees[swapper][_pairId(groupIdIn, groupIdOut)];
        
        //return fee for pair 
        if (feeBps > 0) return feeBps;
        
        //if nothing set, return the default (which can be 0)
        feeBps = defaultFee[swapper];
        return feeBps;
    }

    /// @notice Returns the applicable fee for a swap pair
    /// @dev Looks up group pair fee first; falls back to defaultRecipient[swapper] if not configured.
    function getFeeRecipient(address swapper, ERC20 feeToken) external view returns (address) {
        address feeRecipient = feeTokenRecipient[swapper][feeToken];
        if (feeRecipient != address(0)) return feeRecipient;

        feeRecipient = defaultRecipient[swapper];
        return feeRecipient;        
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /// @notice Produces an order-normalized pair key so (A,B) == (B,A).
    function _pairId(uint8 groupA, uint8 groupB) internal pure returns (bytes32) {
        return groupA <= groupB ? keccak256(abi.encode(groupA, groupB)) : keccak256(abi.encode(groupB, groupA));
    }
}
