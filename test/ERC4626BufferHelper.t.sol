// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithBuffer, TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithBuffer.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ERC4626BufferHelper} from "src/base/Roles/ERC4626BufferHelper.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

/**
 * @title ERC4626BufferHelperTest
 * @notice Integration tests for the ERC4626BufferHelper using sDAI (Savings DAI) on mainnet
 * @dev sDAI is a standard ERC4626 vault wrapping DAI
 */
contract ERC4626BufferHelperTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant TELLER_MANAGER_ROLE = 62;

    TellerWithBuffer public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    RolesAuthority public rolesAuthority;

    ERC20 internal DAI;
    ERC4626 internal sDAI;

    address public referrer = vm.addr(1337);

    ERC4626BufferHelper public bufferHelper;

    function setUp() public {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23091932;
        vm.createSelectFork(vm.envString(rpcKey), blockNumber);

        DAI = getERC20(sourceChain, "DAI");
        sDAI = ERC4626(getAddress(sourceChain, "sDAI"));

        bytes32 salt = keccak256("erc4626-buffer-test");
        boringVault = new BoringVault{salt: salt}(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(DAI), 1.1e4, 0.9e4, 1, 0, 0
        );

        bufferHelper = new ERC4626BufferHelper(address(sDAI), address(boringVault));

        teller = new TellerWithBuffer(
            address(this), address(boringVault), address(accountant), getAddress(sourceChain, "WETH")
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setPublicCapability(
            address(teller), bytes4(keccak256("deposit(address,uint256,uint256,address)")), true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), TELLER_MANAGER_ROLE, true);

        teller.updateAssetData(DAI, true, true, 0);
        accountant.setRateProviderData(DAI, true, address(0));

        teller.allowBufferHelper(DAI, IBufferHelper(address(bufferHelper)));
        teller.setDepositBufferHelper(DAI, IBufferHelper(address(bufferHelper)));
        teller.setWithdrawBufferHelper(DAI, IBufferHelper(address(bufferHelper)));
    }

    // ============================= DEPOSIT TESTS =============================

    function testUserDeposit(uint256 amount) external {
        amount = bound(amount, 1e18, 100_000e18);

        deal(address(DAI), address(this), amount);
        DAI.safeApprove(address(boringVault), amount);

        uint96 currentNonce = teller.depositNonce();
        teller.deposit(DAI, amount, 0, referrer);

        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");
        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");

        // All DAI should now be in sDAI inside the boring vault
        assertEq(DAI.balanceOf(address(boringVault)), 0, "No DAI should remain in the vault");
        assertGt(ERC20(address(sDAI)).balanceOf(address(boringVault)), 0, "sDAI balance should be > 0");

        // sDAI shares should represent approximately the deposited amount
        uint256 sDAIBal = ERC20(address(sDAI)).balanceOf(address(boringVault));
        uint256 underlyingValue = sDAI.convertToAssets(sDAIBal);
        assertApproxEqAbs(underlyingValue, amount, 2, "sDAI underlying value should match deposit amount");
    }

    function testBulkDeposit(uint256 amount) external {
        amount = bound(amount, 1e18, 100_000e18);

        deal(address(DAI), address(this), amount);
        DAI.safeApprove(address(boringVault), amount);

        teller.bulkDeposit(DAI, amount, 0, address(this));

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
        assertEq(DAI.balanceOf(address(boringVault)), 0, "No DAI should remain in the vault");

        uint256 sDAIBal = ERC20(address(sDAI)).balanceOf(address(boringVault));
        uint256 underlyingValue = sDAI.convertToAssets(sDAIBal);
        assertApproxEqAbs(underlyingValue, amount, 2, "sDAI underlying value should match deposit amount");
    }

    function testDepositWithSufficientOpenApproval(uint256 amount) external {
        amount = bound(amount, 1e18, 100_000e18);
        deal(address(DAI), address(this), amount);

        // Pre-approve the erc4626 vault from boring vault with sufficient allowance
        address[] memory targets = new address[](1);
        targets[0] = address(DAI);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(DAI.approve.selector, address(sDAI), amount);
        uint256[] memory values = new uint256[](1);

        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);
        boringVault.manage(targets, data, values);

        DAI.safeApprove(address(boringVault), amount);
        teller.deposit(DAI, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
        assertEq(DAI.balanceOf(address(boringVault)), 0, "No DAI should remain in the vault");
        assertGt(ERC20(address(sDAI)).balanceOf(address(boringVault)), 0, "sDAI balance should be > 0");
    }

    function testDepositWithInsufficientOpenApproval(uint256 amount) external {
        amount = bound(amount, 2e18, 100_000e18);
        deal(address(DAI), address(this), amount);

        // Pre-approve with less than needed
        address[] memory targets = new address[](1);
        targets[0] = address(DAI);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(DAI.approve.selector, address(sDAI), amount - 1);
        uint256[] memory values = new uint256[](1);

        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);
        boringVault.manage(targets, data, values);

        DAI.safeApprove(address(boringVault), amount);
        teller.deposit(DAI, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
        assertEq(DAI.balanceOf(address(boringVault)), 0, "No DAI should remain in the vault");
        assertGt(ERC20(address(sDAI)).balanceOf(address(boringVault)), 0, "sDAI balance should be > 0");
    }

    // ============================= WITHDRAW TESTS =============================

    function testWithdraw(uint256 amount) external {
        amount = bound(amount, 1e18, 100_000e18);

        // Deposit first
        deal(address(DAI), address(this), amount);
        DAI.safeApprove(address(boringVault), amount);
        teller.deposit(DAI, amount, 0, referrer);

        uint256 sDAIBalBefore = ERC20(address(sDAI)).balanceOf(address(boringVault));
        assertGt(sDAIBalBefore, 0, "sDAI balance should be > 0 after deposit");

        // Withdraw the maximum redeemable amount (accounts for ERC4626 rounding)
        uint256 maxWithdrawable = sDAI.convertToAssets(sDAIBalBefore);
        teller.withdraw(DAI, maxWithdrawable, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 2, "Should have no remaining shares");
        assertApproxEqAbs(ERC20(address(sDAI)).balanceOf(address(boringVault)), 0, 2, "sDAI should be fully withdrawn");
        assertApproxEqAbs(DAI.balanceOf(address(this)), amount, 2, "Should have received DAI back");
    }

    function testBulkWithdraw(uint256 amount) external {
        amount = bound(amount, 1e18, 100_000e18);

        // Deposit first
        deal(address(DAI), address(this), amount);
        DAI.safeApprove(address(boringVault), amount);
        teller.bulkDeposit(DAI, amount, 0, address(this));

        // Withdraw the maximum redeemable amount (accounts for ERC4626 rounding)
        uint256 sDAIBal = ERC20(address(sDAI)).balanceOf(address(boringVault));
        uint256 maxWithdrawable = sDAI.convertToAssets(sDAIBal);
        teller.bulkWithdraw(DAI, maxWithdrawable, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 2, "Should have no remaining shares");
        assertApproxEqAbs(ERC20(address(sDAI)).balanceOf(address(boringVault)), 0, 2, "sDAI should be fully withdrawn");
        assertApproxEqAbs(DAI.balanceOf(address(this)), amount, 2, "Should have received DAI back");
    }

    // ============================= DEPOSIT + WITHDRAW COMBO TESTS =============================

    function testMultipleDepositWithdraws(uint256 amount) external {
        amount = bound(amount, 10e18, 100_000e18);

        deal(address(DAI), address(this), amount);
        DAI.safeApprove(address(boringVault), amount);

        // Deposit 1/10
        teller.deposit(DAI, amount / 10, 0, referrer);
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 10, 2, "Shares after first deposit");

        // Deposit another 1/10 via bulkDeposit
        teller.bulkDeposit(DAI, amount / 10, 0, address(this));
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 5, 4, "Shares after second deposit");

        uint256 sDAIBal = ERC20(address(sDAI)).balanceOf(address(boringVault));
        uint256 underlyingValue = sDAI.convertToAssets(sDAIBal);
        assertApproxEqAbs(underlyingValue, amount / 5, 4, "sDAI underlying should match total deposits");

        // Simulate yield: increase exchange rate
        uint256 onePercentYield = amount / 5 / 100 + 1e15; // add buffer for rounding
        deal(address(DAI), address(boringVault), onePercentYield);

        // Manage vault to deposit the extra DAI into sDAI
        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);
        address[] memory targets = new address[](2);
        targets[0] = address(DAI);
        targets[1] = address(sDAI);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(DAI.approve.selector, address(sDAI), onePercentYield);
        data[1] = abi.encodeWithSignature("deposit(uint256,address)", onePercentYield, address(boringVault));
        uint256[] memory values = new uint256[](2);
        boringVault.manage(targets, data, values);

        vm.warp(block.timestamp + 10);
        accountant.updateExchangeRate(1.01e18);

        // Withdraw via bulkWithdraw
        uint256 sharesBefore = boringVault.balanceOf(address(this));
        teller.bulkWithdraw(DAI, sharesBefore / 2, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), sharesBefore / 2, 4, "Should have half the shares left");
        assertGt(DAI.balanceOf(address(this)), 0, "Should have received DAI");

        // Withdraw rest via regular withdraw
        uint256 remainingShares = boringVault.balanceOf(address(this));
        teller.withdraw(DAI, remainingShares, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 4, "Should have no shares left");
    }

    // ============================= BUFFER HELPER MANAGEMENT TESTS =============================

    function testBufferHelperZeroAddress(uint256 amount) external {
        amount = bound(amount, 1e18, 100_000e18);
        deal(address(DAI), address(this), amount);
        DAI.safeApprove(address(boringVault), amount);

        // Disable buffer helpers
        teller.setWithdrawBufferHelper(DAI, IBufferHelper(address(0)));
        teller.setDepositBufferHelper(DAI, IBufferHelper(address(0)));

        teller.deposit(DAI, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Shares should match deposit");
        assertEq(DAI.balanceOf(address(boringVault)), amount, "DAI should stay in vault (no buffer helper)");
        assertEq(ERC20(address(sDAI)).balanceOf(address(boringVault)), 0, "No sDAI should exist");

        teller.withdraw(DAI, amount / 2, 0, address(this));
        assertApproxEqAbs(DAI.balanceOf(address(this)), amount / 2, 4, "Should have received DAI");
        assertApproxEqAbs(DAI.balanceOf(address(boringVault)), amount / 2, 4, "Half DAI should remain in vault");
    }

    function testBufferHelperChange(uint256 amount) external {
        amount = bound(amount, 1e18, 100_000e18);
        deal(address(DAI), address(this), amount);
        DAI.safeApprove(address(boringVault), amount);

        // Create a new buffer helper (same config, different instance)
        ERC4626BufferHelper newHelper = new ERC4626BufferHelper(address(sDAI), address(boringVault));

        teller.allowBufferHelper(DAI, IBufferHelper(address(newHelper)));
        teller.setDepositBufferHelper(DAI, IBufferHelper(address(newHelper)));
        teller.setWithdrawBufferHelper(DAI, IBufferHelper(address(newHelper)));

        teller.deposit(DAI, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Shares should match deposit");
        assertEq(DAI.balanceOf(address(boringVault)), 0, "No DAI should remain in vault");
        assertGt(ERC20(address(sDAI)).balanceOf(address(boringVault)), 0, "sDAI balance should be > 0");

        teller.withdraw(DAI, amount / 2, 0, address(this));
        assertApproxEqAbs(DAI.balanceOf(address(this)), amount / 2, 4, "Should have received DAI");
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 2, 4, "Half of shares should remain");
    }

    function testShareLock(uint256 amount) external {
        amount = bound(amount, 1e18, 100_000e18);
        deal(address(DAI), address(this), amount);

        teller.setShareLockPeriod(10);
        DAI.safeApprove(address(boringVault), amount);
        teller.deposit(DAI, amount, 0, referrer);

        // Should revert because shares are locked
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector);
        teller.withdraw(DAI, amount / 10, 0, address(this));

        // bulkWithdraw should bypass share lock
        teller.bulkWithdraw(DAI, amount / 10, 0, address(this));
        assertApproxEqAbs(DAI.balanceOf(address(this)), amount / 10, 4, "Should have received DAI via bulkWithdraw");

        // Skip to end of share lock period, regular withdraw should work
        vm.warp(block.timestamp + 10);
        teller.withdraw(DAI, amount / 5, 0, address(this));
        assertApproxEqAbs(
            DAI.balanceOf(address(this)), amount / 5 + amount / 10, 8, "Should have received DAI after lock expires"
        );
    }
}

/**
 * @title ERC4626BufferHelperMorphoUSDTTest
 * @notice Integration tests for the ERC4626BufferHelper using Morpho Galaxy USDT Quality vault on mainnet.
 * @dev Morpho vault (0x71ff...878d) has 18 decimals while USDT has 6 decimals.
 *      Covers all four code paths in ERC4626BufferHelper with hardcoded values:
 *
 *      getDepositManageCall:
 *        Path A – currentAllowance >= amount  → 1 call  (deposit only)
 *        Path B – currentAllowance == 0       → 2 calls (approve + deposit)
 *        Path C – 0 < currentAllowance < amt  → 3 calls (reset + approve + deposit)
 *
 *      getWithdrawManageCall:
 *        Single path                          → 1 call  (withdraw)
 */
contract ERC4626BufferHelperMorphoUSDTTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant TELLER_MANAGER_ROLE = 62;

    TellerWithBuffer public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    RolesAuthority public rolesAuthority;

    ERC20 internal USDT;
    ERC4626 internal morphoVault;

    address public referrer = vm.addr(1337);

    ERC4626BufferHelper public bufferHelper;

    function setUp() public {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        // Morpho Galaxy USDT Quality vault exists at this block
        uint256 blockNumber = 24850000;
        vm.createSelectFork(vm.envString(rpcKey), blockNumber);

        USDT = getERC20(sourceChain, "USDT");
        morphoVault = ERC4626(0x71ffB6a81786eC285D429d531Cf655107B9D878d);

        bytes32 salt = keccak256("erc4626-morpho-usdt-test");
        // Use 6 decimals to match USDT as the base asset
        boringVault = new BoringVault{salt: salt}(address(this), "Boring Vault", "BV", 6);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e6, address(USDT), 1.1e4, 0.9e4, 1, 0, 0
        );

        bufferHelper = new ERC4626BufferHelper(address(morphoVault), address(boringVault));

        teller = new TellerWithBuffer(
            address(this), address(boringVault), address(accountant), getAddress(sourceChain, "WETH")
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setPublicCapability(
            address(teller), bytes4(keccak256("deposit(address,uint256,uint256,address)")), true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        // Grant TELLER_MANAGER_ROLE so individual tests can call boringVault.manage() to set up allowance state
        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), TELLER_MANAGER_ROLE, true);

        teller.updateAssetData(USDT, true, true, 0);
        accountant.setRateProviderData(USDT, true, address(0));

        teller.allowBufferHelper(USDT, IBufferHelper(address(bufferHelper)));
        teller.setDepositBufferHelper(USDT, IBufferHelper(address(bufferHelper)));
        teller.setWithdrawBufferHelper(USDT, IBufferHelper(address(bufferHelper)));
    }

    // ============================================================
    // PATH A – currentAllowance >= amount → 1 call (deposit only)
    // ============================================================

    /**
     * @notice Verifies that getDepositManageCall returns a single deposit call and executes
     *         correctly when the boringVault already has sufficient USDT allowance to morphoVault.
     * @dev Pre-condition: allowance set to 2_000e6, which is >= deposit of 1_000e6.
     *      Expected call array: [morphoVault.deposit(1_000e6, boringVault)]
     */
    function testDepositPath_SufficientAllowance() external {
        uint256 depositAmount = 1_000e6; // 1,000 USDT
        uint256 preApprovalAmount = 2_000e6; // 2,000 USDT – exceeds deposit amount

        // Pre-set boringVault's USDT allowance to morphoVault > depositAmount to trigger Path A
        address[] memory mgmtTargets = new address[](1);
        mgmtTargets[0] = address(USDT);
        bytes[] memory mgmtData = new bytes[](1);
        mgmtData[0] = abi.encodeWithSignature("approve(address,uint256)", address(morphoVault), preApprovalAmount);
        uint256[] memory mgmtValues = new uint256[](1);
        boringVault.manage(mgmtTargets, mgmtData, mgmtValues);

        assertGe(
            USDT.allowance(address(boringVault), address(morphoVault)),
            depositAmount,
            "Pre-condition: allowance must be >= depositAmount"
        );

        // --- Verify return values: Path A produces 1 call ---
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getDepositManageCall(address(USDT), depositAmount);

        assertEq(targets.length, 1, "Path A: should return exactly 1 target");
        assertEq(targets[0], address(morphoVault), "Path A: target must be the morpho vault");
        assertEq(
            data[0],
            abi.encodeWithSignature("deposit(uint256,address)", depositAmount, address(boringVault)),
            "Path A: call must be deposit(amount, vault)"
        );
        assertEq(values[0], 0, "Path A: ETH value must be 0");

        // --- Execute via teller and verify resulting state ---
        deal(address(USDT), address(this), depositAmount);
        USDT.safeApprove(address(boringVault), depositAmount);
        teller.deposit(USDT, depositAmount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), depositAmount, "Should have received expected shares");
        assertEq(USDT.balanceOf(address(boringVault)), 0, "No USDT should remain in the boring vault");
        uint256 morphoShares = ERC20(address(morphoVault)).balanceOf(address(boringVault));
        assertGt(morphoShares, 0, "Morpho vault share balance should be > 0");
        assertApproxEqAbs(
            morphoVault.convertToAssets(morphoShares), depositAmount, 2, "Morpho underlying value should match deposit"
        );
    }

    // ==========================================================
    // PATH B – currentAllowance == 0 → 2 calls (approve + deposit)
    // ==========================================================

    /**
     * @notice Verifies that getDepositManageCall returns approve + deposit calls and executes
     *         correctly when the boringVault has no existing USDT allowance to morphoVault.
     * @dev Pre-condition: fresh state, allowance == 0.
     *      Expected call array: [USDT.approve(morphoVault, 1_000e6), morphoVault.deposit(1_000e6, boringVault)]
     */
    function testDepositPath_ZeroAllowance() external {
        uint256 depositAmount = 1_000e6; // 1,000 USDT

        // Verify zero allowance pre-condition (fresh state after setUp)
        assertEq(
            USDT.allowance(address(boringVault), address(morphoVault)),
            0,
            "Pre-condition: allowance must be 0 for Path B"
        );

        // --- Verify return values: Path B produces 2 calls ---
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getDepositManageCall(address(USDT), depositAmount);

        assertEq(targets.length, 2, "Path B: should return exactly 2 targets");
        assertEq(targets[0], address(USDT), "Path B: first target must be USDT token");
        assertEq(targets[1], address(morphoVault), "Path B: second target must be the morpho vault");
        assertEq(
            data[0],
            abi.encodeWithSignature("approve(address,uint256)", address(morphoVault), depositAmount),
            "Path B: first call must approve morpho vault for full amount"
        );
        assertEq(
            data[1],
            abi.encodeWithSignature("deposit(uint256,address)", depositAmount, address(boringVault)),
            "Path B: second call must be deposit(amount, vault)"
        );
        assertEq(values[0], 0, "Path B: first ETH value must be 0");
        assertEq(values[1], 0, "Path B: second ETH value must be 0");

        // --- Execute via teller and verify resulting state ---
        deal(address(USDT), address(this), depositAmount);
        USDT.safeApprove(address(boringVault), depositAmount);
        teller.deposit(USDT, depositAmount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), depositAmount, "Should have received expected shares");
        assertEq(USDT.balanceOf(address(boringVault)), 0, "No USDT should remain in the boring vault");
        uint256 morphoShares = ERC20(address(morphoVault)).balanceOf(address(boringVault));
        assertGt(morphoShares, 0, "Morpho vault share balance should be > 0");
        assertApproxEqAbs(
            morphoVault.convertToAssets(morphoShares), depositAmount, 2, "Morpho underlying value should match deposit"
        );
    }

    // =======================================================================
    // PATH C – 0 < currentAllowance < amount → 3 calls (reset + approve + deposit)
    // =======================================================================

    /**
     * @notice Verifies that getDepositManageCall returns reset + approve + deposit calls and executes
     *         correctly when the boringVault has a partial (non-zero but insufficient) allowance.
     * @dev Pre-condition: allowance set to 500e6, which is > 0 but < deposit of 1_000e6.
     *      This 3-call pattern is required for USDT which disallows changing a non-zero allowance
     *      directly to another non-zero value.
     *      Expected call array: [
     *        USDT.approve(morphoVault, 0),
     *        USDT.approve(morphoVault, 1_000e6),
     *        morphoVault.deposit(1_000e6, boringVault)
     *      ]
     */
    function testDepositPath_PartialAllowance() external {
        uint256 depositAmount = 1_000e6; // 1,000 USDT
        uint256 partialAllowance = 500e6; // 500 USDT – positive but less than depositAmount

        // Pre-set a non-zero allowance < depositAmount to trigger Path C
        address[] memory mgmtTargets = new address[](1);
        mgmtTargets[0] = address(USDT);
        bytes[] memory mgmtData = new bytes[](1);
        mgmtData[0] = abi.encodeWithSignature("approve(address,uint256)", address(morphoVault), partialAllowance);
        uint256[] memory mgmtValues = new uint256[](1);
        boringVault.manage(mgmtTargets, mgmtData, mgmtValues);

        assertEq(
            USDT.allowance(address(boringVault), address(morphoVault)),
            partialAllowance,
            "Pre-condition: allowance must equal partialAllowance"
        );

        // --- Verify return values: Path C produces 3 calls ---
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getDepositManageCall(address(USDT), depositAmount);

        assertEq(targets.length, 3, "Path C: should return exactly 3 targets");
        assertEq(targets[0], address(USDT), "Path C: first target must be USDT (reset allowance)");
        assertEq(targets[1], address(USDT), "Path C: second target must be USDT (re-approve)");
        assertEq(targets[2], address(morphoVault), "Path C: third target must be the morpho vault");
        assertEq(
            data[0],
            abi.encodeWithSignature("approve(address,uint256)", address(morphoVault), 0),
            "Path C: first call must reset allowance to 0"
        );
        assertEq(
            data[1],
            abi.encodeWithSignature("approve(address,uint256)", address(morphoVault), depositAmount),
            "Path C: second call must approve full deposit amount"
        );
        assertEq(
            data[2],
            abi.encodeWithSignature("deposit(uint256,address)", depositAmount, address(boringVault)),
            "Path C: third call must be deposit(amount, vault)"
        );
        assertEq(values[0], 0, "Path C: first ETH value must be 0");
        assertEq(values[1], 0, "Path C: second ETH value must be 0");
        assertEq(values[2], 0, "Path C: third ETH value must be 0");

        // --- Execute via teller and verify resulting state ---
        deal(address(USDT), address(this), depositAmount);
        USDT.safeApprove(address(boringVault), depositAmount);
        teller.deposit(USDT, depositAmount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), depositAmount, "Should have received expected shares");
        assertEq(USDT.balanceOf(address(boringVault)), 0, "No USDT should remain in the boring vault");
        uint256 morphoShares = ERC20(address(morphoVault)).balanceOf(address(boringVault));
        assertGt(morphoShares, 0, "Morpho vault share balance should be > 0");
        assertApproxEqAbs(
            morphoVault.convertToAssets(morphoShares), depositAmount, 2, "Morpho underlying value should match deposit"
        );
    }

    // ================================================================
    // WITHDRAW PATH – single path → 1 call (withdraw from ERC4626 vault)
    // ================================================================

    /**
     * @notice Verifies that getWithdrawManageCall always returns a single withdraw call and
     *         correctly redeems USDT from the Morpho vault back to the user.
     * @dev The asset parameter of getWithdrawManageCall is intentionally unused in the source;
     *      the Morpho vault address is always the sole target.
     *      Expected call array: [morphoVault.withdraw(amount, boringVault, boringVault)]
     */
    function testWithdrawPath() external {
        uint256 depositAmount = 1_000e6; // 1,000 USDT

        // Deposit first (Path B) so there are Morpho shares to withdraw
        deal(address(USDT), address(this), depositAmount);
        USDT.safeApprove(address(boringVault), depositAmount);
        teller.deposit(USDT, depositAmount, 0, referrer);

        uint256 morphoSharesBefore = ERC20(address(morphoVault)).balanceOf(address(boringVault));
        assertGt(morphoSharesBefore, 0, "Pre-condition: must have Morpho shares to withdraw");

        // Use convertToAssets to determine max safe withdrawal (accounts for ERC4626 rounding)
        uint256 withdrawAmount = morphoVault.convertToAssets(morphoSharesBefore);

        // --- Verify return values: single withdraw path produces 1 call ---
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getWithdrawManageCall(address(USDT), withdrawAmount);

        assertEq(targets.length, 1, "Withdraw: should return exactly 1 target");
        assertEq(targets[0], address(morphoVault), "Withdraw: target must be the morpho vault");
        assertEq(
            data[0],
            abi.encodeWithSignature(
                "withdraw(uint256,address,address)", withdrawAmount, address(boringVault), address(boringVault)
            ),
            "Withdraw: call must be withdraw(amount, vault, vault)"
        );
        assertEq(values[0], 0, "Withdraw: ETH value must be 0");

        // --- Execute via teller and verify resulting state ---
        teller.withdraw(USDT, withdrawAmount, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 2, "Should have no remaining shares");
        uint256 remainingShares = ERC20(address(morphoVault)).balanceOf(address(boringVault));
        assertApproxEqAbs(
            morphoVault.convertToAssets(remainingShares), 0, 2, "Remaining Morpho share value should be dust"
        );
        assertApproxEqAbs(USDT.balanceOf(address(this)), depositAmount, 2, "Should have received USDT back");
    }
}
