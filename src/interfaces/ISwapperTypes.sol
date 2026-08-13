// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BoringVault} from "src/base/BoringVault.sol";

/// @notice V1 type vocabulary for the swapper ecosystem. Adapters and the V1 swapper
///         reference these structs through this namespace. A future SwapperV2 with a
///         different SwapConfig shape ships its own ISwapperTypesV2 — top-level
///         contracts (FeeRegistry, AdapterRegistry, PriceValidator) bind to the
///         stable ISwapper view surface instead and never see these types.
interface ISwapperTypes {
    struct TokenRoute {
        ERC20 tokenIn;
        ERC20 tokenOut;
    }

    struct SwapConfig {
        TokenRoute tokenRoute;
        address adapter;
        address quoteAsset;
        bytes swapData;
        uint256 slippageBps;
        BoringVault receiver;
    }
}
