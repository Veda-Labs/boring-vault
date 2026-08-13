// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {OneInchAdapterTest} from "./OneInchAdapter.t.sol";
import {OneInchAdapterNoExecutor} from "src/base/Periphery/adapters/OneInchAdapterNoExecutor.sol";

/// @notice Runs the ENTIRE OneInchAdapter test suite against OneInchAdapterNoExecutor via inheritance, so the two
///         can never drift. OneInchAdapterNoExecutor shares byte-identical limit-order, unoswap, pool-validation,
///         `_verifyPostInteractionData`, and `filledAmount` logic with OneInchAdapter — including the raw-nonce
///         bit-invalidator read, the per-slot 4/5/6 offset checks, the feeLen<=7 tail bound, and the
///         tokenIn-in-pool checks. It ONLY relaxes `swap()` by dropping the trusted-executor
///         whitelist and the `srcReceiver == executor` check.
///
///         Inheritance is safe because no inherited test depends on those two dropped checks: none asserts
///         `ExecutorMismatch`/`SrcReceiverMismatch`, and the atomic-swap tests use a real whitelisted executor
///         that the relaxed variant also accepts. Only `setUp` differs — it re-points `oneInchAdapter` at the
///         NoExecutor variant; routes, oracles, and rate limits are token-keyed and carry over unchanged.
contract OneInchAdapterNoExecutorTest is OneInchAdapterTest {
    function setUp() public override {
        // Full parent wiring for the standard adapter (routes, oracles, registry, decoder, fork).
        super.setUp();

        // Swap in the NoExecutor variant (same constructor minus the executors whitelist) and re-point every
        // adapter-specific hook at it. From here every inherited test exercises OneInchAdapterNoExecutor through
        // the `oneInchAdapter` state variable.
        oneInchAdapter = address(
            new OneInchAdapterNoExecutor(
                ONEINCH_ROUTER,
                ONEINCH_FEE_TAKER,
                0x90CbE4BDd538D6e9b379bFF5fE72c3d67A521De5, // 1inch protocol fee receiver
                getAddress(sourceChain, "uniV2Factory"),
                getAddress(sourceChain, "uniV3Factory"),
                getAddress(sourceChain, "curveMetaRegistry")
            )
        );
        swapper.setApprovedAdapter(oneInchAdapter, true);
        registry.put(oneInchAdapter, "ONEINCH_NOEXEC");
    }
}
