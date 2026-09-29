// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DirectPropAMMDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DirectPropAMMDecoderAndSanitizer.sol";
import {TempoDirectPropAMMDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TempoDirectPropAMMDecoderAndSanitizer.sol";
import {IDirectPropAMM} from "src/interfaces/IDirectPropAMM.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @notice Admin, quote, and inspection surface of the real DirectPropAMM, beyond the taker calls in
///         `IDirectPropAMM`. Matches the vendored artifact's ABI exactly.
interface IDirectPropAMMAdmin {
    function fund(address token, uint256 amount, bytes32 memo) external;
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
    function setTakerAllowed(address taker, bool allowed) external;
    function setRecipientAllowed(address recipient, bool allowed) external;
    function takerAllowed(address taker) external view returns (bool);
    function recipientAllowed(address recipient) external view returns (bool);
    function resetPriceAnchor(bool baseToQuote) external;
    function priceAnchor(bool baseToQuote) external view returns (uint256);
    function setMaxPriceDeviationBps(uint256 bps) external;
    function maxOracleAge() external view returns (uint256);
    function maxPriceDeviationBps() external view returns (uint256);
    function resolveRecipient(address recipient) external view returns (address);
    function roundingCredit(bytes32 routeKey) external view returns (uint256);
    function roundingRouteKey(address taker, address recipient, bytes32 customerId) external view returns (bytes32);

    function quoteExactInputFor(address taker, address recipient, bytes32 customerId, bool baseToQuote, uint256 amountIn)
        external
        view
        returns (uint256 amountOut, uint256 price, uint256 updatedAt, uint256 creditAfter);

    function quoteExactOutputFor(address taker, address recipient, bytes32 customerId, bool baseToQuote, uint256 amountOut)
        external
        view
        returns (uint256 amountIn, uint256 price, uint256 updatedAt, uint256 creditAfter);
}

interface IPushPriceOracle {
    function pushPrice(uint256 price, uint256 updatedAt) external;
    function price() external view returns (uint256);
    function updatedAt() external view returns (uint256);
}

/**
 * @notice Strategist path exercised against the REAL DirectPropAMM. Nothing about the DEX is mocked.
 *
 * @dev The pool and its push oracle are deployed on the fork from bytecode compiled out of the
 *      propAMM repository (test/artifacts/propAMM/*.json, solc 0.8.30 + via_ir + cancun). They cannot be
 *      compiled here because this repository is pinned to solc 0.8.21, which is why the artifacts are
 *      vendored as bytecode rather than source. The "reviewed taker ABI" section below pins the
 *      selectors this suite drives against the interface, the leaf signature strings, and the
 *      deployed artifact's own dispatcher.
 *
 *      Everything else is live Tempo state: the TIP-20 PRIME and pathUSD tokens, the address registry
 *      predeploy, and the token balances the swaps move. Vault-side contracts are deployed fresh
 *      because the point is to test this repository's decoder, leaves, and manager path.
 *
 *      Prices come from the real PushPriceOracle driven by a reporter we control, which is what makes
 *      the caller-binding arguments testable: a push oracle is the only way to make the price tick
 *      between quote and execution.
 */
contract TempoPropAMMRealForkTest is MerkleTreeHelper {
    ERC20 internal constant PRIME = ERC20(0x20C00000000000000000000058d0B8b2CFDb358c);
    ERC20 internal constant PATH_USD = ERC20(0x20C0000000000000000000000000000000000000);
    address internal constant ADDRESS_REGISTRY = 0xfDC0000000000000000000000000000000000000;

    /// @dev Live PRIME holder (the propAMM deployer) and live pathUSD holder (the DEX predeploy).
    address internal constant PRIME_WHALE = 0xcC4957A13A225eA1BfC85346D48B7de2Cb2cE374;
    address internal constant PATH_USD_WHALE = 0xDEc0000000000000000000000000000000000000;
    /// @dev A second live pool, used as a real non-approved target instead of a fabricated address.
    address internal constant OTHER_LIVE_POOL = 0x360d3b2f751247BAc6eda73876F067aEB46E6397;

    uint256 internal constant FORK_BLOCK = 36_425_642;
    uint8 internal constant ORACLE_DECIMALS = 8;
    uint256 internal constant INITIAL_PRICE = 105_151_100; // 1 PRIME = 1.051511 pathUSD
    uint256 internal constant MAX_ORACLE_AGE = 90_000;
    uint256 internal constant MAX_PRICE_DEVIATION_BPS = 50;
    uint256 internal constant BPS = 10_000;

    uint8 internal constant MANAGER_ROLE = 20;
    uint8 internal constant STRATEGIST_ROLE = 21;
    bytes32 internal constant CUSTOMER_ID = keccak256("VEDA_DIRECT_PROP_AMM");
    uint256 internal constant DEFAULT_TOLERANCE_BPS = 10;

    uint256 internal constant POOL_INVENTORY = 5e6; // 5 of each token
    uint256 internal constant VAULT_FUNDING = 5e6;

    /// @dev Selectors of the exact signature strings `_addDirectPropAMMLeafs` hashes into leaves.
    ///      Verify against a deployment with:
    ///      cast sig "swapExactInput(bool,uint256,uint256,address,bytes32,bytes32,uint256,uint256,uint256,uint256)"
    bytes4 internal constant SWAP_EXACT_INPUT_SELECTOR = 0x187fe9be;
    bytes4 internal constant SWAP_EXACT_OUTPUT_SELECTOR = 0x8b6d66da;

    /// @dev Six-argument taker ABI that predates the reviewed source. It carries no deadline,
    ///      expected-price, tolerance, or minimum-updated-at binding, so a pool exposing it cannot
    ///      serve a root built from the leaves above.
    bytes4 internal constant LEGACY_SWAP_EXACT_INPUT_SELECTOR = 0x096da718;
    bytes4 internal constant LEGACY_SWAP_EXACT_OUTPUT_SELECTOR = 0x17031cd2;

    BoringVault internal boringVault;
    RolesAuthority internal rolesAuthority;
    ManagerWithMerkleVerification internal manager;
    address internal decoder;
    address internal pool;
    IPushPriceOracle internal oracle;

    struct Binding {
        uint256 expectedOraclePrice;
        uint256 oraclePriceToleranceBps;
        uint256 minimumOracleUpdatedAt;
        uint256 deadline;
    }

    function setUp() public {
        vm.createSelectFork("tempo", FORK_BLOCK);
        setSourceChainName(tempo);

        // ---- vault side, deployed fresh: this is the code under test ----
        boringVault = new BoringVault(address(this), "Real Fork Vault", "RFV", 18);
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(1));
        manager.setAuthority(rolesAuthority);
        decoder = address(new TempoDirectPropAMMDecoderAndSanitizer());

        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256("manage(address,bytes,uint256)")), true);
        rolesAuthority.setRoleCapability(STRATEGIST_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);

        // ---- real pool and real oracle, from vendored production bytecode ----
        oracle = IPushPriceOracle(
            _deploy("test/artifacts/propAMM/PushPriceOracle.json", abi.encode(ORACLE_DECIMALS, address(this), address(this), INITIAL_PRICE, block.timestamp))
        );
        pool = _deploy(
            "test/artifacts/propAMM/DirectPropAMM.json",
            abi.encode(
                address(PRIME), address(PATH_USD), address(oracle), ADDRESS_REGISTRY, address(this), address(this), MAX_ORACLE_AGE, MAX_PRICE_DEVIATION_BPS
            )
        );

        // ---- real tokens, moved from live holders ----
        vm.prank(PRIME_WHALE);
        PRIME.transfer(address(this), POOL_INVENTORY + VAULT_FUNDING);
        vm.prank(PATH_USD_WHALE);
        PATH_USD.transfer(address(this), POOL_INVENTORY + VAULT_FUNDING);
        PRIME.transfer(address(boringVault), VAULT_FUNDING);
        PATH_USD.transfer(address(boringVault), VAULT_FUNDING);

        PRIME.approve(pool, POOL_INVENTORY);
        PATH_USD.approve(pool, POOL_INVENTORY);
        IDirectPropAMMAdmin(pool).fund(address(PRIME), POOL_INVENTORY, bytes32("SEED_BASE"));
        IDirectPropAMMAdmin(pool).fund(address(PATH_USD), POOL_INVENTORY, bytes32("SEED_QUOTE"));

        IDirectPropAMMAdmin(pool).setTakerAllowed(address(boringVault), true);
        IDirectPropAMMAdmin(pool).setRecipientAllowed(address(boringVault), true);
        IDirectPropAMMAdmin(pool).resetPriceAnchor(true);
        IDirectPropAMMAdmin(pool).resetPriceAnchor(false);
        IDirectPropAMMAdmin(pool).unpause();

        setAddress(false, tempo, "boringVault", address(boringVault));
        setAddress(false, tempo, "rawDataDecoderAndSanitizer", decoder);
        (, bytes32[][] memory tree) = _tree();
        manager.setManageRoot(address(this), tree[tree.length - 1][0]);
    }

    // ===================== reviewed taker ABI =====================

    /// @dev Ties the interface, the decoder mirror, and the leaf signature strings to one pair of
    ///      pinned selectors. The leaf is a string literal in MerkleTreeHelper with no compiler link
    ///      to `IDirectPropAMM`, so any of the three drifting apart breaks this test instead of a
    ///      shipped root whose leaves are dead calldata.
    function testPinnedSelectorsMatchInterfaceAndLeafSignatures() external pure {
        assertEq(IDirectPropAMM.swapExactInput.selector, SWAP_EXACT_INPUT_SELECTOR, "swapExactInput selector drifted");
        assertEq(IDirectPropAMM.swapExactOutput.selector, SWAP_EXACT_OUTPUT_SELECTOR, "swapExactOutput selector drifted");
        assertEq(
            bytes4(keccak256("swapExactInput(bool,uint256,uint256,address,bytes32,bytes32,uint256,uint256,uint256,uint256)")),
            SWAP_EXACT_INPUT_SELECTOR,
            "leaf signature string does not match interface"
        );
        assertEq(
            bytes4(keccak256("swapExactOutput(bool,uint256,uint256,address,bytes32,bytes32,uint256,uint256,uint256,uint256)")),
            SWAP_EXACT_OUTPUT_SELECTOR,
            "leaf signature string does not match interface"
        );
    }

    /// @dev The standard repo check: every leaf signature in the tree must resolve to a function the
    ///      decoder actually implements, rather than falling through to
    ///      `BaseDecoderAndSanitizer__FunctionSelectorNotSupported`. Covers the two approval leaves as
    ///      well as the swaps, which the selector pinning above does not.
    function testDecoderImplementsEveryLeafSelector() external {
        (ManageLeaf[] memory leafs,) = _tree();
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
    }

    /// @dev Doubles as the pre-ship gate. With no environment override it checks the pool this suite
    ///      deploys from the vendored artifact, which is the only thing binding the pinned selectors
    ///      to real bytecode: a rebuilt artifact that regressed to the six-argument taker ABI would
    ///      still deploy and still pass the rest of this suite, because the swaps here go through
    ///      calldata the leaves build rather than a typed call the compiler could check.
    ///
    ///      Point it at a freshly deployed pool before shipping a root, since nothing else checks
    ///      that the live address matches the ABI the root was built for:
    ///      DIRECT_PROP_AMM_POOL=0x... FOUNDRY_PROFILE=tempo forge test --match-test ReviewedTakerAbi
    function testPoolImplementsReviewedTakerAbi() external view {
        address target = vm.envOr("DIRECT_PROP_AMM_POOL", pool);

        assertGt(target.code.length, 0, "no code at pool");
        assertTrue(_implementsSelector(target, SWAP_EXACT_INPUT_SELECTOR), "pool lacks reviewed swapExactInput");
        assertTrue(_implementsSelector(target, SWAP_EXACT_OUTPUT_SELECTOR), "pool lacks reviewed swapExactOutput");
        assertFalse(_implementsSelector(target, LEGACY_SWAP_EXACT_INPUT_SELECTOR), "pool still exposes legacy swapExactInput");
        assertFalse(_implementsSelector(target, LEGACY_SWAP_EXACT_OUTPUT_SELECTOR), "pool still exposes legacy swapExactOutput");
        assertEq(_addressView(target, "addressRegistry()"), ADDRESS_REGISTRY, "pool uses a non-canonical registry");
        assertTrue(_hasView(target, "maxPriceDeviationBps()"), "pool lacks the directional deviation guard");
        assertTrue(_hasView(target, "roundingCredit(bytes32)"), "pool lacks the rounding-credit ledger");
    }

    // ===================== real swaps through the manager =====================

    /// @dev The core case: a strategist batch settling against real pool bytecode, priced by the
    ///      pool's own route-aware quoter, with allowance hygiene enforced in the same batch.
    function testRealPoolExactInputBaseToQuote() external {
        (uint256 quoted,,,) = _quoteExactInput(true, 1e6);
        assertGt(quoted, 0, "pool quoted zero");

        uint256 primeBefore = PRIME.balanceOf(address(boringVault));
        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));

        _swapExactInput(true, 1e6, quoted, _defaultBinding());

        assertEq(PRIME.balanceOf(address(boringVault)), primeBefore - 1e6, "input delta wrong");
        assertEq(PATH_USD.balanceOf(address(boringVault)), pathBefore + quoted, "settlement disagreed with quote");
        assertEq(PRIME.allowance(address(boringVault), pool), 0, "residual allowance");
    }

    function testRealPoolExactInputQuoteToBase() external {
        (uint256 quoted,,,) = _quoteExactInput(false, 1e6);
        assertGt(quoted, 0, "pool quoted zero");

        uint256 primeBefore = PRIME.balanceOf(address(boringVault));
        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));

        _swapExactInput(false, 1e6, quoted, _defaultBinding());

        assertEq(PATH_USD.balanceOf(address(boringVault)), pathBefore - 1e6, "input delta wrong");
        assertEq(PRIME.balanceOf(address(boringVault)), primeBefore + quoted, "settlement disagreed with quote");
        assertEq(PATH_USD.allowance(address(boringVault), pool), 0, "residual allowance");
    }

    function testRealPoolExactOutput() external {
        (uint256 quotedIn,,,) = _quoteExactOutput(true, 1e6);
        assertGt(quotedIn, 0, "pool quoted zero");

        uint256 primeBefore = PRIME.balanceOf(address(boringVault));
        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));

        _swapExactOutput(true, 1e6, quotedIn, _defaultBinding());

        assertEq(PRIME.balanceOf(address(boringVault)), primeBefore - quotedIn, "input delta disagreed with quote");
        assertEq(PATH_USD.balanceOf(address(boringVault)), pathBefore + 1e6, "output delta wrong");
        assertEq(PRIME.allowance(address(boringVault), pool), 0, "residual allowance");
    }

    /// @dev Zero fee and zero spread, so a round trip returns everything but integer truncation.
    function testRealPoolRoundTripLosesOnlyRounding() external {
        uint256 primeBefore = PRIME.balanceOf(address(boringVault));

        (uint256 out,,,) = _quoteExactInput(true, 1e6);
        _swapExactInput(true, 1e6, out, _defaultBinding());
        (uint256 back,,,) = _quoteExactInput(false, out);
        _swapExactInput(false, out, back, _defaultBinding());

        assertApproxEqAbs(PRIME.balanceOf(address(boringVault)), primeBefore, 2, "round trip lost more than rounding");
    }

    /// @dev The rounding-credit route is keyed by (taker, resolvedRecipient, customerId). Fixing the
    ///      customer ID in the sanitizer is what keeps every vault trade on one route, so credit
    ///      accrued by one swap is available to the next.
    function testRealPoolAccruesRoundingCreditOnTheVaultRoute() external {
        bytes32 routeKey = IDirectPropAMMAdmin(pool).roundingRouteKey(address(boringVault), address(boringVault), CUSTOMER_ID);
        assertEq(IDirectPropAMMAdmin(pool).roundingCredit(routeKey), 0, "route started with credit");

        (uint256 out,,,) = _quoteExactInput(true, 333_333);
        _swapExactInput(true, 333_333, out, _defaultBinding());

        assertGt(IDirectPropAMMAdmin(pool).roundingCredit(routeKey), 0, "no rounding credit accrued");
    }

    /// @dev Credit earned on the vault route is spent by a later exact-output swap on the same route,
    ///      so the pool pulls strictly less input than the credit-blind `quoteExactOutput` asks for.
    ///      This is the difference tooling must not ignore: quoting with the plain form and settling
    ///      with the route form are not the same number.
    function testExactOutputConsumesRouteCreditSoAmountInIsLower() external {
        bytes32 routeKey = IDirectPropAMMAdmin(pool).roundingRouteKey(address(boringVault), address(boringVault), CUSTOMER_ID);

        (uint256 seedOut,,,) = _quoteExactInput(false, 333_333);
        _swapExactInput(false, 333_333, seedOut, _defaultBinding());
        uint256 creditBefore = IDirectPropAMMAdmin(pool).roundingCredit(routeKey);
        assertGt(creditBefore, 0, "no rounding credit to spend");

        (uint256 plainIn,,) = IDirectPropAMM(pool).quoteExactOutput(false, 100_001);
        (uint256 routeIn,,, uint256 creditAfter) = _quoteExactOutput(false, 100_001);
        assertLt(routeIn, plainIn, "route quote did not consume credit");

        uint256 primeBefore = PRIME.balanceOf(address(boringVault));
        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));
        _swapExactOutput(false, 100_001, plainIn, _defaultBinding());

        assertEq(PRIME.balanceOf(address(boringVault)) - primeBefore, 100_001, "did not receive the exact output");
        assertEq(pathBefore - PATH_USD.balanceOf(address(boringVault)), routeIn, "settled at the plain quote, not the route quote");
        assertEq(IDirectPropAMMAdmin(pool).roundingCredit(routeKey), creditAfter, "credit ledger diverged from the quote");
    }

    /// @dev `_settle` skips the input pull entirely when accumulated credit covers the whole output.
    ///      Reaching it needs the oracle to fall after the credit was earned, because credit is stored
    ///      as a raw fraction whose unit is price-dependent: a fraction banked at a high price buys
    ///      more output once the price drops. The anchor is reset because the move is deliberately
    ///      larger than `maxPriceDeviationBps` would otherwise allow.
    function testExactOutputFullyCoveredByCreditPullsNoInput() external {
        bytes32 routeKey = IDirectPropAMMAdmin(pool).roundingRouteKey(address(boringVault), address(boringVault), CUSTOMER_ID);

        (uint256 seedOut,,,) = _quoteExactInput(false, 333_333);
        _swapExactInput(false, 333_333, seedOut, _defaultBinding());
        uint256 credit = IDirectPropAMMAdmin(pool).roundingCredit(routeKey);
        assertGt(credit, 0, "no rounding credit accrued");

        _push(1e6);
        IDirectPropAMMAdmin(pool).pause();
        IDirectPropAMMAdmin(pool).resetPriceAnchor(true);
        IDirectPropAMMAdmin(pool).resetPriceAnchor(false);
        IDirectPropAMMAdmin(pool).unpause(); // unpause re-validates both anchors, so both must be reset

        (uint256 amountIn,,,) = _quoteExactOutput(false, 1);
        assertEq(amountIn, 0, "credit did not cover the whole output");

        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));
        uint256 primeBefore = PRIME.balanceOf(address(boringVault));
        _swapExactOutput(false, 1, 0, _defaultBinding());

        assertEq(PATH_USD.balanceOf(address(boringVault)), pathBefore, "pool pulled input on a fully credited swap");
        assertEq(PRIME.balanceOf(address(boringVault)) - primeBefore, 1, "did not receive the output");
        assertLt(IDirectPropAMMAdmin(pool).roundingCredit(routeKey), credit, "credit was not spent");
    }

    /// @dev The memo's blast-radius argument rests on the anchor advancing after each accepted trade:
    ///      the deviation guard bounds ONE step, not cumulative drift. Verified here against real pool
    ///      state rather than taken from the source. Two successive 40 bps pushes are each inside the
    ///      50 bps guard, yet together they move the anchor 80 bps, which a lifetime bound would stop.
    function testDirectionalAnchorAdvancesSoDriftIsNotBounded() external {
        uint256 startAnchor = IDirectPropAMMAdmin(pool).priceAnchor(true);
        assertEq(startAnchor, INITIAL_PRICE, "anchor did not initialise to the oracle price");

        uint256 stepOne = INITIAL_PRICE * (BPS + 40) / BPS;
        _push(stepOne);
        _swapExactInput(true, 1e6, 0, _defaultBinding());
        assertEq(IDirectPropAMMAdmin(pool).priceAnchor(true), stepOne, "anchor did not advance after trade");

        uint256 stepTwo = stepOne * (BPS + 40) / BPS;
        _push(stepTwo);
        _swapExactInput(true, 1e6, 0, _defaultBinding());
        assertEq(IDirectPropAMMAdmin(pool).priceAnchor(true), stepTwo, "anchor did not advance again");

        // Cumulative move well past the per-step ceiling, reached entirely through accepted trades.
        assertGt(stepTwo, startAnchor * (BPS + 70) / BPS, "cumulative drift did not exceed one step");
    }

    /// @dev `CUSTOMER_ID` is a decoder constant, so every vault using this decoder sends the same
    ///      value. That does not merge their credit: the pool keys a route on
    ///      `keccak256(taker, resolvedRecipient, customerId)` and the taker is `msg.sender`, which is
    ///      the vault running `manage`. Two vaults sharing one decoder therefore sit on two routes.
    ///      What they do share is pool inventory and the directional anchor.
    function testSecondVaultSharingTheDecoderGetsItsOwnCreditRoute() external {
        bytes32 routeOne = IDirectPropAMMAdmin(pool).roundingRouteKey(address(boringVault), address(boringVault), CUSTOMER_ID);
        (uint256 firstOut,,,) = _quoteExactInput(false, 333_333);
        _swapExactInput(false, 333_333, firstOut, _defaultBinding());
        uint256 creditOne = IDirectPropAMMAdmin(pool).roundingCredit(routeOne);
        assertGt(creditOne, 0, "first vault accrued no credit");

        (BoringVault vaultTwo, ManagerWithMerkleVerification managerTwo) = _deploySecondVault();
        bytes32 routeTwo = IDirectPropAMMAdmin(pool).roundingRouteKey(address(vaultTwo), address(vaultTwo), CUSTOMER_ID);
        assertTrue(routeOne != routeTwo, "same customer ID collapsed two vaults onto one route");
        assertEq(IDirectPropAMMAdmin(pool).roundingCredit(routeTwo), 0, "second vault inherited credit");

        _swapFromSecondVault(vaultTwo, managerTwo, 333_333);

        assertGt(IDirectPropAMMAdmin(pool).roundingCredit(routeTwo), 0, "second vault accrued no credit");
        assertEq(IDirectPropAMMAdmin(pool).roundingCredit(routeOne), creditOne, "second vault's trade moved the first vault's credit");
    }

    // ===================== caller-binding invariants, against the real pool =====================
    // The four scalars a Merkle leaf cannot pin. See DirectPropAMM_Safety_Validation.md,
    // "Mandatory strategist-tooling invariants". Each is now asserted against real pool logic.

    /// @dev Invariant 1 and 2: quote through the route-aware quoter, bind to the price it returned.
    function testCompliantToolingFlowSettlesAtTheQuotedPrice() external {
        (uint256 amountOut, uint256 price, uint256 updatedAt,) = _quoteExactInput(true, 1e6);
        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));

        _swapExactInput(true, 1e6, amountOut, Binding(price, DEFAULT_TOLERANCE_BPS, updatedAt, block.timestamp + 60));

        assertEq(PATH_USD.balanceOf(address(boringVault)), pathBefore + amountOut, "settlement moved off the quote");
    }

    /// @dev Invariant 3: a tick beyond tolerance must reject. 20 bps stays inside the 50 bps
    ///      directional anchor, so the caller binding is the only guard that catches it.
    function testCallerPriceBindingRejectsTickBeyondTolerance() external {
        _push(INITIAL_PRICE * (BPS + 20) / BPS);
        Binding memory binding = Binding(INITIAL_PRICE, DEFAULT_TOLERANCE_BPS, oracle.updatedAt(), block.timestamp + 60);

        vm.expectPartialRevert(bytes4(keccak256("OraclePriceToleranceExceeded(uint256,uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    function testCallerPriceBindingAcceptsTickWithinTolerance() external {
        _push(INITIAL_PRICE * (BPS + 5) / BPS);
        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));
        Binding memory binding = Binding(INITIAL_PRICE, DEFAULT_TOLERANCE_BPS, oracle.updatedAt(), block.timestamp + 60);

        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
        assertGt(PATH_USD.balanceOf(address(boringVault)), pathBefore, "swap inside tolerance did not settle");
    }

    /// @dev Invariant 3, why nonzero: one unit of movement defeats a zero tolerance, so tooling that
    ///      submits 0 reverts on any push between quote and execution.
    function testZeroToleranceRevertsOnASingleUnitTick() external {
        _push(INITIAL_PRICE + 1);
        Binding memory binding = Binding(INITIAL_PRICE, 0, oracle.updatedAt(), block.timestamp + 60);

        vm.expectPartialRevert(bytes4(keccak256("OraclePriceToleranceExceeded(uint256,uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    /// @dev Invariant 4: the observation must be no older than the one the quote priced from.
    function testMinimumOracleUpdatedAtRejectsAnOlderObservation() external {
        Binding memory binding = Binding(oracle.price(), DEFAULT_TOLERANCE_BPS, oracle.updatedAt() + 1, block.timestamp + 60);

        vm.expectPartialRevert(bytes4(keccak256("OracleTimestampTooOld(uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    /// @dev Invariant 2: both directions bind the raw oracle price, so an inverted expected price
    ///      does not mirror the binding, it breaks it.
    function testInvertedExpectedOraclePriceBreaksTheBinding() external {
        uint256 inverted = (10 ** ORACLE_DECIMALS) * (10 ** ORACLE_DECIMALS) / INITIAL_PRICE;
        Binding memory binding = Binding(inverted, DEFAULT_TOLERANCE_BPS, oracle.updatedAt(), block.timestamp + 60);

        vm.expectPartialRevert(bytes4(keccak256("OraclePriceToleranceExceeded(uint256,uint256,uint256)")));
        this.callSwapExactInput(false, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);

        vm.expectPartialRevert(bytes4(keccak256("OraclePriceToleranceExceeded(uint256,uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    function testToleranceAboveBpsCeilingReverts() external {
        Binding memory binding = Binding(oracle.price(), BPS + 1, oracle.updatedAt(), block.timestamp + 60);

        vm.expectPartialRevert(bytes4(keccak256("InvalidOraclePriceToleranceBps(uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    /// @dev Invariant 5: an expired deadline rejects.
    function testExpiredDeadlineReverts() external {
        Binding memory binding = Binding(oracle.price(), DEFAULT_TOLERANCE_BPS, oracle.updatedAt(), block.timestamp - 1);

        vm.expectPartialRevert(bytes4(keccak256("DeadlineExpired(uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    /// @dev The accepted gap, on real pool logic: every scalar wide open still passes proof
    ///      verification and settles. See the memo's "Scalars the root cannot pin".
    function testRootDoesNotConstrainScalarsSoAnUnboundedSwapStillVerifies() external {
        uint256 pathBefore = PATH_USD.balanceOf(address(boringVault));
        Binding memory wideOpen = Binding(oracle.price(), BPS, 0, type(uint256).max);

        _swapExactInput(true, 1e6, 0, wideOpen);
        assertGt(PATH_USD.balanceOf(address(boringVault)), pathBefore, "unbounded swap did not settle");
    }

    // ===================== the real pool's own guards =====================

    function testRealPoolRevertsOnStaleOracle() external {
        vm.warp(block.timestamp + MAX_ORACLE_AGE + 1);
        Binding memory binding = _defaultBinding();
        vm.expectPartialRevert(bytes4(keccak256("StaleOraclePrice(uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    /// @dev A move larger than the directional anchor allows is rejected even when the caller's own
    ///      binding is satisfied, which is the pool-side ceiling the memo's blast radius rests on.
    function testRealPoolRevertsOnDirectionalAnchorDeviation() external {
        _push(INITIAL_PRICE * (BPS + 200) / BPS);
        Binding memory binding = Binding(oracle.price(), DEFAULT_TOLERANCE_BPS, oracle.updatedAt(), block.timestamp + 60);

        vm.expectPartialRevert(bytes4(keccak256("PriceDeviationExceeded(bool,uint256,uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    function testRealPoolRevertsOnSlippage() external {
        (uint256 quoted,,,) = _quoteExactInput(true, 1e6);
        Binding memory binding = _defaultBinding();
        vm.expectPartialRevert(bytes4(keccak256("SlippageExceeded(uint256,uint256)")));
        this.callSwapExactInput(true, 1e6, quoted + 1, CUSTOMER_ID, address(boringVault), binding);
    }

    /// @dev Sized so the input pull succeeds and the pool then runs out of OUTPUT inventory. A larger
    ///      input would fail the vault's own token transfer first and never reach this guard.
    /// @dev The exact-output bound is a separate branch from the exact-input one above
    ///      (`SlippageExceeded(maxAmountIn, amountIn)` against `SlippageExceeded(minAmountOut, amountOut)`),
    ///      so both directions of the check are exercised.
    function testRealPoolRevertsOnSlippageForExactOutput() external {
        (uint256 quoted,,,) = _quoteExactOutput(true, 1e6);
        Binding memory binding = _defaultBinding();
        vm.expectPartialRevert(bytes4(keccak256("SlippageExceeded(uint256,uint256)")));
        this.callSwapExactOutput(true, 1e6, quoted - 1, binding);
    }

    function testRealPoolRevertsOnInsufficientInventory() external {
        (uint256 quoted,,,) = _quoteExactInput(true, VAULT_FUNDING);
        assertGt(quoted, POOL_INVENTORY, "test amount does not exceed pool inventory");

        Binding memory binding = _defaultBinding();
        vm.expectPartialRevert(bytes4(keccak256("InsufficientInventory(address,uint256,uint256)")));
        this.callSwapExactInput(true, VAULT_FUNDING, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    /// @dev A guardian pause takes the direct path offline with no fallback venue. Fail-closed is
    ///      intended; this is the availability risk the memo records.
    function testRealPoolRevertsWhenPaused() external {
        Binding memory binding = _defaultBinding();
        IDirectPropAMMAdmin(pool).pause();
        vm.expectPartialRevert(bytes4(keccak256("Paused()")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    function testRealPoolRevertsAfterTakerPermissionRevoked() external {
        Binding memory binding = _defaultBinding();
        IDirectPropAMMAdmin(pool).setTakerAllowed(address(boringVault), false);
        vm.expectPartialRevert(bytes4(keccak256("TakerNotAllowed(address)")));
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(boringVault), binding);
    }

    /// @dev Settlement pays the raw recipient while the exact-delta check watches
    ///      `resolveRecipient(recipient)`. The live registry must map the vault to itself or the two
    ///      diverge. This is the memo's registry gate, asserted through the pool's own view.
    function testPoolResolvesVaultRecipientToItself() external view {
        assertEq(IDirectPropAMMAdmin(pool).resolveRecipient(address(boringVault)), address(boringVault));
    }

    // ===================== what the Merkle root enforces =====================

    function testRecipientOtherThanVaultFailsMerkleProof() external {
        Binding memory binding = _defaultBinding();
        _expectProofFailure();
        this.callSwapExactInput(true, 1e6, 0, CUSTOMER_ID, address(0xBEEF), binding);
    }

    function testApprovalToNonPoolSpenderFailsMerkleProof() external {
        _expectProofFailure();
        this.callManageOne(0, address(PRIME), abi.encodeWithSignature("approve(address,uint256)", address(0xBEEF), 1e6));
    }

    function testApprovalOnUnpinnedTokenFailsMerkleProof() external {
        _expectProofFailure();
        this.callManageOne(0, address(0xFEED), abi.encodeWithSignature("approve(address,uint256)", pool, 1e6));
    }

    /// @dev The rejected target is another real pool, not a fabricated address.
    function testSwapOnDifferentLivePoolFailsMerkleProof() external {
        bytes memory payload = _swapInputCalldata(true, 1e6, 0, address(boringVault), CUSTOMER_ID, _defaultBinding());
        _expectProofFailure();
        this.callManageOne(2, OTHER_LIVE_POOL, payload);
    }

    function testUnmirroredSelectorHitsDecoderFallback() external {
        vm.expectRevert(BaseDecoderAndSanitizer.BaseDecoderAndSanitizer__FunctionSelectorNotSupported.selector);
        this.callManageOne(2, pool, abi.encodeCall(IDirectPropAMMAdmin.pause, ()));
    }

    function testZeroCustomerIdRejectedBySanitizer() external {
        Binding memory binding = _defaultBinding();
        vm.expectRevert(DirectPropAMMDecoderAndSanitizer.DirectPropAMMDecoderAndSanitizer__InvalidCustomerId.selector);
        this.callSwapExactInput(true, 1e6, 0, bytes32(0), address(boringVault), binding);
    }

    function testNonCanonicalCustomerIdRejectedBySanitizer() external {
        Binding memory binding = _defaultBinding();
        vm.expectRevert(DirectPropAMMDecoderAndSanitizer.DirectPropAMMDecoderAndSanitizer__InvalidCustomerId.selector);
        this.callSwapExactInput(true, 1e6, 0, bytes32("another-route"), address(boringVault), binding);
    }

    // ===================== helpers =====================

    /// @dev Scans deployed bytecode for the selector as a PUSH4 immediate, which is how solc emits
    ///      every entry in its dispatcher. Probing by staticcall cannot distinguish "no such
    ///      function" from a guard reverting without data, so read the dispatcher directly.
    function _implementsSelector(address target, bytes4 selector) internal view returns (bool) {
        bytes memory code = target.code;
        if (code.length < 5) return false;
        for (uint256 i; i < code.length - 4; ++i) {
            if (code[i] != 0x63) continue; // PUSH4
            if (code[i + 1] == selector[0] && code[i + 2] == selector[1] && code[i + 3] == selector[2] && code[i + 4] == selector[3]) {
                return true;
            }
        }
        return false;
    }

    function _hasView(address target, string memory signature) internal view returns (bool) {
        (bool ok, bytes memory ret) = target.staticcall(abi.encodeWithSignature(signature, bytes32(0)));
        return ok && ret.length > 0;
    }

    function _addressView(address target, string memory signature) internal view returns (address) {
        (bool ok, bytes memory ret) = target.staticcall(abi.encodeWithSignature(signature));
        require(ok && ret.length == 32, "view call failed");
        return abi.decode(ret, (address));
    }

    /// @dev A second vault with its own manager and root, wired to the SAME decoder instance.
    function _deploySecondVault() internal returns (BoringVault vaultTwo, ManagerWithMerkleVerification managerTwo) {
        vaultTwo = new BoringVault(address(this), "Second Vault", "SV", 18);
        RolesAuthority authorityTwo = new RolesAuthority(address(this), Authority(address(0)));
        vaultTwo.setAuthority(authorityTwo);
        managerTwo = new ManagerWithMerkleVerification(address(this), address(vaultTwo), address(1));
        managerTwo.setAuthority(authorityTwo);
        authorityTwo.setUserRole(address(managerTwo), MANAGER_ROLE, true);
        authorityTwo.setUserRole(address(this), STRATEGIST_ROLE, true);
        authorityTwo.setRoleCapability(MANAGER_ROLE, address(vaultTwo), bytes4(keccak256("manage(address,bytes,uint256)")), true);
        authorityTwo.setRoleCapability(STRATEGIST_ROLE, address(managerTwo), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);

        IDirectPropAMMAdmin(pool).setTakerAllowed(address(vaultTwo), true);
        IDirectPropAMMAdmin(pool).setRecipientAllowed(address(vaultTwo), true);
        // setUp spends the test contract's whole pathUSD balance, so fund this vault from the whale.
        vm.prank(PATH_USD_WHALE);
        PATH_USD.transfer(address(vaultTwo), VAULT_FUNDING);
    }

    function _secondVaultTree(address vaultTwo) internal returns (ManageLeaf[] memory leafs, bytes32[][] memory tree) {
        setAddress(true, tempo, "boringVault", vaultTwo);
        leafIndex = type(uint256).max;
        ownerToTokenToSpenderToApprovalInTree[vaultTwo][address(PRIME)][pool] = false;
        ownerToTokenToSpenderToApprovalInTree[vaultTwo][address(PATH_USD)][pool] = false;
        leafs = new ManageLeaf[](4);
        _addDirectPropAMMLeafs(leafs, pool, address(PRIME), address(PATH_USD));
        tree = _generateMerkleTree(leafs);
        setAddress(true, tempo, "boringVault", address(boringVault));
    }

    function _swapFromSecondVault(BoringVault vaultTwo, ManagerWithMerkleVerification managerTwo, uint256 amountIn) internal {
        (ManageLeaf[] memory leafs, bytes32[][] memory tree) = _secondVaultTree(address(vaultTwo));
        managerTwo.setManageRoot(address(this), tree[tree.length - 1][0]);

        (uint256 quoted,,) = IDirectPropAMM(pool).quoteExactInput(false, amountIn);
        bytes memory swapData = _swapInputCalldata(false, amountIn, quoted, address(vaultTwo), CUSTOMER_ID, _defaultBinding());

        ManageLeaf[] memory selected = new ManageLeaf[](4);
        selected[0] = leafs[1];
        selected[1] = leafs[1];
        selected[2] = leafs[2];
        selected[3] = leafs[1];

        address[] memory decoders = new address[](4);
        address[] memory targets = new address[](4);
        bytes[] memory data = new bytes[](4);
        for (uint256 i; i < 4; ++i) {
            decoders[i] = decoder;
            targets[i] = address(PATH_USD);
        }
        targets[2] = pool;
        data[0] = abi.encodeWithSignature("approve(address,uint256)", pool, 0);
        data[1] = abi.encodeWithSignature("approve(address,uint256)", pool, amountIn);
        data[2] = swapData;
        data[3] = abi.encodeWithSignature("approve(address,uint256)", pool, 0);

        managerTwo.manageVaultWithMerkleVerification(_getProofsUsingTree(selected, tree), decoders, targets, data, new uint256[](4));
    }

    function _deploy(string memory artifact, bytes memory args) internal returns (address deployed) {
        bytes memory creationCode = abi.encodePacked(vm.getCode(artifact), args);
        assembly {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        require(deployed != address(0), "deploy failed");
    }

    /// @dev The real PushPriceOracle rejects a non-increasing timestamp with
    ///      TimestampNotIncreasing, so every push has to advance the clock first.
    function _push(uint256 newPrice) internal {
        vm.warp(block.timestamp + 1);
        oracle.pushPrice(newPrice, block.timestamp);
    }

    function _defaultBinding() internal view returns (Binding memory) {
        return Binding(oracle.price(), DEFAULT_TOLERANCE_BPS, oracle.updatedAt(), block.timestamp + 60);
    }

    function _quoteExactInput(bool baseToQuote, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut, uint256 price, uint256 updatedAt, uint256 creditAfter)
    {
        return IDirectPropAMMAdmin(pool).quoteExactInputFor(address(boringVault), address(boringVault), CUSTOMER_ID, baseToQuote, amountIn);
    }

    function _quoteExactOutput(bool baseToQuote, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn, uint256 price, uint256 updatedAt, uint256 creditAfter)
    {
        return IDirectPropAMMAdmin(pool).quoteExactOutputFor(address(boringVault), address(boringVault), CUSTOMER_ID, baseToQuote, amountOut);
    }

    function _swapInputCalldata(bool baseToQuote, uint256 amountIn, uint256 minAmountOut, address recipient, bytes32 customerId, Binding memory binding)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            IDirectPropAMM.swapExactInput,
            (
                baseToQuote,
                amountIn,
                minAmountOut,
                recipient,
                customerId,
                keccak256(abi.encode(block.number, amountIn)),
                binding.deadline,
                binding.expectedOraclePrice,
                binding.oraclePriceToleranceBps,
                binding.minimumOracleUpdatedAt
            )
        );
    }

    function _swapExactInput(bool baseToQuote, uint256 amountIn, uint256 minAmountOut, Binding memory binding) internal {
        address tokenIn = baseToQuote ? address(PRIME) : address(PATH_USD);
        _manageBatch(tokenIn, amountIn, _swapInputCalldata(baseToQuote, amountIn, minAmountOut, address(boringVault), CUSTOMER_ID, binding), 2);
    }

    function _swapExactOutput(bool baseToQuote, uint256 amountOut, uint256 maxAmountIn, Binding memory binding) internal {
        address tokenIn = baseToQuote ? address(PRIME) : address(PATH_USD);
        bytes memory data = abi.encodeCall(
            IDirectPropAMM.swapExactOutput,
            (
                baseToQuote,
                amountOut,
                maxAmountIn,
                address(boringVault),
                CUSTOMER_ID,
                keccak256(abi.encode(block.number, amountOut)),
                binding.deadline,
                binding.expectedOraclePrice,
                binding.oraclePriceToleranceBps,
                binding.minimumOracleUpdatedAt
            )
        );
        _manageBatch(tokenIn, maxAmountIn, data, 3);
    }

    /// @dev External so `vm.expectRevert` observes the manager call, not this test's frame.
    function callSwapExactInput(bool baseToQuote, uint256 amountIn, uint256 minAmountOut, bytes32 customerId, address recipient, Binding memory binding)
        external
    {
        require(msg.sender == address(this));
        address tokenIn = baseToQuote ? address(PRIME) : address(PATH_USD);
        _manageBatch(tokenIn, amountIn, _swapInputCalldata(baseToQuote, amountIn, minAmountOut, recipient, customerId, binding), 2);
    }

    function callSwapExactOutput(bool baseToQuote, uint256 amountOut, uint256 maxAmountIn, Binding memory binding) external {
        require(msg.sender == address(this));
        _swapExactOutput(baseToQuote, amountOut, maxAmountIn, binding);
    }

    function callManageOne(uint256 leafIdx, address target, bytes memory payload) external {
        require(msg.sender == address(this));
        (ManageLeaf[] memory leafs, bytes32[][] memory tree) = _tree();
        ManageLeaf[] memory selected = new ManageLeaf[](1);
        selected[0] = leafs[leafIdx];

        address[] memory decoders = new address[](1);
        decoders[0] = decoder;
        address[] memory targets = new address[](1);
        targets[0] = target;
        bytes[] memory data = new bytes[](1);
        data[0] = payload;

        manager.manageVaultWithMerkleVerification(_getProofsUsingTree(selected, tree), decoders, targets, data, new uint256[](1));
    }

    /// @dev approve(0) -> approve(amount) -> swap -> approve(0) in one manager call.
    function _manageBatch(address tokenIn, uint256 approvalAmount, bytes memory swapData, uint256 swapLeaf) internal {
        (ManageLeaf[] memory leafs, bytes32[][] memory tree) = _tree();
        uint256 approvalLeaf = tokenIn == address(PRIME) ? 0 : 1;

        ManageLeaf[] memory selected = new ManageLeaf[](4);
        selected[0] = leafs[approvalLeaf];
        selected[1] = leafs[approvalLeaf];
        selected[2] = leafs[swapLeaf];
        selected[3] = leafs[approvalLeaf];

        address[] memory decoders = new address[](4);
        address[] memory targets = new address[](4);
        bytes[] memory data = new bytes[](4);
        for (uint256 i; i < 4; ++i) {
            decoders[i] = decoder;
        }
        targets[0] = tokenIn;
        targets[1] = tokenIn;
        targets[2] = pool;
        targets[3] = tokenIn;
        data[0] = abi.encodeWithSignature("approve(address,uint256)", pool, 0);
        data[1] = abi.encodeWithSignature("approve(address,uint256)", pool, approvalAmount);
        data[2] = swapData;
        data[3] = abi.encodeWithSignature("approve(address,uint256)", pool, 0);

        manager.manageVaultWithMerkleVerification(_getProofsUsingTree(selected, tree), decoders, targets, data, new uint256[](4));
    }

    function _expectProofFailure() internal {
        vm.expectPartialRevert(ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector);
    }

    /// @dev Uses the production leaf helper unchanged: leaves 0 and 1 are the pair-token approvals,
    ///      leaves 2 and 3 are exact-input and exact-output swaps.
    function _tree() internal returns (ManageLeaf[] memory leafs, bytes32[][] memory tree) {
        leafIndex = type(uint256).max;
        ownerToTokenToSpenderToApprovalInTree[address(boringVault)][address(PRIME)][pool] = false;
        ownerToTokenToSpenderToApprovalInTree[address(boringVault)][address(PATH_USD)][pool] = false;
        leafs = new ManageLeaf[](4);
        _addDirectPropAMMLeafs(leafs, pool, address(PRIME), address(PATH_USD));
        tree = _generateMerkleTree(leafs);
    }
}
