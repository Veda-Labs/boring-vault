// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IPausable} from "src/interfaces/IPausable.sol";

contract MockPausable is IPausable {
    bool public isPaused;

    function pause() external {
        isPaused = true;
    }

    function unpause() external {
        isPaused = false;
    }
}
