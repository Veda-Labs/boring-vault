// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithBuffer, TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithBuffer.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AaveV4BufferHelper} from "src/base/Roles/AaveV4BufferHelper.sol";
import {AaveV4BufferLens} from "src/helper/AaveV4BufferLens.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {IAaveV4Spoke} from "src/interfaces/IAaveV4Spoke.sol";
import {IAaveV4Hub} from "src/interfaces/IAaveV4Hub.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AaveV4BufferHelperTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using stdStorage for StdStorage;

    // Aave V4 protocol errors, declared locally for typed expectReverts.
    error ReserveNotListed();
    error InvalidAmount();

    BoringVault public boringVault;
    TellerWithBuffer public teller;
    AccountantWithRateProviders public accountant;
    RolesAuthority public rolesAuthority;
    AaveV4BufferHelper public bufferHelper;
    AaveV4BufferLens public lens;

    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant TELLER_MANAGER_ROLE = 62;

    // Reserve ids on the Aave V4 Main Spoke; both are validated against the spoke in the helper's
    // constructor.
    uint256 internal constant WETH_RESERVE_ID = 0;
    uint256 internal constant WSTETH_RESERVE_ID = 1;
    // USDT on the Main Spoke: a nonstandard ERC20 (no return value on approve/transfer; approve
    // reverts on a non-zero -> non-zero change). Used to exercise the reset-then-approve path.
    uint256 internal constant USDT_RESERVE_ID = 8;

    ERC20 internal WETH;
    ERC20 internal WSTETH;
    ERC20 internal USDC;

    IAaveV4Spoke internal spoke;
    IAaveV4Hub internal hub;

    address public payout_address = vm.addr(7777777);
    address public referrer = vm.addr(1337);

    function setUp() public {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 25100000;
        vm.createSelectFork(vm.envString(rpcKey), blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        WSTETH = getERC20(sourceChain, "WSTETH");
        USDC = getERC20(sourceChain, "USDC");
        spoke = IAaveV4Spoke(getAddress(sourceChain, "aaveV4MainSpoke"));
        hub = IAaveV4Hub(getAddress(sourceChain, "aaveV4CoreHub"));

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.1e4, 0.9e4, 1, 0, 0
        );

        uint256[] memory reserveIds = new uint256[](2);
        reserveIds[0] = WETH_RESERVE_ID;
        reserveIds[1] = WSTETH_RESERVE_ID;
        bufferHelper = new AaveV4BufferHelper(address(spoke), address(boringVault), reserveIds);

        teller = new TellerWithBuffer(address(this), address(boringVault), address(accountant), address(WETH));

        lens = new AaveV4BufferLens();

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
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

        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), TELLER_MANAGER_ROLE, true);

        teller.updateAssetData(WETH, true, true, 0);

        teller.allowBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
        teller.setWithdrawBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
    }

    // ========================================= HELPER TESTS =========================================

    function testConstructorMapsUnderlyingsFromSpoke() external {
        assertEq(bufferHelper.aaveV4Spoke(), address(spoke), "spoke should be set");
        assertEq(bufferHelper.vault(), address(boringVault), "vault should be set");
        assertEq(bufferHelper.reserveIdFor(address(WETH)), WETH_RESERVE_ID, "WETH should map to reserve id 0");
        assertEq(bufferHelper.reserveIdFor(address(WSTETH)), WSTETH_RESERVE_ID, "wstETH should map to reserve id 1");
    }

    function testConstructorRevertsOnEmptyReserveIds() external {
        vm.expectRevert(AaveV4BufferHelper.AaveV4BufferHelper__NoReserveIds.selector);
        new AaveV4BufferHelper(address(spoke), address(boringVault), new uint256[](0));
    }

    function testConstructorRevertsOnUnlistedReserveId() external {
        uint256[] memory reserveIds = new uint256[](1);
        reserveIds[0] = 999;
        // The spoke reverts when asked for an unlisted reserve, so a bad id cannot be configured.
        vm.expectRevert(ReserveNotListed.selector);
        new AaveV4BufferHelper(address(spoke), address(boringVault), reserveIds);
    }

    function testConstructorRevertsOnDuplicateUnderlying() external {
        // Live precedent: the Bluechip spoke lists USDC and USDT each under two reserve ids on
        // different hubs. Simulate a second reserve id resolving to WETH.
        IAaveV4Spoke.Reserve memory wethReserve = spoke.getReserve(WETH_RESERVE_ID);
        vm.mockCall(
            address(spoke),
            abi.encodeWithSelector(IAaveV4Spoke.getReserve.selector, uint256(999)),
            abi.encode(wethReserve)
        );

        uint256[] memory reserveIds = new uint256[](2);
        reserveIds[0] = WETH_RESERVE_ID;
        reserveIds[1] = 999;
        vm.expectRevert(
            abi.encodeWithSelector(AaveV4BufferHelper.AaveV4BufferHelper__DuplicateUnderlying.selector, address(WETH))
        );
        new AaveV4BufferHelper(address(spoke), address(boringVault), reserveIds);
        vm.clearMockedCalls();
    }

    function testConstructorRevertsOnZeroAddresses() external {
        uint256[] memory reserveIds = new uint256[](1);
        reserveIds[0] = WETH_RESERVE_ID;

        vm.expectRevert(AaveV4BufferHelper.AaveV4BufferHelper__ZeroAddress.selector);
        new AaveV4BufferHelper(address(0), address(boringVault), reserveIds);

        vm.expectRevert(AaveV4BufferHelper.AaveV4BufferHelper__ZeroAddress.selector);
        new AaveV4BufferHelper(address(spoke), address(0), reserveIds);
    }

    function testRevertsForUnconfiguredAsset() external {
        vm.expectRevert(
            abi.encodeWithSelector(AaveV4BufferHelper.AaveV4BufferHelper__AssetNotConfigured.selector, address(USDC))
        );
        bufferHelper.getDepositManageCall(address(USDC), 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(AaveV4BufferHelper.AaveV4BufferHelper__AssetNotConfigured.selector, address(USDC))
        );
        bufferHelper.getWithdrawManageCall(address(USDC), 1e6);
    }

    function testUserDeposit(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 500e18);

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        teller.deposit(WETH, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(WETH_RESERVE_ID, address(boringVault)),
            amount,
            2,
            "Should have put entire deposit into Aave V4"
        );
        assertEq(WETH.balanceOf(address(boringVault)), 0, "Vault should hold no idle WETH");
    }

    function testUserDepositWithSufficientOpenApproval(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 500e18);

        // Ample pre-existing approval: the fixed reset-then-approve path still resets it to 0 and
        // re-approves, so the deposit succeeds via the teller regardless of the prior allowance.
        vm.prank(address(boringVault));
        WETH.safeApprove(address(spoke), type(uint256).max);

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        teller.deposit(WETH, amount, 0, referrer);

        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(WETH_RESERVE_ID, address(boringVault)),
            amount,
            2,
            "Should have put entire deposit into Aave V4"
        );
    }

    function testUserDepositWithInsufficientOpenApproval(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 500e18);

        // Stale partial pre-existing approval: the fixed path resets it to 0 before re-approving, so
        // the deposit succeeds via the teller (and would be USDT-safe in this state).
        vm.prank(address(boringVault));
        WETH.safeApprove(address(spoke), 1);

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        teller.deposit(WETH, amount, 0, referrer);

        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(WETH_RESERVE_ID, address(boringVault)),
            amount,
            2,
            "Should have put entire deposit into Aave V4"
        );
    }

    function testWithdraw(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 500e18);

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        // Withdraw all but dust shares to absorb supply-side share rounding.
        teller.withdraw(WETH, amount - 2, 0, address(this));

        assertApproxEqAbs(WETH.balanceOf(address(this)), amount - 2, 2, "Should have received expected WETH");
        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(WETH_RESERVE_ID, address(boringVault)),
            0,
            3,
            "Should have removed entire deposit from Aave V4"
        );
    }

    function testBufferHelperUsdtDepositIsSinglePathForAnyAllowance() external {
        // The deposit call is a fixed approve(0) + approve(amount) + supply sequence regardless of the
        // vault's current spoke allowance, so it is USDT-safe (no-return approve; never a non-zero ->
        // non-zero change) whether the prior allowance is zero, a stale partial, or ample. Drive each
        // case end to end against the live spoke, then withdraw the accumulated position back.
        ERC20 usdt = getERC20(sourceChain, "USDT");
        uint256[] memory reserveIds = new uint256[](1);
        reserveIds[0] = USDT_RESERVE_ID;
        AaveV4BufferHelper usdtHelper = new AaveV4BufferHelper(address(spoke), address(boringVault), reserveIds);
        assertEq(usdtHelper.reserveIdFor(address(usdt)), USDT_RESERVE_ID, "USDT should map to reserve id 8");
        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);

        uint256 amount = 25_000e6;
        // supply consumes the approval, so the vault->spoke allowance is 0 at the start of every iteration.
        uint256[3] memory startingAllowances = [uint256(0), uint256(1), type(uint256).max];

        for (uint256 i; i < startingAllowances.length; ++i) {
            if (startingAllowances[i] != 0) {
                vm.prank(address(boringVault));
                usdt.safeApprove(address(spoke), startingAllowances[i]);
            }
            deal(address(usdt), address(boringVault), amount);

            (address[] memory targets, bytes[] memory data, uint256[] memory values) =
                usdtHelper.getDepositManageCall(address(usdt), amount);

            // Single fixed path: approve(spoke, 0) -> approve(spoke, amount) -> supply, in all cases.
            assertEq(targets.length, 3, "deposit must always be approve(0)+approve+supply");
            assertEq(targets[0], address(usdt), "call 0 resets the token approval");
            assertEq(targets[1], address(usdt), "call 1 sets the token approval");
            assertEq(targets[2], address(spoke), "call 2 supplies to the spoke");

            uint256 suppliedBefore = spoke.getUserSuppliedAssets(USDT_RESERVE_ID, address(boringVault));
            boringVault.manage(targets, data, values);
            assertApproxEqAbs(
                spoke.getUserSuppliedAssets(USDT_RESERVE_ID, address(boringVault)),
                suppliedBefore + amount,
                2,
                "deposit supplies USDT regardless of prior allowance"
            );
            assertEq(
                usdt.allowance(address(boringVault), address(spoke)),
                0,
                "supply consumes the approval, leaving none for the next deposit"
            );
        }

        // Withdraw the accumulated position back to the vault through the spoke.
        uint256 supplied = spoke.getUserSuppliedAssets(USDT_RESERVE_ID, address(boringVault));
        (address[] memory wTargets, bytes[] memory wData, uint256[] memory wValues) =
            usdtHelper.getWithdrawManageCall(address(usdt), supplied - 2);
        boringVault.manage(wTargets, wData, wValues);
        assertApproxEqAbs(usdt.balanceOf(address(boringVault)), supplied - 2, 3, "USDT withdrawn back to the vault");
    }

    function testUsdtThroughFullTellerFlow() external {
        // Full teller deposit + withdraw of USDT routed through the Aave V4 buffer. A USDT-base
        // accountant keeps deposits 1:1 with no cross-asset rate provider, isolating USDT's nonstandard
        // approve/transfer behaviour across the entire teller -> vault -> spoke path.
        ERC20 usdt = getERC20(sourceChain, "USDT");

        AccountantWithRateProviders usdtAccountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e6, address(usdt), 1.1e4, 0.9e4, 1, 0, 0
        );
        uint256[] memory reserveIds = new uint256[](1);
        reserveIds[0] = USDT_RESERVE_ID;
        AaveV4BufferHelper usdtHelper = new AaveV4BufferHelper(address(spoke), address(boringVault), reserveIds);
        TellerWithBuffer usdtTeller =
            new TellerWithBuffer(address(this), address(boringVault), address(usdtAccountant), address(WETH));

        usdtAccountant.setAuthority(rolesAuthority);
        usdtTeller.setAuthority(rolesAuthority);

        // Authorize the USDT teller on the vault and expose its deposit/withdraw.
        rolesAuthority.setUserRole(address(usdtTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(usdtTeller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(usdtTeller), TELLER_MANAGER_ROLE, true);
        rolesAuthority.setPublicCapability(
            address(usdtTeller), bytes4(keccak256("deposit(address,uint256,uint256,address)")), true
        );
        rolesAuthority.setPublicCapability(address(usdtTeller), TellerWithMultiAssetSupport.withdraw.selector, true);

        usdtTeller.updateAssetData(usdt, true, true, 0);
        usdtTeller.allowBufferHelper(usdt, IBufferHelper(address(usdtHelper)));
        usdtTeller.setDepositBufferHelper(usdt, IBufferHelper(address(usdtHelper)));
        usdtTeller.setWithdrawBufferHelper(usdt, IBufferHelper(address(usdtHelper)));

        uint256 amount = 100_000e6;
        deal(address(usdt), address(this), amount);
        usdt.safeApprove(address(boringVault), amount);

        uint256 shares = usdtTeller.deposit(usdt, amount, 0, referrer);
        assertGt(shares, 0, "deposit should mint shares");
        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(USDT_RESERVE_ID, address(boringVault)),
            amount,
            2,
            "teller deposit should route USDT into Aave V4"
        );
        assertEq(usdt.balanceOf(address(boringVault)), 0, "no idle USDT left in the vault");

        // Withdraw nearly all shares; leave a 2-unit margin to absorb supply-side rounding, since the
        // vault holds no idle USDT to top up a clamp (mirrors testWithdraw).
        uint256 sharesToWithdraw = shares * (amount - 2) / amount;
        usdtTeller.withdraw(usdt, sharesToWithdraw, 0, address(this));
        assertApproxEqAbs(
            usdt.balanceOf(address(this)), amount, 4, "teller withdraw should return ~all USDT from Aave V4"
        );
    }

    // ========================================= LENS TESTS =========================================

    function testLensReturnsIdleAssetsWhenNoWithdrawHelper() external {
        teller.setWithdrawBufferHelper(WETH, IBufferHelper(address(0)));

        deal(address(WETH), address(boringVault), 123e18);

        assertEq(_withdrawable(), 123e18, "Lens should report idle vault balance");
    }

    function testLensReportsSuppliedPosition(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 500e18);

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        uint256 suppliedAssets = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, address(boringVault));
        assertEq(_withdrawable(), suppliedAssets, "Lens should report the full supplied position");
        assertApproxEqAbs(_withdrawable(), amount, 2, "Lens should approximately equal the deposit");
    }

    function testLensCapsAtHubLiquidity() external {
        uint256 amount = 100e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        // With ample real liquidity the lens reports the full supplied position. The hub is keyed
        // by assetId, not the spoke's reserveId (they only coincide for WETH on the Main Spoke).
        uint256 wethAssetId = spoke.getReserve(WETH_RESERVE_ID).assetId;
        uint256 suppliedAssets = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, address(boringVault));
        assertGt(hub.getAssetLiquidity(wethAssetId), suppliedAssets, "Real liquidity should exceed the position");
        assertEq(_withdrawable(), suppliedAssets, "Lens should report the full position when liquidity is ample");

        // Simulate the hub running low on liquidity (most of it lent out): the lens must cap the
        // withdrawable amount at the hub's available liquidity, since Hub.remove reverts above it.
        vm.mockCall(
            address(hub),
            abi.encodeWithSelector(IAaveV4Hub.getAssetLiquidity.selector, wethAssetId),
            abi.encode(uint256(40e18))
        );
        assertEq(_withdrawable(), 40e18, "Lens should be capped at hub liquidity");
        vm.clearMockedCalls();

        // And a real withdrawal within the actual ample liquidity still succeeds end to end.
        teller.withdraw(WETH, 60e18, 0, address(this));
        assertApproxEqAbs(WETH.balanceOf(address(this)), 60e18, 2, "Should have received withdrawn WETH");
    }

    function testLensReturnsZeroWhenReservePaused() external {
        uint256 amount = 100e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        // A paused reserve (flag bit 0x01) blocks withdrawals on the spoke regardless of liquidity.
        IAaveV4Spoke.Reserve memory reserve = spoke.getReserve(WETH_RESERVE_ID);
        reserve.flags |= 0x01;
        vm.mockCall(
            address(spoke),
            abi.encodeWithSelector(IAaveV4Spoke.getReserve.selector, WETH_RESERVE_ID),
            abi.encode(reserve)
        );

        assertEq(_withdrawable(), 0, "Lens should report zero for a paused reserve");
        vm.clearMockedCalls();
    }

    function testLensIncludesIdleAssetsWhenLiquidityCoversPosition() external {
        // Supplied position via the deposit helper...
        deal(address(WETH), address(this), 125e18);
        WETH.safeApprove(address(boringVault), 125e18);
        teller.deposit(WETH, 100e18, 0, referrer);

        // ...then idle deposits after the deposit helper is unset (e.g. during an incident).
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(0)));
        teller.deposit(WETH, 25e18, 0, referrer);

        uint256 suppliedAssets = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, address(boringVault));
        assertEq(
            _withdrawable(),
            suppliedAssets + 25e18,
            "Lens should count idle balance on top of the position when liquidity covers it"
        );

        // Spoke.withdraw clamps to the position and the vault tops up from idle, so the full
        // quoted amount is genuinely withdrawable in one teller call.
        teller.withdraw(WETH, 125e18 - 2, 0, address(this));
        assertApproxEqAbs(WETH.balanceOf(address(this)), 125e18 - 2, 2, "Should have received position plus idle");
    }

    function testLensReturnsZeroWithoutSpokePosition() external {
        // With the withdraw helper set but nothing supplied, every teller withdrawal reverts in
        // the hub on the zero-amount remove, so idle balance is not instantly withdrawable.
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(0)));
        deal(address(WETH), address(this), 50e18);
        WETH.safeApprove(address(boringVault), 50e18);
        teller.deposit(WETH, 50e18, 0, referrer);

        assertEq(WETH.balanceOf(address(boringVault)), 50e18, "Deposit should sit idle in the vault");
        assertEq(_withdrawable(), 0, "Lens should report zero without a spoke position");

        vm.expectRevert(InvalidAmount.selector);
        teller.withdraw(WETH, 10e18, 0, address(this));
    }

    function testLensReturnsZeroWhenSpokeInactiveOrHalted() external {
        uint256 amount = 100e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        IAaveV4Spoke.Reserve memory reserve = spoke.getReserve(WETH_RESERVE_ID);
        IAaveV4Hub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(reserve.assetId, address(spoke));

        // An inactive spoke blocks Hub.remove regardless of liquidity.
        spokeConfig.active = false;
        vm.mockCall(
            address(hub),
            abi.encodeWithSelector(IAaveV4Hub.getSpokeConfig.selector, uint256(reserve.assetId), address(spoke)),
            abi.encode(spokeConfig)
        );
        assertEq(_withdrawable(), 0, "Lens should report zero for an inactive spoke");

        // So does a halted spoke.
        spokeConfig.active = true;
        spokeConfig.halted = true;
        vm.mockCall(
            address(hub),
            abi.encodeWithSelector(IAaveV4Hub.getSpokeConfig.selector, uint256(reserve.assetId), address(spoke)),
            abi.encode(spokeConfig)
        );
        assertEq(_withdrawable(), 0, "Lens should report zero for a halted spoke");
        vm.clearMockedCalls();
    }

    function testLensQuotesNormallyForFrozenReserve() external {
        uint256 amount = 100e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        // Frozen (0x02) blocks supplies but not withdrawals, so the quote must be unaffected.
        IAaveV4Spoke.Reserve memory reserve = spoke.getReserve(WETH_RESERVE_ID);
        reserve.flags |= 0x02;
        vm.mockCall(
            address(spoke),
            abi.encodeWithSelector(IAaveV4Spoke.getReserve.selector, WETH_RESERVE_ID),
            abi.encode(reserve)
        );

        uint256 suppliedAssets = spoke.getUserSuppliedAssets(WETH_RESERVE_ID, address(boringVault));
        assertEq(_withdrawable(), suppliedAssets, "Frozen reserve should not affect the withdraw quote");
        vm.clearMockedCalls();
    }

    function testLensRevertsOnReserveAssetMismatch() external {
        // If a spoke upgrade ever remapped a reserve's underlying, the lens fails loudly rather
        // than quoting against the wrong asset.
        IAaveV4Spoke.Reserve memory reserve = spoke.getReserve(WETH_RESERVE_ID);
        reserve.underlying = address(WSTETH);
        vm.mockCall(
            address(spoke),
            abi.encodeWithSelector(IAaveV4Spoke.getReserve.selector, WETH_RESERVE_ID),
            abi.encode(reserve)
        );

        vm.expectRevert("AaveV4BufferLens: reserve asset mismatch");
        lens.getInstantlyWithdrawableAmount(teller, WETH);
        vm.clearMockedCalls();
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _withdrawable() internal view returns (uint256) {
        return lens.getInstantlyWithdrawableAmount(teller, WETH);
    }
}
