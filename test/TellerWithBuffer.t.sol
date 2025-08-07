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
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AtomicSolverV3, AtomicQueue} from "src/atomic-queue/AtomicSolverV3.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AaveV3BufferHelper} from "src/base/Roles/AaveV3BufferHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract TellerBufferTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;
    uint8 public constant TELLER_MANAGER_ROLE = 62;

    TellerWithBuffer public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;
    AtomicQueue public atomicQueue;
    AtomicSolverV3 public atomicSolverV3;

    ERC20 internal USDT;
    ERC20 internal USDC;

    function setUp() public {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23091932;
        vm.createSelectFork(vm.envString(rpcKey), blockNumber);

        USDT = getERC20(sourceChain, "USDT");
        USDC = getERC20(sourceChain, "USDC");

        bytes32 salt = keccak256("boring-vault-salt");
        boringVault = new BoringVault{salt: salt}(address(this), "Boring Vault", "BV", 6);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e6, address(USDT), 1.001e4, 0.999e4, 1, 0, 0
        );

        address bufferHelper = address(new AaveV3BufferHelper(getAddress(sourceChain, "v3Pool"), address(boringVault)));

        teller =
            new TellerWithBuffer(address(this), address(boringVault), address(accountant), address(USDT), bufferHelper, bufferHelper);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        atomicQueue = new AtomicQueue(address(this), Authority(address(0)));
        atomicSolverV3 = new AtomicSolverV3(address(this), rolesAuthority);

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        atomicQueue.setAuthority(rolesAuthority);

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
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(QUEUE_ROLE, address(atomicSolverV3), AtomicSolverV3.finishSolve.selector, true);
        rolesAuthority.setRoleCapability(
            CAN_SOLVE_ROLE, address(atomicSolverV3), AtomicSolverV3.redeemSolve.selector, true
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

        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), TELLER_MANAGER_ROLE, true);

        teller.updateAssetData(USDT, true, true, 0);
        teller.updateAssetData(USDC, true, true, 0);
        accountant.setRateProviderData(USDC, true, address(0));
    }

    function testUserDepositPeggedAssets(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);

        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);
        uint96 currentNonce = teller.depositNonce();

        teller.deposit(USDT, amount, 0);
        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");

        teller.deposit(USDC, amount, 0);
        assertEq(teller.depositNonce(), currentNonce + 2, "Deposit nonce should have increased by 2");
        assertEq(teller.depositNonce(), 2, "Deposit nonce should be 2");

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(getERC20(sourceChain, "aV3USDT").balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
    }

    function testUserDepositWithSufficientOpenApproval(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        // approve >= the amount that will be deposited
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(USDT.approve.selector, getAddress(sourceChain, "v3Pool"), amount);
        data[1] = abi.encodeWithSelector(USDC.approve.selector, getAddress(sourceChain, "v3Pool"), amount);

        address[] memory targets = new address[](2);
        targets[0] = address(USDT);
        targets[1] = address(USDC);

        uint256[] memory values = new uint256[](2);

        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);

        boringVault.manage(targets, data, values);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);
        uint96 currentNonce = teller.depositNonce();

        teller.deposit(USDT, amount, 0);
        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");

        teller.deposit(USDC, amount, 0);
        assertEq(teller.depositNonce(), currentNonce + 2, "Deposit nonce should have increased by 2");
        assertEq(teller.depositNonce(), 2, "Deposit nonce should be 2");

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(getERC20(sourceChain, "aV3USDT").balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
    }

    function testUserDepositWithInsufficientOpenApproval(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        // approve less than the amount that will be deposited
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(USDT.approve.selector, getAddress(sourceChain, "v3Pool"), amount - 1);
        data[1] = abi.encodeWithSelector(USDC.approve.selector, getAddress(sourceChain, "v3Pool"), amount - 1);

        address[] memory targets = new address[](2);
        targets[0] = address(USDT);
        targets[1] = address(USDC);

        uint256[] memory values = new uint256[](2);
        
        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);

        boringVault.manage(targets, data, values);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);
        uint96 currentNonce = teller.depositNonce();

        teller.deposit(USDT, amount, 0);
        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");

        teller.deposit(USDC, amount, 0);
        assertEq(teller.depositNonce(), currentNonce + 2, "Deposit nonce should have increased by 2");
        assertEq(teller.depositNonce(), 2, "Deposit nonce should be 2");

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(getERC20(sourceChain, "aV3USDT").balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
    }

    // TODO NEXT:
    // - Add a test for USDT deposit
    // - add a test for deposits with open approvals > amount
    // - add a test for deposits with open approvals < amount
    // - test bulkWithdraw
    // - test bulkDeposit
    // - test depositWithPermit

}