// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MPortalWormholeIntegrationBase} from "test/integrations/MPortalWormholeIntegration.t.sol";

// Monad -> mainnet over the Wormhole bridge adapter. Shares its tests with MPortalWormholeIntegrationTest (mainnet).
// forge test --match-path "test/integrations/MPortalWormholeMonadIntegration.t.sol" -vvv
contract MPortalWormholeMonadIntegrationTest is MPortalWormholeIntegrationBase {
    function _chainName() internal pure override returns (string memory) {
        return "monad";
    }

    function _rpcKey() internal pure override returns (string memory) {
        return "MONAD_RPC_URL";
    }

    function _blockNumber() internal pure override returns (uint256) {
        return 109_147_997;
    }

    function _destinationChainId() internal pure override returns (uint32) {
        return 1;
    }

    function _srcWormholeChain() internal pure override returns (uint16) {
        return 48;
    }

    function _dstWormholeChain() internal pure override returns (uint16) {
        return 2;
    }

    // Recent Monad->mainnet Executor fee (tx 0xbf4b40e0d7c8d3030773d3aba7fa7cd42710e6bfb6bbdde3d58bf48a160c00df).
    // The fee is set by the offchain quote and varies; use the quote's estimatedCost in production.
    function _executorFee() internal pure override returns (uint256) {
        return 84_741_414_216_522_864_498;
    }

    // Monad->mainnet mUSD tx 0x15b76782e85be6661a7e82787a60b9f45634c24e6fa638f9a87dd831f6e5e854.
    function _realQuote() internal pure override returns (bytes memory) {
        return hex"45513031a54008017941ece968623a0dd8ee907e2b1335960000000000000000000000006a8bfc410a3cc7306d52872f116afb12f1cec6c6003000020000000069e1486500000043371b6cd0000000000dd5f3a10000000014a5936c00001550273ee40058db8fd5bb85de2e787cb29e2644e47e935e0dcd150f84a8b15b3bd0599281903f42f435c712366f7eb35c6e91277d3fdf29d7479e35bebb24715b9cfc7362ee1b";
    }
}
