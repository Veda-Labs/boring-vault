// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";


interface IAdapter {

    struct OrderInfo {
        address approvalTarget;
        address cancelTarget;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        bytes32 protocolHash;
    }

    function version() external view returns (uint256);
    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address swapper) external view returns (OrderInfo memory);

    /// @notice Returns the protocol-side cancel target and calldata for an order.
    /// @dev Contract:
    ///      - When the protocol-side state needs no action (order was never registered, already filled,
    ///        already invalidated), return `data.length == 0`. The swapper will skip the external call
    ///        and rely on its local invalidation (`approvedHashes = false` + allowance reduction) alone.
    ///      - When `data.length > 0`, the returned calldata MUST execute successfully against `target`
    ///        for any state the protocol is in. The swapper reverts the entire `cancelOrder` tx on
    ///        external-call failure — adapters must therefore inspect protocol state (e.g. fill/invalidator
    ///        getters) and return empty calldata for states where the cancel call would revert.
    ///      - For protocols whose cancel is idempotent (e.g. CoW `invalidateOrder`, 1inch v4 `cancelOrder`),
    ///        always returning non-empty calldata is acceptable.
    ///      - For "validate-once" protocols where local-only invalidation does NOT prevent fills (the
    ///        protocol caches the signature check at registration time), the adapter is the only line
    ///        of defense: the cancel MUST succeed externally. Implement existence checks accordingly.
    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address swapper) external view returns (address target, bytes memory data);

    /// @notice Returns true iff the protocol considers the order filled.
    /// @dev Read-only inspection of protocol state (e.g. CoW `filledAmount`, 1inch `bitInvalidatorForOrder`,
    ///      OpenOcean `remainingRaw`). The swapper calls this inside `_cancelOrder` BEFORE invoking
    ///      `cancelLimitOrder`, so any "set" reading at the call site must be a genuine fill — the swapper
    ///      has not yet invalidated the order itself. Adapters that do not support limit orders MUST
    ///      revert (matching their `verifyLimitOrder` / `cancelLimitOrder` behavior).
    function isFilled(ISwapperTypes.SwapConfig calldata swapConfig, address swapper) external view returns (bool);
}
