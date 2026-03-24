// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData,
    PermitData
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {AtomicSolverV3, AtomicQueue} from "src/archive/atomic-queue/AtomicSolverV3.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

contract TellerWithMultiAssetSupportTest is Test, MerkleTreeHelper {
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

    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;
    AtomicQueue public atomicQueue;
    AtomicSolverV3 public atomicSolverV3;

    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    address internal EETH_LIQUIDITY_POOL;
    address internal WEETH_RATE_PROVIDER;

    address public solver = vm.addr(54);
    address public referrer = vm.addr(1337);

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        EETH_LIQUIDITY_POOL = getAddress(sourceChain, "EETH_LIQUIDITY_POOL");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(WETH));

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
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );
        rolesAuthority.setPublicCapability(address(atomicQueue), AtomicQueue.updateAtomicRequest.selector, true);
        rolesAuthority.setPublicCapability(address(atomicQueue), AtomicQueue.solve.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(atomicSolverV3), SOLVER_ROLE, true);
        rolesAuthority.setUserRole(address(atomicQueue), QUEUE_ROLE, true);
        rolesAuthority.setUserRole(solver, CAN_SOLVE_ROLE, true);

        teller.updateAssetData(WETH, true, true, 0);
        teller.updateAssetData(ERC20(NATIVE), true, true, 0);
        teller.updateAssetData(EETH, true, true, 0);
        teller.updateAssetData(WEETH, true, true, 0);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
    }

    function testDepositReverting(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);
        // Turn on share lock period, and deposit reverting
        boringVault.setBeforeTransferHook(address(teller));

        teller.setShareLockPeriod(1 days);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();

        WETH.safeApprove(address(boringVault), wETH_amount);
        EETH.safeApprove(address(boringVault), eETH_amount);
        uint256 shares0 =
            teller.deposit(DepositParams(WETH, wETH_amount, 0, address(this)), referrer, ComplianceData(0, ""));
        uint256 firstDepositTimestamp = block.timestamp;
        uint256 firstDepositSharePrice = accountant.getRateSafe();
        // Skip 1 days to finalize first deposit.
        skip(1 days + 1);
        uint256 shares1 =
            teller.deposit(DepositParams(EETH, eETH_amount, 0, address(this)), referrer, ComplianceData(0, ""));
        uint256 secondDepositTimestamp = block.timestamp;
        uint256 secondDepositSharePrice = accountant.getRateSafe();

        // Even if setShareLockPeriod is set to 2 days, first deposit is still not revertable.
        teller.setShareLockPeriod(2 days);

        // If depositReverter tries to revert the first deposit, call fails.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreUnLocked.selector)
        );
        teller.refundDeposit(
            1,
            address(this),
            address(WETH),
            wETH_amount,
            shares0,
            firstDepositTimestamp,
            1 days,
            firstDepositSharePrice,
            referrer
        );

        // However the second deposit is still revertable.
        teller.refundDeposit(
            2,
            address(this),
            address(EETH),
            eETH_amount,
            shares1,
            secondDepositTimestamp,
            1 days,
            secondDepositSharePrice,
            referrer
        );

        // Calling revert deposit again should revert.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__BadDepositHash.selector)
        );
        teller.refundDeposit(
            2,
            address(this),
            address(EETH),
            eETH_amount,
            shares1,
            secondDepositTimestamp,
            1 days,
            secondDepositSharePrice,
            referrer
        );
    }

    function testUserDepositPeggedAssets(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();

        WETH.safeApprove(address(boringVault), wETH_amount);
        EETH.safeApprove(address(boringVault), eETH_amount);

        uint96 currentNonce = teller.depositNonce();

        teller.deposit(DepositParams(WETH, wETH_amount, 0, address(this)), referrer, ComplianceData(0, ""));
        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");
        teller.deposit(DepositParams(EETH, eETH_amount, 0, address(this)), referrer, ComplianceData(0, ""));
        assertEq(teller.depositNonce(), currentNonce + 2, "Deposit nonce should have increased by 2");
        assertEq(teller.depositNonce(), 2, "Deposit nonce should be 2");

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");
    }

    function testUserDepositNonPeggedAssets(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WEETH.safeApprove(address(boringVault), weETH_amount);

        teller.deposit(DepositParams(WEETH, weETH_amount, 0, address(this)), referrer, ComplianceData(0, ""));

        uint256 expected_shares = amount;

        assertApproxEqRel(
            boringVault.balanceOf(address(this)), expected_shares, 0.000001e18, "Should have received expected shares"
        );
    }

    function testUserDepositNative(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        deal(address(this), 2 * amount);

        teller.deposit{value: amount}(
            DepositParams(ERC20(NATIVE), 0, 0, address(this)), referrer, ComplianceData(0, "")
        );

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
    }

    function testDepositWithPermitNativeReverts(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__AssetNotSupported.selector);
        teller.depositWithPermit(
            DepositParams(NATIVE_ERC20, amount, 0, address(this)),
            PermitData(block.timestamp, 0, bytes32(0), bytes32(0)),
            referrer,
            ComplianceData(0, "")
        );
    }

    function testUserPermitDeposit(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 userKey = 111;
        address user = vm.addr(userKey);

        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), user, weETH_amount);
        // function sign(uint256 privateKey, bytes32 digest) external pure returns (uint8 v, bytes32 r, bytes32 s);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                WEETH.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringVault),
                        weETH_amount,
                        WEETH.nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);

        vm.startPrank(user);
        teller.depositWithPermit(
            DepositParams(WEETH, weETH_amount, 0, user),
            PermitData(block.timestamp, v, r, s),
            referrer,
            ComplianceData(0, "")
        );
        vm.stopPrank();

        // and if user supplied wrong permit data, deposit will fail.
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                WEETH.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringVault),
                        weETH_amount,
                        WEETH.nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (v, r, s) = vm.sign(userKey, digest);

        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__PermitFailedAndAllowanceTooLow.selector
            )
        );
        teller.depositWithPermit(
            DepositParams(WEETH, weETH_amount, 0, user),
            PermitData(block.timestamp, v, r, s),
            referrer,
            ComplianceData(0, "")
        );
        vm.stopPrank();
    }

    function testUserPermitDepositWithFrontRunning(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 userKey = 111;
        address user = vm.addr(userKey);

        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), user, weETH_amount);
        // function sign(uint256 privateKey, bytes32 digest) external pure returns (uint8 v, bytes32 r, bytes32 s);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                WEETH.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringVault),
                        weETH_amount,
                        WEETH.nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);

        // Assume attacker seems users TX in the mem pool and tries griefing them by calling `permit` first.
        address attacker = vm.addr(0xDEAD);
        vm.startPrank(attacker);
        WEETH.permit(user, address(boringVault), weETH_amount, block.timestamp, v, r, s);
        vm.stopPrank();

        // Users TX is still successful.
        vm.startPrank(user);
        teller.depositWithPermit(
            DepositParams(WEETH, weETH_amount, 0, user),
            PermitData(block.timestamp, v, r, s),
            referrer,
            ComplianceData(0, "")
        );
        vm.stopPrank();

        assertTrue(boringVault.balanceOf(user) > 0, "Should have received shares");
    }

    function testBulkDeposit(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();
        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WETH.safeApprove(address(boringVault), wETH_amount);
        EETH.safeApprove(address(boringVault), eETH_amount);
        WEETH.safeApprove(address(boringVault), weETH_amount);

        teller.bulkDeposit(WETH, wETH_amount, 0, address(this));
        teller.bulkDeposit(EETH, eETH_amount, 0, address(this));
        teller.bulkDeposit(WEETH, weETH_amount, 0, address(this));

        uint256 expected_shares = 3 * amount;

        assertApproxEqRel(
            boringVault.balanceOf(address(this)), expected_shares, 0.0001e18, "Should have received expected shares"
        );
    }

    function testBulkWithdraw(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);
        uint256 eETH_amount = amount;
        deal(address(this), eETH_amount + 1);
        ILiquidityPool(EETH_LIQUIDITY_POOL).deposit{value: eETH_amount + 1}();
        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), address(this), weETH_amount);

        WETH.safeApprove(address(boringVault), wETH_amount);
        EETH.safeApprove(address(boringVault), eETH_amount);
        WEETH.safeApprove(address(boringVault), weETH_amount);

        uint256 shares_0 = teller.bulkDeposit(WETH, wETH_amount, 0, address(this));
        uint256 shares_1 = teller.bulkDeposit(EETH, eETH_amount, 0, address(this));
        uint256 shares_2 = teller.bulkDeposit(WEETH, weETH_amount, 0, address(this));

        uint256 assets_out_0 = teller.bulkWithdraw(WETH, shares_0, 0, address(this));
        uint256 assets_out_1 = teller.bulkWithdraw(EETH, shares_1, 0, address(this));
        uint256 assets_out_2 = teller.bulkWithdraw(WEETH, shares_2, 0, address(this));

        assertApproxEqAbs(assets_out_0, wETH_amount, 1, "Should have received expected wETH assets");
        assertApproxEqAbs(assets_out_1, eETH_amount, 1, "Should have received expected eETH assets");
        assertApproxEqAbs(assets_out_2, weETH_amount, 1, "Should have received expected weETH assets");
    }

    function testWithdrawWithAtomicQueue(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        address user = vm.addr(9);
        uint256 wETH_amount = amount;
        deal(address(WETH), user, wETH_amount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), wETH_amount);

        uint256 shares = teller.deposit(DepositParams(WETH, wETH_amount, 0, user), referrer, ComplianceData(0, ""));

        // Share lock period is not set, so user can submit withdraw request immediately.
        AtomicQueue.AtomicRequest memory req = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1 days), atomicPrice: 1e18, offerAmount: uint96(shares), inSolve: false
        });
        boringVault.approve(address(atomicQueue), shares);
        atomicQueue.updateAtomicRequest(boringVault, WETH, req);
        vm.stopPrank();

        // Solver approves solver contract to spend enough assets to cover withdraw.
        vm.startPrank(solver);
        WETH.safeApprove(address(atomicSolverV3), wETH_amount);
        // Solve withdraw request.
        address[] memory users = new address[](1);
        users[0] = user;
        atomicSolverV3.redeemSolve(atomicQueue, boringVault, WETH, users, 0, type(uint256).max, teller);
        vm.stopPrank();
    }

    function testUpdateAssetData() external {
        (bool allowDeposits, bool allowWithdraws, uint16 sharePremium) = teller.assetData(WETH);
        assertTrue(allowDeposits == true, "WETH deposits should be supported");
        assertTrue(allowWithdraws == true, "WETH withdraws should be supported");
        assertEq(sharePremium, 0, "WETH sharePremium should be zero.");

        teller.updateAssetData(WETH, false, false, 0);

        (allowDeposits, allowWithdraws, sharePremium) = teller.assetData(WETH);

        assertTrue(allowDeposits == false, "WETH deposits should not be supported");
        assertTrue(allowWithdraws == false, "WETH withdraws should not be supported");
        assertEq(sharePremium, 0, "WETH sharePremium should be zero.");

        uint16 newSharePremium = 40;
        teller.updateAssetData(WETH, true, true, newSharePremium);

        (allowDeposits, allowWithdraws, sharePremium) = teller.assetData(WETH);

        assertTrue(allowDeposits == true, "WETH deposits should be supported");
        assertTrue(allowWithdraws == true, "WETH withdraws should be supported");
        assertEq(sharePremium, 40, "WETH sharePremium should equal newSharePremium.");
    }

    function testDenyList() external {
        boringVault.setBeforeTransferHook(address(teller));
        address attacker = vm.addr(0xDEAD);
        deal(address(boringVault), attacker, 1e18, true);
        // Transfers currently work.
        vm.prank(attacker);
        boringVault.transfer(address(this), 0.1e18);

        // But if attacker is added to the deny list, transfers should fail.
        teller.denyAll(attacker);

        vm.startPrank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                attacker,
                address(this),
                attacker
            )
        );
        boringVault.transfer(address(this), 0.1e18);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                attacker,
                address(this),
                address(this)
            )
        );
        boringVault.transferFrom(attacker, address(this), 0.1e18);

        // If attacker is removed from the deny list, transfers should work again.
        teller.allowAll(attacker);

        vm.prank(attacker);
        boringVault.transfer(address(this), 0.1e18);

        // Make sure we can deny certain operators.
        address operator = vm.addr(2);
        address normalUser = vm.addr(3);

        teller.denyAll(operator);

        vm.startPrank(operator);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                normalUser,
                normalUser,
                operator
            )
        );
        boringVault.transferFrom(normalUser, normalUser, 1e18);
        vm.stopPrank();
    }

    function testHookLogic() external {
        boringVault.setBeforeTransferHook(address(teller));
        address from = vm.addr(1);
        address to = vm.addr(2);

        deal(address(boringVault), from, 100e18, true);
        vm.prank(from);
        boringVault.approve(address(this), 100e18);

        // Transfers currently work.
        boringVault.transferFrom(from, to, 1e18);

        // Transfers fail if from is denied.
        teller.denyFrom(from);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                from,
                to,
                address(this)
            )
        );
        boringVault.transferFrom(from, to, 1e18);

        teller.allowFrom(from);

        // Transfers fail if to is denied.
        teller.denyTo(to);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                from,
                to,
                address(this)
            )
        );
        boringVault.transferFrom(from, to, 1e18);

        teller.allowTo(to);

        // Transfers fail if operator is denied.
        teller.denyOperator(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                from,
                to,
                address(this)
            )
        );
        boringVault.transferFrom(from, to, 1e18);

        teller.allowOperator(address(this));

        // Transfers currently work.
        boringVault.transferFrom(from, to, 1e18);
    }

    function testSharePremiumLogicERC20Deposit(uint256 depositAmount, uint16 sharePremium) external {
        depositAmount = bound(depositAmount, 0.0001e18, 1_000e18);
        sharePremium = uint16(bound(sharePremium, 0, 1_000));
        teller.updateAssetData(WETH, true, true, sharePremium);

        deal(address(WETH), address(this), depositAmount);
        WETH.approve(address(boringVault), depositAmount);

        uint256 shareDelta = boringVault.balanceOf(address(this));
        uint256 sharesOut =
            teller.deposit(DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(0, ""));
        shareDelta = boringVault.balanceOf(address(this)) - shareDelta;

        // WETH is 1:1 with share price, so shares out should equal depositAmount - sharePremium
        uint256 expectedSharesOut = depositAmount.mulDivDown(1e4 - sharePremium, 1e4);

        assertEq(shareDelta, sharesOut, "Share delta should match shares out.");
        assertEq(sharesOut, expectedSharesOut, "Shares out should equal expected shares out.");
        assertEq(WETH.balanceOf(address(this)), 0, "All assets should have been spent.");
        assertEq(WETH.balanceOf(address(boringVault)), depositAmount, "All assets should be in boring vault.");
    }

    function testSharePremiumLogicNativeDeposit(uint256 depositAmount, uint16 sharePremium) external {
        depositAmount = bound(depositAmount, 0.0001e18, 1_000e18);
        sharePremium = uint16(bound(sharePremium, 0, 1_000));
        teller.updateAssetData(ERC20(NATIVE), true, true, sharePremium);

        deal(address(this), depositAmount);

        uint256 shareDelta = boringVault.balanceOf(address(this));
        uint256 sharesOut = teller.deposit{value: depositAmount}(
            DepositParams(ERC20(NATIVE), 0, 0, address(this)), referrer, ComplianceData(0, "")
        );
        shareDelta = boringVault.balanceOf(address(this)) - shareDelta;

        // ETH is 1:1 with share price, so shares out should equal depositAmount - sharePremium
        uint256 expectedSharesOut = depositAmount.mulDivDown(1e4 - sharePremium, 1e4);

        assertEq(shareDelta, sharesOut, "Share delta should match shares out.");
        assertEq(sharesOut, expectedSharesOut, "Shares out should equal expected shares out.");
        assertEq(address(this).balance, 0, "All assets should have been spent.");
        assertEq(WETH.balanceOf(address(boringVault)), depositAmount, "All assets should be in boring vault.");
    }

    function testAllowDeposits() external {
        // Stop deposits.
        teller.updateAssetData(WETH, false, false, 0);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__AssetNotSupported.selector
                )
            )
        );
        teller.deposit(DepositParams(WETH, 0, 0, address(this)), referrer, ComplianceData(0, ""));

        // Allow deposits
        teller.updateAssetData(WETH, true, false, 0);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector))
        );
        teller.deposit(DepositParams(WETH, 0, 0, address(this)), referrer, ComplianceData(0, ""));

        // Stop deposits.
        teller.updateAssetData(WETH, false, false, 0);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__AssetNotSupported.selector
                )
            )
        );
        teller.depositWithPermit(
            DepositParams(WETH, 0, 0, address(this)),
            PermitData(0, 0, bytes32(0), bytes32(0)),
            referrer,
            ComplianceData(0, "")
        );

        // Allow deposits
        teller.updateAssetData(WETH, true, false, 0);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector))
        );
        teller.depositWithPermit(
            DepositParams(WETH, 0, 0, address(this)),
            PermitData(0, 0, bytes32(0), bytes32(0)),
            referrer,
            ComplianceData(0, "")
        );

        // Stop deposits.
        teller.updateAssetData(WETH, false, false, 0);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__AssetNotSupported.selector
                )
            )
        );
        teller.bulkDeposit(WETH, 0, 0, address(this));

        // Allow deposits
        teller.updateAssetData(WETH, true, false, 0);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector))
        );
        teller.bulkDeposit(WETH, 0, 0, address(this));
    }

    function testAllowWithdraws() external {
        // Stop withdraws.
        teller.updateAssetData(WETH, false, false, 0);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__AssetNotSupported.selector
                )
            )
        );
        teller.bulkWithdraw(WETH, 0, 0, address(this));

        // Allow withdraws
        teller.updateAssetData(WETH, false, true, 0);

        vm.expectRevert(
            bytes(abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroShares.selector))
        );
        teller.bulkWithdraw(WETH, 0, 0, address(this));
    }

    function testShowDepositAndTransferLogic() external {
        boringVault.setBeforeTransferHook(address(teller));
        // If share lock period is set to 0 we allow for deposit and transfer in the same tx.
        teller.setShareLockPeriod(0);

        address user = vm.addr(1);

        uint256 shareDelta = boringVault.balanceOf(user);
        depositAndTransfer(WETH, 1e18, user, false);
        shareDelta = boringVault.balanceOf(user) - shareDelta;

        assertEq(shareDelta, 1e18, "User should have received 1 share.");

        // But if share lock period is greater than 0, deposit and transfers in the same tx revert.
        teller.setShareLockPeriod(1);

        depositAndTransfer(WETH, 1e18, user, true);
    }

    function testMultipleDepositsWithShareLockPeriod() external {
        teller.setShareLockPeriod(10000);
        // can deposit multiple times in a row without share lock blocking
        deal(address(WETH), address(this), 1e18);
        WETH.safeApprove(address(boringVault), 1e18);
        teller.deposit(DepositParams(WETH, 0.1e18, 0, address(this)), referrer, ComplianceData(0, ""));
        skip(100);
        teller.deposit(DepositParams(WETH, 0.1e18, 0, address(this)), referrer, ComplianceData(0, ""));
    }

    function testDepositRevertsWhenDenyFrom() external {
        teller.denyFrom(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                address(this),
                address(this),
                address(this)
            )
        );
        teller.deposit(DepositParams(WETH, 1e18, 0, address(this)), referrer, ComplianceData(0, ""));
    }

    function testDepositRevertsWhenDenyTo() external {
        teller.denyTo(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                address(this),
                address(this),
                address(this)
            )
        );
        teller.deposit(DepositParams(WETH, 1e18, 0, address(this)), referrer, ComplianceData(0, ""));
    }

    function testDepositRevertsWhenDenyOperator() external {
        teller.denyOperator(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                address(this),
                address(this),
                address(this)
            )
        );
        teller.deposit(DepositParams(WETH, 1e18, 0, address(this)), referrer, ComplianceData(0, ""));
    }

    function testDepositRevertsWhenDenyAll() external {
        teller.denyAll(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                address(this),
                address(this),
                address(this)
            )
        );
        teller.deposit(DepositParams(WETH, 1e18, 0, address(this)), referrer, ComplianceData(0, ""));
    }

    function testReverts() external {
        // Test pause logic
        teller.pause();

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__Paused.selector)
        );
        teller.deposit(DepositParams(WETH, 0, 0, address(this)), referrer, ComplianceData(0, ""));

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__Paused.selector)
        );
        teller.depositWithPermit(
            DepositParams(WETH, 0, 0, address(this)),
            PermitData(0, 0, bytes32(0), bytes32(0)),
            referrer,
            ComplianceData(0, "")
        );

        teller.unpause();

        teller.updateAssetData(WETH, false, false, 0);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__AssetNotSupported.selector)
        );
        teller.deposit(DepositParams(WETH, 0, 0, address(this)), referrer, ComplianceData(0, ""));

        teller.updateAssetData(WETH, true, true, 0);

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector)
        );
        teller.deposit(DepositParams(WETH, 0, 0, address(this)), referrer, ComplianceData(0, ""));

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DualDeposit.selector)
        );
        teller.deposit{value: 1}(DepositParams(WETH, 1, 0, address(this)), referrer, ComplianceData(0, ""));

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__MinimumMintNotMet.selector)
        );
        teller.deposit(DepositParams(WETH, 1, type(uint256).max, address(this)), referrer, ComplianceData(0, ""));

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector)
        );
        teller.deposit(DepositParams(NATIVE_ERC20, 0, 0, address(this)), referrer, ComplianceData(0, ""));

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__MinimumMintNotMet.selector)
        );
        teller.deposit{value: 1}(
            DepositParams(NATIVE_ERC20, 1, type(uint256).max, address(this)), referrer, ComplianceData(0, "")
        );

        // updateAssetData revert
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharePremiumTooLarge.selector
            )
        );
        teller.updateAssetData(WETH, true, true, 1_001);

        // bulkDeposit reverts
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroAssets.selector)
        );
        teller.bulkDeposit(WETH, 0, 0, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__MinimumMintNotMet.selector)
        );
        teller.bulkDeposit(WETH, 1, type(uint256).max, address(this));

        // bulkWithdraw reverts
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ZeroShares.selector)
        );
        teller.bulkWithdraw(WETH, 0, 0, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__MinimumAssetsNotMet.selector
            )
        );
        teller.bulkWithdraw(WETH, 1, type(uint256).max, address(this));

        // Set share lock reverts
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ShareLockPeriodTooLong.selector
            )
        );
        teller.setShareLockPeriod(3 days + 1);

        teller.setShareLockPeriod(3 days);
        boringVault.setBeforeTransferHook(address(teller));

        // Have user deposit
        address user = vm.addr(333);
        vm.startPrank(user);
        uint256 wETH_amount = 1e18;
        deal(address(WETH), user, wETH_amount);
        WETH.safeApprove(address(boringVault), wETH_amount);

        teller.deposit(DepositParams(WETH, wETH_amount, 0, user), referrer, ComplianceData(0, ""));

        // Trying to transfer shares should revert.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector)
        );
        boringVault.transfer(address(this), 1);

        vm.stopPrank();
        // Calling transferFrom should also revert.
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector)
        );
        boringVault.transferFrom(user, address(this), 1);

        // But if user waits 3 days.
        skip(3 days + 1);
        // They can now transfer.
        vm.prank(user);
        boringVault.transfer(address(this), 1);

        teller.setDepositCap(100e18);
        wETH_amount = 101e18;
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DepositExceedsCap.selector)
        );
        teller.deposit(DepositParams(WETH, wETH_amount, 0, address(this)), referrer, ComplianceData(0, ""));

        //now succeeds
        teller.setDepositCap(1000e18);

        deal(address(WETH), user, 1000e18);
        wETH_amount = 998e18;
        vm.startPrank(user);
        WETH.approve(address(boringVault), type(uint256).max);
        teller.deposit(DepositParams(WETH, wETH_amount, 0, user), referrer, ComplianceData(0, ""));

        //now we add more than deposit cap
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DepositExceedsCap.selector)
        );
        teller.deposit(DepositParams(WETH, 2e18, 0, user), referrer, ComplianceData(0, ""));
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function depositAndTransfer(ERC20 asset, uint256 depositAmount, address to, bool expectRevert) public {
        deal(address(asset), address(this), depositAmount);
        asset.approve(address(boringVault), depositAmount);
        uint256 shares =
            teller.deposit(DepositParams(asset, depositAmount, 0, address(this)), referrer, ComplianceData(0, ""));
        if (expectRevert) {
            vm.expectRevert(
                bytes(
                    abi.encodeWithSelector(
                        TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector
                    )
                )
            );
            boringVault.transfer(to, shares);
        } else {
            boringVault.transfer(to, shares);
        }
    }
    //throws weird natspec error when using TellerWithMultiAssetSupport.Deposit
    event Deposit(
        uint256 nonce,
        address indexed receiver,
        address indexed depositAsset,
        uint256 depositAmount,
        uint256 shareAmount,
        uint256 depositTimestamp,
        uint256 shareLockPeriodAtTimeOfDeposit,
        address indexed referralAddress
    );

    event ComplianceSignerSet(address indexed signer);
    event ComplianceWindowSet(uint96 window);

    function testDepositEmitsReadableReferralEvent() external {
        uint256 amount = 1e18;

        uint256 wETH_amount = amount;
        deal(address(WETH), address(this), wETH_amount);

        WETH.safeApprove(address(boringVault), wETH_amount);
        vm.expectEmit();
        emit Deposit(1, address(this), address(WETH), wETH_amount, wETH_amount, block.timestamp, 0, referrer);
        teller.deposit(DepositParams(WETH, wETH_amount, 0, address(this)), referrer, ComplianceData(0, ""));
    }

    // ======================================= COMPLIANCE TESTS =======================================

    function testSetComplianceSigner() external {
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);

        vm.expectEmit();
        emit ComplianceSignerSet(signer);
        teller.setComplianceSigner(signer);

        assertEq(teller.complianceSigner(), signer, "Compliance signer should be set");
    }

    function testSetComplianceWindow() external {
        uint96 window = 1 hours;

        vm.expectEmit();
        emit ComplianceWindowSet(window);
        teller.setComplianceWindow(window);

        assertEq(teller.complianceWindow(), window, "Compliance window should be set");
    }

    function testDepositWithComplianceSignature() external {
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);
        teller.setComplianceSigner(signer);

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 messageHash = keccak256(
            abi.encode(address(teller), block.chainid, address(this), address(WETH), depositAmount, deadline)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 shares = teller.deposit(
            DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(deadline, signature)
        );

        assertEq(shares, depositAmount, "Should have received expected shares");
        assertTrue(teller.usedComplianceSignatures(messageHash), "Compliance signature should be marked as used");
    }

    function testComplianceSignatureReplayReverts() external {
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);
        teller.setComplianceSigner(signer);

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), 2 * depositAmount);
        WETH.safeApprove(address(boringVault), 2 * depositAmount);

        uint256 deadline = block.timestamp + 1 hours;
        bytes32 messageHash = keccak256(
            abi.encode(address(teller), block.chainid, address(this), address(WETH), depositAmount, deadline)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First deposit succeeds.
        teller.deposit(
            DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(deadline, signature)
        );

        // Second deposit with same signature reverts.
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        teller.deposit(
            DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(deadline, signature)
        );
    }

    function testComplianceSignatureExpiredReverts() external {
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);
        teller.setComplianceSigner(signer);

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);

        // Set deadline in the past.
        uint256 deadline = block.timestamp - 1;
        bytes32 messageHash = keccak256(
            abi.encode(address(teller), block.chainid, address(this), address(WETH), depositAmount, deadline)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        teller.deposit(
            DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(deadline, signature)
        );
    }

    function testComplianceWindowExceededReverts() external {
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);
        teller.setComplianceSigner(signer);

        // Set a 1-hour compliance window (relative duration, not absolute timestamp).
        uint96 window = 1 hours;
        teller.setComplianceWindow(window);

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);

        // Use a deadline that exceeds block.timestamp + window.
        uint256 deadline = block.timestamp + uint256(window) + 1;
        bytes32 messageHash = keccak256(
            abi.encode(address(teller), block.chainid, address(this), address(WETH), depositAmount, deadline)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        teller.deposit(
            DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(deadline, signature)
        );
    }

    function testComplianceWindowRelativeNotAbsolute() external {
        // Prove that complianceWindow is treated as a relative duration, not an absolute timestamp.
        // If someone mistakenly sets window = 604800 (7 days in seconds), it should allow
        // deadlines up to block.timestamp + 604800, NOT treat 604800 as a Unix timestamp.
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);
        teller.setComplianceSigner(signer);

        uint96 sevenDays = 7 days;
        teller.setComplianceWindow(sevenDays);

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);

        // A deadline 6 days from now should succeed (within the 7-day window).
        uint256 deadline = block.timestamp + 6 days;
        bytes32 messageHash = keccak256(
            abi.encode(address(teller), block.chainid, address(this), address(WETH), depositAmount, deadline)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should NOT revert -- deadline is within the window.
        teller.deposit(
            DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(deadline, signature)
        );
    }

    function testComplianceWindowSmallValueDoesNotBlockDeposits() external {
        // Regression: if complianceWindow were treated as an absolute timestamp,
        // setting it to a small value like 3600 (1 hour) would be interpreted as
        // Unix timestamp 3600 (Jan 1, 1970 01:00 UTC), blocking ALL deposits
        // because every modern deadline > 3600. With relative semantics, 3600
        // means "deadline must be within 1 hour of now", which works correctly.
        uint256 signerKey = 0xBEEF;
        address signer = vm.addr(signerKey);
        teller.setComplianceSigner(signer);

        uint96 oneHour = 1 hours;
        teller.setComplianceWindow(oneHour);

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);

        // Deadline 30 minutes from now -- well within the 1-hour window.
        uint256 deadline = block.timestamp + 30 minutes;
        bytes32 messageHash = keccak256(
            abi.encode(address(teller), block.chainid, address(this), address(WETH), depositAmount, deadline)
        );
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Should succeed -- deadline is within the window.
        teller.deposit(
            DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(deadline, signature)
        );
    }

    function testComplianceDisabledWhenSignerIsZero() external {
        // complianceSigner is address(0) by default, so compliance is disabled.
        assertEq(teller.complianceSigner(), address(0), "Compliance signer should be zero by default");

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);

        // Deposit with empty compliance data succeeds when signer is zero.
        uint256 shares =
            teller.deposit(DepositParams(WETH, depositAmount, 0, address(this)), referrer, ComplianceData(0, ""));
        assertEq(shares, depositAmount, "Should have received expected shares with compliance disabled");
    }

    // ========================================= TRANSFER ALLOWLIST TESTS =========================================

    function testTransferAllowlist_DefaultUnrestricted() external {
        assertEq(teller.transferAllowedRole(), type(uint8).max);

        address alice = vm.addr(0xA11CE);
        address bob = vm.addr(0xB0B);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        vm.prank(alice);
        boringVault.transfer(bob, 0.5e18);
        assertEq(boringVault.balanceOf(bob), 0.5e18);
    }

    function testTransferAllowlist_BlocksUserToUser() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address bob = vm.addr(0xB0B);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferNotAllowed.selector);
        boringVault.transfer(bob, 0.5e18);
    }

    function testTransferAllowlist_AllowsTransferToQueueRole() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address queueAddr = address(atomicQueue);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        vm.prank(alice);
        boringVault.transfer(queueAddr, 0.5e18);
        assertEq(boringVault.balanceOf(queueAddr), 0.5e18);
    }

    function testTransferAllowlist_AllowsTransferFromQueueRole() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address queueAddr = address(atomicQueue);

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, queueAddr), address(0), ComplianceData(0, ""));

        vm.prank(queueAddr);
        boringVault.transfer(alice, 0.5e18);
        assertEq(boringVault.balanceOf(alice), 0.5e18);
    }

    function testTransferAllowlist_ReenablePublicTransfers() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);
        teller.setTransferAllowedRole(type(uint8).max);

        address alice = vm.addr(0xA11CE);
        address bob = vm.addr(0xB0B);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        vm.prank(alice);
        boringVault.transfer(bob, 0.5e18);
        assertEq(boringVault.balanceOf(bob), 0.5e18);
    }

    function testTransferAllowlist_TransferFromBlockedWithoutRole() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address bob = vm.addr(0xB0B);
        address charlie = vm.addr(0xC);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        boringVault.approve(charlie, 1e18);
        vm.stopPrank();

        // Operator charlie calls transferFrom on behalf of alice -> bob. Neither has QUEUE_ROLE.
        vm.prank(charlie);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferNotAllowed.selector);
        boringVault.transferFrom(alice, bob, 0.5e18);
    }

    function testTransferAllowlist_TransferFromAllowedWhenRecipientHasRole() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address queueAddr = address(atomicQueue);
        address charlie = vm.addr(0xC);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        boringVault.approve(charlie, 1e18);
        vm.stopPrank();

        // Operator charlie transfers alice's shares to queue (queue has QUEUE_ROLE).
        vm.prank(charlie);
        boringVault.transferFrom(alice, queueAddr, 0.5e18);
        assertEq(boringVault.balanceOf(queueAddr), 0.5e18);
    }

    function testTransferAllowlist_TransferFromAllowedWhenSenderHasRole() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address queueAddr = address(atomicQueue);
        address charlie = vm.addr(0xC);

        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, queueAddr), address(0), ComplianceData(0, ""));

        // queue approves charlie as operator
        vm.prank(queueAddr);
        boringVault.approve(charlie, 1e18);

        // Operator charlie transfers queue's shares to alice (queue has QUEUE_ROLE as sender).
        vm.prank(charlie);
        boringVault.transferFrom(queueAddr, alice, 0.5e18);
        assertEq(boringVault.balanceOf(alice), 0.5e18);
    }

    function testTransferAllowlist_BothSidesHaveRole() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        // Give a second address QUEUE_ROLE.
        address secondQueue = vm.addr(0xDEAD);
        rolesAuthority.setUserRole(secondQueue, QUEUE_ROLE, true);

        address queueAddr = address(atomicQueue);
        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, queueAddr), address(0), ComplianceData(0, ""));

        // Transfer between two QUEUE_ROLE holders succeeds.
        vm.prank(queueAddr);
        boringVault.transfer(secondQueue, 0.5e18);
        assertEq(boringVault.balanceOf(secondQueue), 0.5e18);
    }

    function testTransferAllowlist_RoleRevokedBlocksTransfer() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address queueAddr = address(atomicQueue);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Revoke QUEUE_ROLE from atomicQueue.
        rolesAuthority.setUserRole(queueAddr, QUEUE_ROLE, false);

        // Now transfer to queue should fail (neither side has the role).
        vm.prank(alice);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferNotAllowed.selector);
        boringVault.transfer(queueAddr, 0.5e18);
    }

    function testTransferAllowlist_DepositAndWithdrawStillWork() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        // Deposit still works even with allowlist active.
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        assertGt(shares, 0, "deposit should mint shares");
        assertEq(boringVault.balanceOf(alice), shares, "alice should hold shares");
        vm.stopPrank();
    }

    function testTransferAllowlist_ZeroAmountTransferBlockedWithoutRole() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address bob = vm.addr(0xB0B);

        // Zero-amount transfer still hits the allowlist check.
        vm.prank(alice);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferNotAllowed.selector);
        boringVault.transfer(bob, 0);
    }

    function testTransferAllowlist_DenyListTakesPrecedenceOverAllowlist() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address queueAddr = address(atomicQueue);
        uint256 depositAmount = 1e18;
        deal(address(WETH), address(this), depositAmount);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, queueAddr), address(0), ComplianceData(0, ""));

        // Deny the queue from sending.
        teller.denyAll(queueAddr);

        // Even though queue has QUEUE_ROLE, deny list blocks the transfer.
        vm.prank(queueAddr);
        vm.expectRevert();
        boringVault.transfer(vm.addr(0xB0B), 0.5e18);
    }

    function testTransferAllowlist_DifferentRoleId() external {
        boringVault.setBeforeTransferHook(address(teller));

        // Use a fresh role ID that nobody holds yet.
        uint8 CUSTOM_ROLE = 42;
        teller.setTransferAllowedRole(CUSTOM_ROLE);

        address alice = vm.addr(0xA11CE);
        address bob = vm.addr(0xB0B);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Blocked: neither has CUSTOM_ROLE.
        vm.prank(alice);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferNotAllowed.selector);
        boringVault.transfer(bob, 0.5e18);

        // Grant bob CUSTOM_ROLE.
        rolesAuthority.setUserRole(bob, CUSTOM_ROLE, true);

        // Now alice -> bob works (bob has the role).
        vm.prank(alice);
        boringVault.transfer(bob, 0.5e18);
        assertEq(boringVault.balanceOf(bob), 0.5e18);
    }

    function testTransferAllowlist_SwitchBetweenRoleIds() external {
        boringVault.setBeforeTransferHook(address(teller));

        uint8 ROLE_A = 42;
        uint8 ROLE_B = 43;
        address alice = vm.addr(0xA11CE);
        address bob = vm.addr(0xB0B);

        rolesAuthority.setUserRole(bob, ROLE_A, true);

        uint256 depositAmount = 2e18;
        deal(address(WETH), alice, depositAmount);
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Set to ROLE_A: alice -> bob works.
        teller.setTransferAllowedRole(ROLE_A);
        vm.prank(alice);
        boringVault.transfer(bob, 0.5e18);
        assertEq(boringVault.balanceOf(bob), 0.5e18);

        // Switch to ROLE_B: alice -> bob now blocked (bob only has ROLE_A).
        teller.setTransferAllowedRole(ROLE_B);
        vm.prank(alice);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferNotAllowed.selector);
        boringVault.transfer(bob, 0.5e18);
    }

    function testTransferAllowlist_QueueRoundTrip() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address queueAddr = address(atomicQueue);

        uint256 depositAmount = 1e18;
        deal(address(WETH), alice, depositAmount);

        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // alice -> queue (allowed: queue has role)
        vm.prank(alice);
        boringVault.transfer(queueAddr, 1e18);
        assertEq(boringVault.balanceOf(queueAddr), 1e18);
        assertEq(boringVault.balanceOf(alice), 0);

        // queue -> alice (allowed: queue has role)
        vm.prank(queueAddr);
        boringVault.transfer(alice, 1e18);
        assertEq(boringVault.balanceOf(alice), 1e18);
        assertEq(boringVault.balanceOf(queueAddr), 0);
    }

    function testTransferAllowlist_MultipleUsersToQueue() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setTransferAllowedRole(QUEUE_ROLE);

        address alice = vm.addr(0xA11CE);
        address bob = vm.addr(0xB0B);
        address queueAddr = address(atomicQueue);

        uint256 depositAmount = 1e18;

        // Alice deposits
        deal(address(WETH), alice, depositAmount);
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, alice), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Bob deposits
        deal(address(WETH), bob, depositAmount);
        vm.startPrank(bob);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0, bob), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Both can transfer to queue.
        vm.prank(alice);
        boringVault.transfer(queueAddr, 0.5e18);

        vm.prank(bob);
        boringVault.transfer(queueAddr, 0.5e18);

        assertEq(boringVault.balanceOf(queueAddr), 1e18);

        // But alice cannot transfer to bob.
        vm.prank(alice);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferNotAllowed.selector);
        boringVault.transfer(bob, 0.1e18);
    }
}
