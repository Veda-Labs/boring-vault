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
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {MorphoMarketBufferHelper} from "src/base/Roles/MorphoMarketBufferHelper.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

interface IMorphoLite {
    struct Position {
        uint256 supplyShares;
        uint128 borrowShares;
        uint128 collateral;
    }

    function position(bytes32 id, address user) external view returns (Position memory);

    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );
}

/**
 * @notice A minimal twin of {MorphoMarketBufferHelper} that does NOT enforce zero-address
 *         guards on its constructor. Used by the zero-address effect tests to demonstrate
 *         what would silently happen if the real helper were missing those guards.
 */
contract UnsafeMorphoMarketBufferHelper {
    address public immutable MORPHO_BLUE;
    address public immutable VAULT;
    address public immutable LOAN_TOKEN;
    address public immutable COLLATERAL_TOKEN;
    address public immutable ORACLE;
    address public immutable IRM;
    uint256 public immutable LLTV;

    constructor(
        address morphoBlue,
        address vault,
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    ) {
        MORPHO_BLUE = morphoBlue;
        VAULT = vault;
        LOAN_TOKEN = loanToken;
        COLLATERAL_TOKEN = collateralToken;
        ORACLE = oracle;
        IRM = irm;
        LLTV = lltv;
    }

    function marketParams() public view returns (DecoderCustomTypes.MarketParams memory) {
        return DecoderCustomTypes.MarketParams({
            loanToken: LOAN_TOKEN,
            collateralToken: COLLATERAL_TOKEN,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });
    }

    function getDepositManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        targets = new address[](3);
        targets[0] = asset;
        targets[1] = asset;
        targets[2] = MORPHO_BLUE;
        data = new bytes[](3);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", MORPHO_BLUE, 0);
        data[1] = abi.encodeWithSignature("approve(address,uint256)", MORPHO_BLUE, amount);
        data[2] = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            marketParams(),
            amount,
            uint256(0),
            VAULT,
            bytes("")
        );
        values = new uint256[](3);
    }

    function getWithdrawManageCall(address, /* asset */ uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        targets = new address[](1);
        targets[0] = MORPHO_BLUE;
        data = new bytes[](1);
        data[0] = abi.encodeWithSignature(
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            marketParams(),
            amount,
            uint256(0),
            VAULT,
            VAULT
        );
        values = new uint256[](1);
    }
}

/**
 * @title MorphoMarketBufferHelperTest
 * @notice Integration tests for the MorphoMarketBufferHelper using the weETH/WETH 86% LLTV market on mainnet.
 *         The market loan token is WETH; the helper supplies / withdraws WETH on behalf of the BoringVault.
 */
contract MorphoMarketBufferHelperTest is Test, MerkleTreeHelper {
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

    ERC20 internal WETH;
    address internal MORPHO_BLUE;

    // weETH/WETH 86% LLTV market parameters (mainnet)
    address internal constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant WEETH_ORACLE = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address internal constant WEETH_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 internal constant WEETH_LLTV = 0.86e18;
    bytes32 internal MARKET_ID;

    address public referrer = vm.addr(1337);

    MorphoMarketBufferHelper public bufferHelper;

    function setUp() public {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        // Block at which the weETH/WETH 86 market exists (same block used by MorphoBlueIntegration tests).
        uint256 blockNumber = 19826676;
        vm.createSelectFork(vm.envString(rpcKey), blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        MORPHO_BLUE = getAddress(sourceChain, "morphoBlue");
        MARKET_ID = getBytes32(sourceChain, "weETH_wETH_86_market");

        bytes32 salt = keccak256("morpho-market-buffer-test");
        boringVault = new BoringVault{salt: salt}(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.1e4, 0.9e4, 1, 0, 0
        );

        bufferHelper = new MorphoMarketBufferHelper(
            MORPHO_BLUE, address(boringVault), address(WETH), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );

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

        teller.updateAssetData(WETH, true, true, 0);
        accountant.setRateProviderData(WETH, true, address(0));

        teller.allowBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
        teller.setWithdrawBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
    }

    // ============================= IMMUTABLES =============================

    function testImmutables() external {
        assertEq(bufferHelper.MORPHO_BLUE(), MORPHO_BLUE, "MORPHO_BLUE");
        assertEq(bufferHelper.VAULT(), address(boringVault), "VAULT");
        assertEq(bufferHelper.LOAN_TOKEN(), address(WETH), "LOAN_TOKEN");
        assertEq(bufferHelper.COLLATERAL_TOKEN(), WEETH, "COLLATERAL_TOKEN");
        assertEq(bufferHelper.ORACLE(), WEETH_ORACLE, "ORACLE");
        assertEq(bufferHelper.IRM(), WEETH_IRM, "IRM");
        assertEq(bufferHelper.LLTV(), WEETH_LLTV, "LLTV");

        DecoderCustomTypes.MarketParams memory mp = bufferHelper.marketParams();
        assertEq(mp.loanToken, address(WETH), "marketParams.loanToken");
        assertEq(mp.collateralToken, WEETH, "marketParams.collateralToken");
        assertEq(mp.oracle, WEETH_ORACLE, "marketParams.oracle");
        assertEq(mp.irm, WEETH_IRM, "marketParams.irm");
        assertEq(mp.lltv, WEETH_LLTV, "marketParams.lltv");
    }

    // ============================= DEPOSIT TESTS =============================

    function testUserDeposit() external {
        uint256 amount = 1e18;

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        uint96 currentNonce = teller.depositNonce();
        teller.deposit(WETH, amount, 0, referrer);

        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");
        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");

        // All WETH should now be supplied to Morpho.
        assertEq(WETH.balanceOf(address(boringVault)), 0, "No WETH should remain in the vault");
        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Supply shares should be > 0");
    }

    function testBulkDeposit() external {
        uint256 amount = 1e18;

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        teller.bulkDeposit(WETH, amount, 0, address(this));

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
        assertEq(WETH.balanceOf(address(boringVault)), 0, "No WETH should remain in the vault");

        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Supply shares should be > 0");
    }

    function testDepositWithSufficientOpenApproval() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);

        // Pre-approve Morpho Blue from boring vault with sufficient allowance.
        address[] memory targets = new address[](1);
        targets[0] = address(WETH);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(WETH.approve.selector, MORPHO_BLUE, amount);
        uint256[] memory values = new uint256[](1);

        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);
        boringVault.manage(targets, data, values);

        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
        assertEq(WETH.balanceOf(address(boringVault)), 0, "No WETH should remain in the vault");
        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Supply shares should be > 0");
    }

    // ============================= WITHDRAW TESTS =============================

    function testWithdraw() external {
        uint256 amount = 1e18;

        // Deposit first.
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        IMorphoLite.Position memory posBefore = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(posBefore.supplyShares, 0, "Supply shares should be > 0 after deposit");

        // Withdraw slightly less than the supplied amount to avoid hitting share-rounding edge.
        uint256 withdrawAmount = amount - 1;
        teller.withdraw(WETH, withdrawAmount, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 2, "Should have ~0 remaining shares");
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount, 2, "Should have received WETH back");
    }

    function testBulkWithdraw() external {
        uint256 amount = 1e18;

        // Deposit first.
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.bulkDeposit(WETH, amount, 0, address(this));

        uint256 withdrawAmount = amount - 1;
        teller.bulkWithdraw(WETH, withdrawAmount, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 2, "Should have ~0 remaining shares");
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount, 2, "Should have received WETH back");
    }

    // ============================= DEPOSIT + WITHDRAW COMBO TESTS =============================

    function testMultipleDepositWithdraws() external {
        uint256 amount = 1e18;

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        // Deposit 1/10.
        teller.deposit(WETH, amount / 10, 0, referrer);
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 10, 2, "Shares after first deposit");

        // Deposit another 1/10 via bulkDeposit.
        teller.bulkDeposit(WETH, amount / 10, 0, address(this));
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 5, 4, "Shares after second deposit");

        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Should have supply shares");

        // bulkWithdraw half the shares.
        uint256 sharesBefore = boringVault.balanceOf(address(this));
        teller.bulkWithdraw(WETH, sharesBefore / 2, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), sharesBefore / 2, 4, "Should have half the shares left");
        assertGt(WETH.balanceOf(address(this)), 0, "Should have received WETH");

        // Withdraw rest via regular withdraw.
        uint256 remainingShares = boringVault.balanceOf(address(this));
        teller.withdraw(WETH, remainingShares - 1, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 4, "Should have ~0 shares left");
    }

    // ============================= BUFFER HELPER MANAGEMENT TESTS =============================

    function testBufferHelperZeroAddress() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        // Disable buffer helpers.
        teller.setWithdrawBufferHelper(WETH, IBufferHelper(address(0)));
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(0)));

        teller.deposit(WETH, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Shares should match deposit");
        assertEq(WETH.balanceOf(address(boringVault)), amount, "WETH should stay in vault (no buffer helper)");

        teller.withdraw(WETH, amount / 2, 0, address(this));
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount / 2, 4, "Should have received WETH");
        assertApproxEqAbs(WETH.balanceOf(address(boringVault)), amount / 2, 4, "Half WETH should remain in vault");
    }

    function testBufferHelperChange() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        // Create a new buffer helper (same config, different instance).
        MorphoMarketBufferHelper newHelper = new MorphoMarketBufferHelper(
            MORPHO_BLUE, address(boringVault), address(WETH), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );

        teller.allowBufferHelper(WETH, IBufferHelper(address(newHelper)));
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(newHelper)));
        teller.setWithdrawBufferHelper(WETH, IBufferHelper(address(newHelper)));

        teller.deposit(WETH, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Shares should match deposit");
        assertEq(WETH.balanceOf(address(boringVault)), 0, "No WETH should remain in vault");
        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Supply shares should be > 0");

        teller.withdraw(WETH, amount / 2, 0, address(this));
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount / 2, 4, "Should have received WETH");
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 2, 4, "Half of shares should remain");
    }

    function testShareLock() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);

        teller.setShareLockPeriod(10);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        // Should revert because shares are locked.
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector);
        teller.withdraw(WETH, amount / 10, 0, address(this));

        // bulkWithdraw should bypass share lock.
        teller.bulkWithdraw(WETH, amount / 10, 0, address(this));
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount / 10, 4, "Should have received WETH via bulkWithdraw");

        // Skip to end of share lock period; regular withdraw should work.
        vm.warp(block.timestamp + 10);
        teller.withdraw(WETH, amount / 5, 0, address(this));
        assertApproxEqAbs(
            WETH.balanceOf(address(this)), amount / 5 + amount / 10, 8, "Should have received WETH after lock expires"
        );
    }

    // ============================= ASSET MISMATCH SAFETY CHECK =============================

    /**
     * @notice Verifies that getDepositManageCall reverts when invoked with an asset that is
     *         not the configured LOAN_TOKEN, guarding against misconfigured teller registrations.
     */
    function testGetDepositManageCallRevertsOnAssetMismatch() external {
        address wrongAsset = WEETH; // collateral token of the market – not the loan token
        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoMarketBufferHelper.MorphoMarketBufferHelper__AssetMismatch.selector, wrongAsset, address(WETH)
            )
        );
        bufferHelper.getDepositManageCall(wrongAsset, 1e18);
    }

    /**
     * @notice Verifies that getWithdrawManageCall reverts when invoked with an asset that is
     *         not the configured LOAN_TOKEN, preventing a misconfigured registration from
     *         silently withdrawing the wrong token.
     */
    function testGetWithdrawManageCallRevertsOnAssetMismatch() external {
        address wrongAsset = WEETH;
        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoMarketBufferHelper.MorphoMarketBufferHelper__AssetMismatch.selector, wrongAsset, address(WETH)
            )
        );
        bufferHelper.getWithdrawManageCall(wrongAsset, 1e18);
    }

    /**
     * @notice End-to-end: if the teller is wired to route a non-loan asset through this
     *         helper, the deposit reverts with the asset-mismatch error rather than
     *         silently approving / supplying the wrong token.
     * @dev Uses WEETH as the registered asset on the teller, but the helper is locked to
     *      WETH as its LOAN_TOKEN.
     */
    function testTellerDepositRevertsWhenHelperRegisteredForWrongAsset() external {
        ERC20 weeth = ERC20(WEETH);
        // Register WEETH as a depositable asset and bind this helper (which expects WETH) to it.
        teller.updateAssetData(weeth, true, true, 0);
        accountant.setRateProviderData(weeth, true, address(0));
        teller.allowBufferHelper(weeth, IBufferHelper(address(bufferHelper)));
        teller.setDepositBufferHelper(weeth, IBufferHelper(address(bufferHelper)));

        uint256 amount = 1e18;
        deal(WEETH, address(this), amount);
        weeth.safeApprove(address(boringVault), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoMarketBufferHelper.MorphoMarketBufferHelper__AssetMismatch.selector, WEETH, address(WETH)
            )
        );
        teller.deposit(weeth, amount, 0, referrer);
    }

    // ============================= ENCODING TESTS =============================

    /**
     * @notice Verifies that getDepositManageCall returns the canonical 3-call sequence
     *         (approve(0), approve(amount), supply) regardless of pre-existing allowance.
     */
    function testGetDepositManageCallEncoding() external {
        uint256 depositAmount = 1e18;
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getDepositManageCall(address(WETH), depositAmount);

        assertEq(targets.length, 3, "should return exactly 3 targets");
        assertEq(targets[0], address(WETH), "first target must be WETH (reset allowance)");
        assertEq(targets[1], address(WETH), "second target must be WETH (re-approve)");
        assertEq(targets[2], MORPHO_BLUE, "third target must be Morpho Blue");
        assertEq(
            data[0],
            abi.encodeWithSignature("approve(address,uint256)", MORPHO_BLUE, 0),
            "first call must reset allowance to 0"
        );
        assertEq(
            data[1],
            abi.encodeWithSignature("approve(address,uint256)", MORPHO_BLUE, depositAmount),
            "second call must approve the full deposit amount"
        );

        DecoderCustomTypes.MarketParams memory mp = bufferHelper.marketParams();
        bytes memory expectedSupply = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            mp,
            depositAmount,
            uint256(0),
            address(boringVault),
            bytes("")
        );
        assertEq(data[2], expectedSupply, "third call must be Morpho supply with assets-form");

        assertEq(values[0], 0, "first ETH value must be 0");
        assertEq(values[1], 0, "second ETH value must be 0");
        assertEq(values[2], 0, "third ETH value must be 0");
    }

    /**
     * @notice Verifies that getWithdrawManageCall returns a single withdraw call.
     *         The asset parameter is intentionally unused — the Morpho Blue singleton is always the target.
     */
    function testGetWithdrawManageCallEncoding() external {
        uint256 withdrawAmount = 1e18;
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getWithdrawManageCall(address(WETH), withdrawAmount);

        assertEq(targets.length, 1, "Withdraw: should return exactly 1 target");
        assertEq(targets[0], MORPHO_BLUE, "Withdraw: target must be Morpho Blue");

        DecoderCustomTypes.MarketParams memory mp = bufferHelper.marketParams();
        bytes memory expectedWithdraw = abi.encodeWithSignature(
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            mp,
            withdrawAmount,
            uint256(0),
            address(boringVault),
            address(boringVault)
        );
        assertEq(data[0], expectedWithdraw, "Withdraw: call must be Morpho withdraw with assets-form");
        assertEq(values[0], 0, "Withdraw: ETH value must be 0");
    }

    // ============================= ZERO-ADDRESS CONSTRUCTOR GUARDS =============================

    /// @notice The production helper must reject a zero Morpho Blue singleton at construction.
    function testConstructorRevertsOnZeroMorphoBlue() external {
        vm.expectRevert(MorphoMarketBufferHelper.MorphoMarketBufferHelper__ZeroAddress.selector);
        new MorphoMarketBufferHelper(
            address(0), address(boringVault), address(WETH), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );
    }

    /// @notice The production helper must reject a zero boring vault at construction.
    function testConstructorRevertsOnZeroVault() external {
        vm.expectRevert(MorphoMarketBufferHelper.MorphoMarketBufferHelper__ZeroAddress.selector);
        new MorphoMarketBufferHelper(
            MORPHO_BLUE, address(0), address(WETH), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );
    }

    /// @notice The production helper must reject a zero loan token at construction.
    function testConstructorRevertsOnZeroLoanToken() external {
        vm.expectRevert(MorphoMarketBufferHelper.MorphoMarketBufferHelper__ZeroAddress.selector);
        new MorphoMarketBufferHelper(
            MORPHO_BLUE, address(boringVault), address(0), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );
    }

    /**
     * @notice Demonstrates the catastrophic effect a zero Morpho Blue singleton would have had
     *         without the constructor guard:
     *           - the third target of `getDepositManageCall` (the supply call) is `address(0)`,
     *             so the BoringVault.manage() loop would `call(address(0), supplyCalldata)`.
     *             That call succeeds silently (no code at 0x0, no revert), the approved tokens
     *             remain in the vault, no supply position is created, and the asset would be
     *             stuck approved to address(0).
     *           - the withdraw call would likewise be a no-op call into address(0) and no
     *             tokens would ever come back.
     */
    function testZeroMorphoBlueWouldSilentlyMisrouteAllCalls() external {
        UnsafeMorphoMarketBufferHelper unsafe = new UnsafeMorphoMarketBufferHelper(
            address(0), address(boringVault), address(WETH), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );

        // ---- Deposit side ----
        (address[] memory dTargets, bytes[] memory dData,) = unsafe.getDepositManageCall(address(WETH), 1e18);
        assertEq(dTargets[2], address(0), "supply target would be address(0)");
        // The approval bytes literally approve address(0) as spender, which is harmless on its own
        // but means the manager has just "approved" a non-contract to spend vault funds.
        assertEq(
            dData[0],
            abi.encodeWithSignature("approve(address,uint256)", address(0), 0),
            "reset approval would target address(0)"
        );
        assertEq(
            dData[1],
            abi.encodeWithSignature("approve(address,uint256)", address(0), 1e18),
            "approval would be granted to address(0)"
        );

        // Show that executing the supply call against address(0) returns success with no effect
        // (an EOA-style call with no code). This is exactly the silent-misroute the audit warns about.
        (bool ok, bytes memory ret) = address(0).call(dData[2]);
        assertTrue(ok, "call to address(0) silently succeeds");
        assertEq(ret.length, 0, "call returns empty data, no revert");

        // ---- Withdraw side ----
        (address[] memory wTargets, bytes[] memory wData,) = unsafe.getWithdrawManageCall(address(WETH), 1e18);
        assertEq(wTargets[0], address(0), "withdraw target would be address(0)");
        (ok, ret) = address(0).call(wData[0]);
        assertTrue(ok, "withdraw to address(0) silently succeeds");
        assertEq(ret.length, 0, "withdraw returns empty data, no revert");
    }

    /**
     * @notice Demonstrates the catastrophic effect a zero VAULT immutable would have had
     *         without the constructor guard.
     *
     *         The encoded supply call sets `onBehalf = address(0)`, and Morpho Blue itself
     *         rejects that with its own `ZERO_ADDRESS` check. Withdraw likewise reverts
     *         (`receiver = address(0)`).
     *
     *         Because all parameters are immutable, this means:
     *           - Every deposit through TellerWithBuffer would revert at the manage() step.
     *           - Every withdraw would revert in the same way.
     *           - The helper is permanently bricked and cannot be upgraded in place.
     *           - Any approval already granted to Morpho Blue is dead weight; no supply
     *             position can ever be opened.
     *         This is the unrecoverable foot-gun the audit warns about: the constructor
     *         guard is the only line of defense, because there is no setter to fix VAULT.
     */
    function testZeroVaultWouldBrickEveryDepositAndWithdraw() external {
        UnsafeMorphoMarketBufferHelper unsafe = new UnsafeMorphoMarketBufferHelper(
            MORPHO_BLUE, address(0), address(WETH), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );

        (, bytes[] memory dData,) = unsafe.getDepositManageCall(address(WETH), 1e18);
        DecoderCustomTypes.MarketParams memory mp = unsafe.marketParams();

        // The supply call is encoded with onBehalf = address(0).
        bytes memory expectedSupply = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            mp,
            uint256(1e18),
            uint256(0),
            address(0), // <-- onBehalf is the zero VAULT
            bytes("")
        );
        assertEq(dData[2], expectedSupply, "supply call would be onBehalf = address(0)");

        // Withdraw is encoded with onBehalf = receiver = address(0).
        (, bytes[] memory wData,) = unsafe.getWithdrawManageCall(address(WETH), 1e18);
        bytes memory expectedWithdraw = abi.encodeWithSignature(
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            mp,
            uint256(1e18),
            uint256(0),
            address(0),
            address(0)
        );
        assertEq(wData[0], expectedWithdraw, "withdraw onBehalf and receiver would be address(0)");

        // Fund a sender and prove that Morpho Blue itself reverts both calls, permanently.
        deal(address(WETH), address(this), 1e18);
        WETH.safeApprove(MORPHO_BLUE, 1e18);

        (bool supplyOk,) = MORPHO_BLUE.call(dData[2]);
        assertFalse(supplyOk, "supply with onBehalf=0 must revert at Morpho Blue");

        (bool withdrawOk,) = MORPHO_BLUE.call(wData[0]);
        assertFalse(withdrawOk, "withdraw with receiver=0 must revert at Morpho Blue");

        // Confirm no supply position exists for either address — nothing happened on-chain,
        // but the helper is now dead weight: every future TellerWithBuffer call routed through
        // it will revert in exactly the same way, and there is no setter to fix VAULT.
        IMorphoLite.Position memory zeroPos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(0));
        IMorphoLite.Position memory vaultPos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertEq(zeroPos.supplyShares, 0, "no shares were credited to address(0)");
        assertEq(vaultPos.supplyShares, 0, "no shares were credited to the vault");
    }
}
