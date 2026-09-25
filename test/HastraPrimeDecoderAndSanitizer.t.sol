// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {HastraPrimeFullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HastraPrimeFullDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {Test} from "@forge-std/Test.sol";

/// @dev State-changing ABI of Hastra wYLDS, taken from the verified YieldVaultV2 implementation
///      0x06e0b9155a3cf07f41ac826ccfee7ef8413a9723 behind proxy 0x6aD038cA6C04e885630851278ca0a856Ad9a66Cc.
interface IWyldsVault {
    function addToWhitelist(address account) external;
    function approve(address spender, uint256 value) external returns (bool);
    function cancelRedeem() external;
    function claimRewards(uint256 epochIndex, uint256 amount, bytes32[] memory proof) external;
    function completeRedeem(address user) external;
    function createRewardsEpoch(uint256 epochIndex, bytes32 merkleRoot, uint256 totalRewards) external;
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function depositWithPermit(uint256 assets, address receiver, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (uint256 shares);
    function freezeAccount(address account) external;
    function grantRole(bytes32 role, address account) external;
    function initialize(address asset_, string memory name_, string memory symbol_, address admin_, address redeemVault_, address initialWhitelist_) external;
    function initializeV2(uint64 version, address epochAdmin, address redeemOperator, uint256 globalCap) external;
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function mintRewards(address to, uint256 amount) external;
    function pause() external;
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function removeFromWhitelist(address account) external;
    function renounceRole(bytes32 role, address callerConfirmation) external;
    function requestRedeem(uint256 shares) external;
    function revokeRole(bytes32 role, address account) external;
    function setMaxEpochCap(uint256 newCap) external;
    function setRedeemVault(address newRedeemVault) external;
    function thawAccount(address account) external;
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function unpause() external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function withdrawUSDC(address to, uint256 amount) external;
}

/// @dev State-changing ABI of Hastra PRIME, taken from the verified StakingVault implementation
///      0x881fe0e5e91c54fabbf0198a1bb2fc6e5747d4c5 behind proxy 0x19ebb35279A16207Ec4ba82799CC64715065F7F6.
///      Functions shared with wYLDS (approve, deposit, mint, redeem, withdraw, permit, roles, pause,
///      freeze, transfer, upgrade) have identical signatures and are only listed on IWyldsVault.
interface IPrimeStakingVault {
    function distributeRewards(uint256 amount) external;
    function initialize(address asset_, string memory name_, string memory symbol_, address admin_, address yieldVault_) external;
    function setMaxPeriodRewards(uint256 newCap) external;
    function setMaxRewardPercent(uint256 newPercent) external;
    function setMaxTotalRewards(uint256 newMax) external;
    function setNavOracle(address oracle, bytes32 feedId) external;
    function setRewardPeriodSeconds(uint256 newSeconds) external;
    function setYieldVault(address newVault) external;
}

contract HastraPrimeDecoderAndSanitizerTest is Test {
    HastraPrimeFullDecoderAndSanitizer internal decoder;

    function setUp() external {
        decoder = new HastraPrimeFullDecoderAndSanitizer();
    }

    // ========================================= SELECTORS =========================================

    /// @notice The decoder's selectors are the ones Hastra's contracts dispatch on. The hex values were
    ///         also read from the live implementations' dispatch tables.
    function testSelectorsMatchHastraAbi() external view {
        assertEq(decoder.deposit.selector, IWyldsVault.deposit.selector);
        assertEq(decoder.mint.selector, IWyldsVault.mint.selector);
        assertEq(decoder.withdraw.selector, IWyldsVault.withdraw.selector);
        assertEq(decoder.redeem.selector, IWyldsVault.redeem.selector);
        assertEq(decoder.requestRedeem.selector, IWyldsVault.requestRedeem.selector);
        assertEq(decoder.cancelRedeem.selector, IWyldsVault.cancelRedeem.selector);
        assertEq(decoder.approve.selector, IWyldsVault.approve.selector);

        assertEq(decoder.deposit.selector, bytes4(0x6e553f65));
        assertEq(decoder.mint.selector, bytes4(0x94bf804d));
        assertEq(decoder.withdraw.selector, bytes4(0xb460af94));
        assertEq(decoder.redeem.selector, bytes4(0xba087652));
        assertEq(decoder.requestRedeem.selector, bytes4(0xaa2f892d));
        assertEq(decoder.cancelRedeem.selector, bytes4(0xe6a29666));
    }

    // ========================================= SANITIZATION =========================================

    function testFuzz_DepositPacksReceiver(uint256 assets, address receiver) external view {
        assertEq(decoder.deposit(assets, receiver), abi.encodePacked(receiver));
        _assertRawDecode(abi.encodeCall(IWyldsVault.deposit, (assets, receiver)), abi.encodePacked(receiver));
    }

    function testFuzz_MintPacksReceiver(uint256 shares, address receiver) external view {
        assertEq(decoder.mint(shares, receiver), abi.encodePacked(receiver));
        _assertRawDecode(abi.encodeCall(IWyldsVault.mint, (shares, receiver)), abi.encodePacked(receiver));
    }

    function testFuzz_WithdrawPacksReceiverThenOwner(uint256 assets, address receiver, address owner) external view {
        assertEq(decoder.withdraw(assets, receiver, owner), abi.encodePacked(receiver, owner));
        _assertRawDecode(abi.encodeCall(IWyldsVault.withdraw, (assets, receiver, owner)), abi.encodePacked(receiver, owner));
    }

    function testFuzz_RedeemPacksReceiverThenOwner(uint256 shares, address receiver, address owner) external view {
        assertEq(decoder.redeem(shares, receiver, owner), abi.encodePacked(receiver, owner));
        _assertRawDecode(abi.encodeCall(IWyldsVault.redeem, (shares, receiver, owner)), abi.encodePacked(receiver, owner));
    }

    function testFuzz_RequestRedeemHasNothingToSanitize(uint256 shares) external view {
        assertEq(decoder.requestRedeem(shares).length, 0);
        _assertRawDecode(abi.encodeCall(IWyldsVault.requestRedeem, (shares)), "");
    }

    function testCancelRedeemHasNothingToSanitize() external view {
        assertEq(decoder.cancelRedeem().length, 0);
        _assertRawDecode(abi.encodeCall(IWyldsVault.cancelRedeem, ()), "");
    }

    function testFuzz_ApprovePacksSpender(address spender, uint256 amount) external view {
        _assertRawDecode(abi.encodeCall(IWyldsVault.approve, (spender, amount)), abi.encodePacked(spender));
    }

    /// @notice transfer comes from BaseDecoderAndSanitizer; the recipient is surfaced for the leaf to pin.
    function testFuzz_TransferPacksRecipient(address to, uint256 amount) external view {
        _assertRawDecode(abi.encodeCall(IWyldsVault.transfer, (to, amount)), abi.encodePacked(to));
    }

    // ========================================= SURFACE =========================================

    /// @notice Every state-changing wYLDS/PRIME function outside the mint/redeem path is rejected by the
    ///         decoder, so no leaf can ever be built for it. The only exceptions are the ERC20 approve and
    ///         transfer inherited from BaseDecoderAndSanitizer, which surface the spender/recipient.
    function testEveryOtherHastraFunctionIsUnsupported() external view {
        bytes4[29] memory unsupported = [
            // Operator and admin functions
            IWyldsVault.completeRedeem.selector,
            IWyldsVault.addToWhitelist.selector,
            IWyldsVault.createRewardsEpoch.selector,
            IWyldsVault.freezeAccount.selector,
            IWyldsVault.grantRole.selector,
            IWyldsVault.initialize.selector,
            IWyldsVault.initializeV2.selector,
            IWyldsVault.mintRewards.selector,
            IWyldsVault.pause.selector,
            IWyldsVault.removeFromWhitelist.selector,
            IWyldsVault.renounceRole.selector,
            IWyldsVault.revokeRole.selector,
            IWyldsVault.setMaxEpochCap.selector,
            IWyldsVault.setRedeemVault.selector,
            IWyldsVault.thawAccount.selector,
            IWyldsVault.unpause.selector,
            IWyldsVault.upgradeToAndCall.selector,
            IWyldsVault.withdrawUSDC.selector,
            IPrimeStakingVault.distributeRewards.selector,
            IPrimeStakingVault.initialize.selector,
            IPrimeStakingVault.setMaxPeriodRewards.selector,
            IPrimeStakingVault.setMaxRewardPercent.selector,
            IPrimeStakingVault.setMaxTotalRewards.selector,
            IPrimeStakingVault.setNavOracle.selector,
            IPrimeStakingVault.setRewardPeriodSeconds.selector,
            IPrimeStakingVault.setYieldVault.selector,
            // User functions intentionally left out
            IWyldsVault.depositWithPermit.selector,
            IWyldsVault.claimRewards.selector,
            IWyldsVault.permit.selector
        ];

        for (uint256 i; i < unsupported.length; ++i) {
            _assertUnsupported(abi.encodePacked(unsupported[i], new bytes(256)));
        }
        // transferFrom is not in BaseDecoderAndSanitizer either.
        _assertUnsupported(abi.encodePacked(IWyldsVault.transferFrom.selector, new bytes(96)));
    }

    // ========================================= HELPERS =========================================

    /// @dev Mirrors ManagerWithMerkleVerification: static call the decoder with the target calldata and
    ///      abi-decode the returned bytes.
    function _assertRawDecode(bytes memory callData, bytes memory expected) internal view {
        (bool success, bytes memory result) = address(decoder).staticcall(callData);
        assertTrue(success, "decoder call failed");
        assertEq(abi.decode(result, (bytes)), expected);
    }

    function _assertUnsupported(bytes memory callData) internal view {
        (bool success, bytes memory result) = address(decoder).staticcall(callData);
        assertFalse(success, "selector should be unsupported");
        assertEq(result, abi.encodeWithSelector(BaseDecoderAndSanitizer.BaseDecoderAndSanitizer__FunctionSelectorNotSupported.selector));
    }
}
