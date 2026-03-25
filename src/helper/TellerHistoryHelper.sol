// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport, PrincipalCheckpoint} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {IncentivePool} from "src/base/IncentivePool.sol";

/// @title TellerHistoryHelper
/// @notice Stateless view helper that aggregates principal and claim histories
///         across a Teller and multiple IncentivePools in a single call.
/// @dev Exists as a separate contract because the cross-chain Teller variants
///      (LayerZero, CCIP) are at ~97% of the Spurious Dragon bytecode limit
///      and cannot accommodate additional view functions.
contract TellerHistoryHelper {
    error ArrayLengthMismatch();

    struct PoolClaimHistory {
        address pool;
        IncentivePool.ClaimCheckpoint[] checkpoints;
        uint256 totalLength;
    }

    struct UserHistory {
        PrincipalCheckpoint[] principalCheckpoints;
        uint256 principalTotalLength;
        PoolClaimHistory[] claimHistories;
    }

    /// @notice Returns the full principal and claim histories for a user.
    /// @param teller The teller to read principal history from.
    /// @param user The user whose history to fetch.
    /// @param incentivePools The incentive pools to read claim history from.
    function getUserHistory(TellerWithMultiAssetSupport teller, address user, address[] calldata incentivePools)
        external
        view
        returns (UserHistory memory history)
    {
        (history.principalCheckpoints, history.principalTotalLength) =
            teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);

        history.claimHistories = new PoolClaimHistory[](incentivePools.length);
        for (uint256 i; i < incentivePools.length; ++i) {
            IncentivePool pool = IncentivePool(incentivePools[i]);
            history.claimHistories[i].pool = incentivePools[i];
            history.claimHistories[i].checkpoints = pool.getClaimHistory(user);
            history.claimHistories[i].totalLength = history.claimHistories[i].checkpoints.length;
        }
    }

    /// @notice Returns paginated principal and claim histories for a user.
    /// @param teller The teller to read principal history from.
    /// @param user The user whose history to fetch.
    /// @param principalStartIndex Start index (inclusive) for principal history.
    /// @param principalLength Maximum number of principal checkpoints to return.
    /// @param incentivePools The incentive pools to read claim history from.
    /// @param claimStartIndexes Per-pool start indexes (inclusive).
    /// @param claimLengths Per-pool maximum number of claim checkpoints to return.
    function getUserHistory(
        TellerWithMultiAssetSupport teller,
        address user,
        uint256 principalStartIndex,
        uint256 principalLength,
        address[] calldata incentivePools,
        uint256[] calldata claimStartIndexes,
        uint256[] calldata claimLengths
    ) external view returns (UserHistory memory history) {
        if (incentivePools.length != claimStartIndexes.length || incentivePools.length != claimLengths.length) {
            revert ArrayLengthMismatch();
        }

        (history.principalCheckpoints, history.principalTotalLength) =
            teller.getPrincipalHistoryPaginated(user, principalStartIndex, principalLength);

        history.claimHistories = new PoolClaimHistory[](incentivePools.length);
        for (uint256 i; i < incentivePools.length; ++i) {
            IncentivePool pool = IncentivePool(incentivePools[i]);
            history.claimHistories[i].pool = incentivePools[i];
            (history.claimHistories[i].checkpoints, history.claimHistories[i].totalLength) =
                pool.getClaimHistoryPaginated(user, claimStartIndexes[i], claimLengths[i]);
        }
    }
}
