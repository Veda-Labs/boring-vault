// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs // Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "@forge-std/Test.sol";

/**
 * Helper contract to define the roles constants
 */
contract RolesConstants is Test {
    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant BORING_VAULT_ROLE = 4;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 3;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;
}