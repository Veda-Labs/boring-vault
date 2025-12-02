// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs // Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "@forge-std/Test.sol";

/**
 * Helper contract to create test actors and their private keys
 * @dev Never use any of these secret keys anywhere else, they are only for testing purposes
 */
contract TestActors is Test {
    address public alice;
    uint256 public aliceSk;

    address public bill;
    uint256 public billSk;

    address public charlie;
    uint256 public charlieSk;

    address public david;
    uint256 public davidSk;

    address public eve;
    uint256 public eveSk;

    address public frank;
    uint256 public frankSk;
    
    address public payoutAddress;
    uint256 public payoutAddressSk;

    address public referrer;
    uint256 public referrerSk;
    constructor() {
        (alice, aliceSk) = makeAddrAndKey("alice");
        (bill, billSk) = makeAddrAndKey("bill");
        (charlie, charlieSk) = makeAddrAndKey("charlie");
        (david, davidSk) = makeAddrAndKey("david");
        (eve, eveSk) = makeAddrAndKey("eve");
        (frank, frankSk) = makeAddrAndKey("frank");
        (payoutAddress, payoutAddressSk) = makeAddrAndKey("payoutAddress");
        (referrer, referrerSk) = makeAddrAndKey("referrer");
    }
}