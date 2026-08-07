// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract FeeRegistryTest is Test {
    FeeRegistry feeRegistry;

    // Arbitrary token placeholders — the registry only maps addresses to groups, no ERC20 calls are made.
    address constant TKN_A = address(0x1111);
    address constant TKN_B = address(0x2222);
    address constant RECIPIENT = address(0x69);
    address constant RECIPIENT_B = address(0x420);
    address constant OTHER_SWAPPER = address(0x42069);

    // events mirrored from FeeRegistry for expectEmit
    event AtomicFeeToggleUpdated(address indexed swapper, bool active);
    event LimitFeeToggleUpdated(address indexed swapper, bool active);
    event MaxFeeBpsUpdated(uint16 newMaxFeeBps);

    // address(this) is the registry owner, so it passes requiresAuth without pranking.
    function setUp() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
    }

    //==================== Constructor (L-03) ====================

    function testConstructor_RevertMaxFeeTooHigh() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        new FeeRegistry(address(this), 10_001);
    }

    function testConstructor_AllowsMaxCap() external {
        FeeRegistry registry = new FeeRegistry(address(this), 10_000);
        assertEq(registry.maxFeeBps(), 10_000);
    }

    //==================== Limit fee resolution ====================

    function testLimit_SameGroup() external {
        feeRegistry.setTokenGroup(address(this), TKN_A, 1);
        feeRegistry.setTokenGroup(address(this), TKN_B, 1);
        feeRegistry.setLimitGroupPairFee(address(this), 1, 1, 5);

        assertEq(feeRegistry.getLimitFee(address(this), TKN_A, TKN_B), 5);
    }

    function testLimit_CrossGroup() external {
        feeRegistry.setTokenGroup(address(this), TKN_B, 2);
        feeRegistry.setTokenGroup(address(this), TKN_A, 1);
        feeRegistry.setLimitGroupPairFee(address(this), 1, 2, 30);

        // symmetric: (A,B) == (B,A)
        assertEq(feeRegistry.getLimitFee(address(this), TKN_B, TKN_A), 30);
        assertEq(feeRegistry.getLimitFee(address(this), TKN_A, TKN_B), 30);
    }

    function testLimit_DefaultFallback() external {
        feeRegistry.setDefaultLimitFee(address(this), 20);
        assertEq(feeRegistry.getLimitFee(address(this), TKN_A, TKN_B), 20);
    }

    function testLimit_GroupPairOverridesDefault() external {
        feeRegistry.setDefaultLimitFee(address(this), 20);
        feeRegistry.setTokenGroup(address(this), TKN_B, 2);
        feeRegistry.setTokenGroup(address(this), TKN_A, 1);
        feeRegistry.setLimitGroupPairFee(address(this), 1, 2, 5);

        assertEq(feeRegistry.getLimitFee(address(this), TKN_B, TKN_A), 5);
    }

    function testLimit_ExplicitZeroDoesNotFallback() external {
        feeRegistry.setDefaultLimitFee(address(this), 20);
        feeRegistry.setTokenGroup(address(this), TKN_A, 1);
        feeRegistry.setTokenGroup(address(this), TKN_B, 2);
        feeRegistry.setLimitGroupPairFee(address(this), 1, 2, 0); // explicit zero, configured=true

        assertEq(feeRegistry.getLimitFee(address(this), TKN_A, TKN_B), 0);
    }

    function testLimit_IsolatedPerSwapper() external {
        feeRegistry.setDefaultLimitFee(address(this), 20);
        // a different swapper sees no fee
        assertEq(feeRegistry.getLimitFee(OTHER_SWAPPER, TKN_A, TKN_B), 0);
    }

    //==================== Atomic fee resolution (mirror of the limit path) ====================

    function testAtomic_SameGroup() external {
        feeRegistry.setTokenGroup(address(this), TKN_A, 1);
        feeRegistry.setTokenGroup(address(this), TKN_B, 1);
        feeRegistry.setAtomicGroupPairFee(address(this), 1, 1, 5);

        assertEq(feeRegistry.getAtomicFee(address(this), TKN_A, TKN_B), 5);
    }

    function testAtomic_CrossGroup() external {
        feeRegistry.setTokenGroup(address(this), TKN_B, 2);
        feeRegistry.setTokenGroup(address(this), TKN_A, 1);
        feeRegistry.setAtomicGroupPairFee(address(this), 1, 2, 30);

        assertEq(feeRegistry.getAtomicFee(address(this), TKN_B, TKN_A), 30);
        assertEq(feeRegistry.getAtomicFee(address(this), TKN_A, TKN_B), 30);
    }

    function testAtomic_DefaultFallback() external {
        feeRegistry.setDefaultAtomicFee(address(this), 20);
        assertEq(feeRegistry.getAtomicFee(address(this), TKN_A, TKN_B), 20);
    }

    function testAtomic_GroupPairOverridesDefault() external {
        feeRegistry.setDefaultAtomicFee(address(this), 20);
        feeRegistry.setTokenGroup(address(this), TKN_B, 2);
        feeRegistry.setTokenGroup(address(this), TKN_A, 1);
        feeRegistry.setAtomicGroupPairFee(address(this), 1, 2, 5);

        assertEq(feeRegistry.getAtomicFee(address(this), TKN_B, TKN_A), 5);
    }

    function testAtomic_ExplicitZeroDoesNotFallback() external {
        feeRegistry.setDefaultAtomicFee(address(this), 20);
        feeRegistry.setTokenGroup(address(this), TKN_A, 1);
        feeRegistry.setTokenGroup(address(this), TKN_B, 2);
        feeRegistry.setAtomicGroupPairFee(address(this), 1, 2, 0);

        assertEq(feeRegistry.getAtomicFee(address(this), TKN_A, TKN_B), 0);
    }

    function testAtomic_IsolatedPerSwapper() external {
        feeRegistry.setDefaultAtomicFee(address(this), 20);
        assertEq(feeRegistry.getAtomicFee(OTHER_SWAPPER, TKN_A, TKN_B), 0);
    }

    //==================== Cap enforcement ====================

    function testRevertLimitGroupPairFeeTooHigh() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        feeRegistry.setLimitGroupPairFee(address(this), 0, 1, 1001); // > maxFeeBps (1000)
    }

    function testRevertAtomicGroupPairFeeTooHigh() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        feeRegistry.setAtomicGroupPairFee(address(this), 0, 1, 1001);
    }

    function testRevertDefaultLimitFeeTooHigh() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        feeRegistry.setDefaultLimitFee(address(this), 1001);
    }

    function testRevertDefaultAtomicFeeTooHigh() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        feeRegistry.setDefaultAtomicFee(address(this), 1001);
    }

    function testSetMaxFeeBps() external {
        assertEq(feeRegistry.maxFeeBps(), 1000);

        vm.expectEmit(false, false, false, true, address(feeRegistry));
        emit MaxFeeBpsUpdated(500);
        feeRegistry.setMaxFeeBps(500);
        assertEq(feeRegistry.maxFeeBps(), 500);

        // a fee above the new cap is now rejected
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        feeRegistry.setLimitGroupPairFee(address(this), 0, 1, 501);
    }

    function testSetMaxFeeBps_RevertAboveHardCap() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        feeRegistry.setMaxFeeBps(10_001);
    }

    // A configured fee is clamped to maxFeeBps at read time when the cap is later lowered below it.
    function testGetFee_ClampsToLoweredMaxFee() external {
        feeRegistry.setDefaultLimitFee(address(this), 1000); // == current cap
        feeRegistry.setDefaultAtomicFee(address(this), 1000);
        feeRegistry.setMaxFeeBps(500); // lower the cap below the configured fees

        assertEq(feeRegistry.getLimitFee(address(this), TKN_A, TKN_B), 500);
        assertEq(feeRegistry.getAtomicFee(address(this), TKN_A, TKN_B), 500);
    }

    //==================== Recipients ====================

    function testRecipient_DefaultFallback() external {
        feeRegistry.setDefaultFeeRecipient(address(this), RECIPIENT);
        // no per-token recipient set -> both paths fall back to the default
        assertEq(feeRegistry.getFeeRecipientLimit(address(this), ERC20(TKN_A)), RECIPIENT);
        assertEq(feeRegistry.getFeeRecipientAtomic(address(this), ERC20(TKN_A)), RECIPIENT);
    }

    function testRecipient_PerTokenOverridesDefault() external {
        feeRegistry.setDefaultFeeRecipient(address(this), RECIPIENT);
        feeRegistry.setFeeTokenRecipientLimit(address(this), ERC20(TKN_A), RECIPIENT_B);
        feeRegistry.setFeeTokenRecipientAtomic(address(this), ERC20(TKN_A), RECIPIENT_B);

        // configured token uses the per-token recipient; others fall back to default
        assertEq(feeRegistry.getFeeRecipientLimit(address(this), ERC20(TKN_A)), RECIPIENT_B);
        assertEq(feeRegistry.getFeeRecipientLimit(address(this), ERC20(TKN_B)), RECIPIENT);
        assertEq(feeRegistry.getFeeRecipientAtomic(address(this), ERC20(TKN_A)), RECIPIENT_B);
        assertEq(feeRegistry.getFeeRecipientAtomic(address(this), ERC20(TKN_B)), RECIPIENT);
    }

    function testRecipient_IsolatedPerSwapper() external {
        feeRegistry.setDefaultFeeRecipient(address(this), RECIPIENT);
        assertEq(feeRegistry.getFeeRecipientLimit(OTHER_SWAPPER, ERC20(TKN_A)), address(0));
        assertEq(feeRegistry.getFeeRecipientAtomic(OTHER_SWAPPER, ERC20(TKN_A)), address(0));
    }

    function testRevertDefaultRecipientZero() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__InvalidRecipient.selector);
        feeRegistry.setDefaultFeeRecipient(address(this), address(0));
    }

    function testRevertLimitRecipientZero() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__InvalidRecipient.selector);
        feeRegistry.setFeeTokenRecipientLimit(address(this), ERC20(TKN_A), address(0));
    }

    function testRevertAtomicRecipientZero() external {
        vm.expectRevert(FeeRegistry.FeeRegistry__InvalidRecipient.selector);
        feeRegistry.setFeeTokenRecipientAtomic(address(this), ERC20(TKN_A), address(0));
    }

    //==================== Active toggles ====================

    function testToggleLimitFee() external {
        assertEq(feeRegistry.limitFeeActive(OTHER_SWAPPER), false);

        vm.expectEmit(true, false, false, true, address(feeRegistry));
        emit LimitFeeToggleUpdated(OTHER_SWAPPER, true);
        feeRegistry.toggleSwapperLimitFee(OTHER_SWAPPER, true);
        assertEq(feeRegistry.limitFeeActive(OTHER_SWAPPER), true);

        feeRegistry.toggleSwapperLimitFee(OTHER_SWAPPER, false);
        assertEq(feeRegistry.limitFeeActive(OTHER_SWAPPER), false);
    }

    function testToggleAtomicFee() external {
        assertEq(feeRegistry.atomicFeeActive(OTHER_SWAPPER), false);

        vm.expectEmit(true, false, false, true, address(feeRegistry));
        emit AtomicFeeToggleUpdated(OTHER_SWAPPER, true);
        feeRegistry.toggleSwapperAtomicFee(OTHER_SWAPPER, true);
        assertEq(feeRegistry.atomicFeeActive(OTHER_SWAPPER), true);

        feeRegistry.toggleSwapperAtomicFee(OTHER_SWAPPER, false);
        assertEq(feeRegistry.atomicFeeActive(OTHER_SWAPPER), false);
    }
}
