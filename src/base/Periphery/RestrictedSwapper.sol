// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringSwapper, SwapParams, QuoteAsset} from "src/base/Periphery/BoringSwapper.sol";
import {Authority} from "@solmate/auth/Auth.sol";

contract RestrictedSwapper is BoringSwapper {

    //============================== ERRORS ===============================

    error RestrictedSwapper__MaxSlippageCeilingNotSet();
    error RestrictedSwapper__MaxSwapAmountNotSet();

    constructor(
        address _NATIVE,
        address _owner,
        Authority _auth
    ) BoringSwapper(_NATIVE, _owner, _auth) {}

    // ========================================= OVERRIDES =========================================

    function _validateSwap(SwapParams calldata params) internal view override {
        if (maxSlippageCeilingBps == 0) revert RestrictedSwapper__MaxSlippageCeilingNotSet();
        if (maxSwapAmountNormalized == 0) revert RestrictedSwapper__MaxSwapAmountNotSet();
        super._validateSwap(params);
    }

    function _resolveMinOut(SwapParams calldata params) internal view override returns (uint256) {
        return _calculateMinOut(params);
    }
}
