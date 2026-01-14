// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/**
 * @title ICoreWriter
 * @notice Interface for Hyperliquid CoreWriter contract on HyperEVM.
 * @dev Deployed at 0x3333333333333333333333333333333333333333 on HyperEVM.
 *      Enables smart contracts to send transactions to HyperCore.
 */
interface ICoreWriter {
    /**
     * @notice Send a raw encoded action to HyperCore.
     * @dev Action data format: [version(1)][actionId(3)][params(variable)]
     *      - version: Currently 0x01
     *      - actionId: Big-endian uint24 identifying the action type
     *      - params: ABI-encoded action parameters
     *
     *      Known action IDs:
     *      - 1: Limit order (asset, isBuy, limitPx, sz, reduceOnly, encodedTif, cloid)
     *      - 2: Vault transfer (vault, isDeposit, usd)
     *      - 3: Token delegate (validator, wei, isUndelegate)
     *      - 4: Spot send (to, coreIndex, coreAmount)
     *      - 7: USD class transfer (ntl, toPerp)
     *
     * @param data The raw encoded action data
     */
    function sendRawAction(bytes calldata data) external;
}
