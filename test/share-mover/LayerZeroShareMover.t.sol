// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {LayerZeroShareMoverHarness} from "test/mocks/LayerZeroShareMoverHarness.sol";
import {MockVault} from "test/mocks/MockVault.sol";
import {LayerZeroShareMover} from "src/base/Roles/CrossChain/ShareMover/LayerZeroShareMover.sol";
import {MockEndpoint} from "test/mocks/MockEndpoint.sol";
import {PairwiseRateLimiter} from "src/base/Roles/CrossChain/PairwiseRateLimiter.sol";
import {MessageLib} from "src/base/Roles/CrossChain/MessageLib.sol";
import {MessageLibHarness} from "test/mocks/MessageLibHarness.sol";
import {ShareMover} from "src/base/Roles/CrossChain/ShareMover/ShareMover.sol";

contract LayerZeroShareMoverHelperTest is Test {
    LayerZeroShareMoverHarness harness;
    MockVault vault;

    function setUp() external {
        vault = new MockVault(18);
        MockEndpoint endpoint = new MockEndpoint();
        harness = new LayerZeroShareMoverHarness(address(vault), address(0x1234), address(endpoint));

        // Add EVM and SOLANA chains via owner (address(this)) since harness owner is itself
        uint32 eidEvm = 101;
        uint32 eidSol = 102;
        bytes32 peer = bytes32(uint256(uint160(address(0xAA))));
        harness.addChain(eidEvm, true, true, peer, 500_000, 18, LayerZeroShareMover.ChainType.EVM);
        harness.addChain(eidSol, true, true, peer, 500_000, 9, LayerZeroShareMover.ChainType.SOLANA);
    }

    function testSanitizeRecipientEvmValid() external view {
        bytes32 padded = bytes32(uint256(uint160(address(0xBEEF))));
        bytes32 out = harness.exposedSanitize(padded, 101);
        assertEq(out, padded);
    }

    function testSanitizeRecipientEvmInvalidReverts() external {
        // first byte non-zero
        bytes32 bad = bytes32(uint256(uint160(address(0xBEEF))) + (1 << 248));
        vm.expectRevert(
            abi.encodeWithSelector(
                LayerZeroShareMover.LayerZeroShareMover__InvalidRecipientAddressFormat.selector,
                101,
                20,
                32
            )
        );
        harness.exposedSanitize(bad, 101);
    }

    function testSanitizeRecipientSolanaAccepts32Bytes() external view {
        bytes32 solanaAddr = bytes32(hex"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
        bytes32 out = harness.exposedSanitize(solanaAddr, 102);
        assertEq(out, solanaAddr);
    }

    function testDecodeBridgeParams() external view {
        uint32 chainId = 999;
        address feeToken = address(0xDEAD);
        uint256 maxFee = 123 ether;
        bytes memory data = abi.encode(chainId, feeToken, maxFee);

        (uint32 eid, address token, uint256 fee) = harness.exposedDecode(data);
        assertEq(eid, chainId);
        assertEq(token, feeToken);
        assertEq(fee, maxFee);
    }

    function testDecodeBridgeParamsInvalidReverts() external {
        bytes memory bad = hex"deadbeef"; // too short
        vm.expectRevert(LayerZeroShareMover.LayerZeroShareMover__InvalidBridgeParams.selector);
        harness.exposedDecode(bad);
    }

    function testPause() external {
        harness.pause();
        vm.expectRevert(ShareMover.ShareMover__IsPaused.selector);
        harness.bridge(1e6, bytes32(uint256(uint160(address(0x1)))), "");
    }
}

// ============================  ADMIN & RATE-LIMIT TESTS  ============================
// (migrated from LayerZeroShareMoverAdmin.t.sol)

contract LayerZeroShareMoverAdminTest is Test {
    LayerZeroShareMoverHarness harness;
    MockVault vault;

    uint32 eid = 99;
    bytes32 peer = bytes32(uint256(uint160(address(0xBEEF))));

    function setUp() external {
        vault = new MockVault(18);
        MockEndpoint ep = new MockEndpoint();
        harness = new LayerZeroShareMoverHarness(address(vault), address(0x1234), address(ep));
    }

    function testAddChainAndRateLimits() external {
        vm.recordLogs();
        harness.addChain(eid, true, false, peer, 500000, 18, LayerZeroShareMover.ChainType.EVM);
        (bool allowFrom,,,,) = harness.chains(eid);
        assertTrue(allowFrom);

        // outbound limit check
        PairwiseRateLimiter.RateLimitConfig[] memory cfg = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfg[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: eid, limit: 10, window: 1});
        harness.exposeSetOutboundLimits(cfg);
        harness.exposeOutboundCheck(eid, 5);
        vm.expectRevert(PairwiseRateLimiter.OutboundRateLimitExceeded.selector);
        harness.exposeOutboundCheck(eid, 6);

        // inbound limit check
        PairwiseRateLimiter.RateLimitConfig[] memory cfgIn = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfgIn[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: eid, limit: 10, window: 1});
        harness.exposeSetInboundLimits(cfgIn);
        harness.exposeInboundCheck(eid, 5);
        vm.expectRevert(PairwiseRateLimiter.InboundRateLimitExceeded.selector);
        harness.exposeInboundCheck(eid, 6);
    }
}

// ============================  FEE TESTS  ============================
// (migrated from LayerZeroShareMoverFee.t.sol)

contract LayerZeroShareMoverFeeTest is Test {
    LayerZeroShareMover mover;
    MockEndpoint endpoint;
    MockVault vault;
    MockVault lzToken;

    uint32 constant dstEid = 99;
    bytes32 constant TO = bytes32(uint256(uint160(address(1))));
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() external {
        vault = new MockVault(18);
        endpoint = new MockEndpoint();
        lzToken = new MockVault(18); // simple ERC20-compatible token
        mover = new LayerZeroShareMover(
            address(this), // owner
            address(0),    // authority
            address(vault),
            address(endpoint),
            address(this), // delegate
            address(lzToken)
        );
        // high outbound limit so sends don't revert via rate-limit
        PairwiseRateLimiter.RateLimitConfig[] memory cfg = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfg[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: dstEid, limit: 1e24, window: 1});
        mover.setOutboundRateLimits(cfg);
        // add chain
        mover.addChain(dstEid, true, true, bytes32(uint256(uint160(address(0x1)))), 500000, 18, LayerZeroShareMover.ChainType.EVM);
    }

    function _wildcard(uint256 maxFee) internal pure returns (bytes memory) {
        return abi.encode(dstEid, NATIVE, maxFee);
    }

    function testPreviewFeeMatchesEndpoint() external {
        endpoint.setQuote(1 ether, 0);
        uint256 fee = mover.previewFee(1e6, TO, _wildcard(2 ether));
        assertEq(fee, 1 ether);
    }

    function testSendMessageRevertsMaxFeeTooLow() external {
        endpoint.setQuote(1 ether, 0);
        vault.mint(address(this), 1e6);
        vault.approve(address(mover), 1e6);
        vm.expectRevert(
            abi.encodeWithSelector(
                LayerZeroShareMover.LayerZeroShareMover__FeeExceedsMax.selector,
                dstEid,
                1 ether,
                0.5 ether
            )
        );
        mover.bridge{value: 1 ether}(1e6, TO, _wildcard(0.5 ether));
    }

    function testSendMessageSucceedsWhenMaxFeeOk() external {
        endpoint.setQuote(1 ether, 0);
        vault.mint(address(this), 1e6);
        vault.approve(address(mover), 1e6);
        mover.bridge{value: 1 ether}(1e6, TO, _wildcard(2 ether));
    }

    /*//////////////////////////////////////////////////////////////
                             LZ TOKEN FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function _wildcardLz(uint256 maxFee) internal view returns (bytes memory) {
        return abi.encode(dstEid, address(lzToken), maxFee);
    }

    function testPreviewFeeMatchesEndpoint_LzToken() external {
        endpoint.setQuote(0, 2 ether);
        uint256 fee = mover.previewFee(1e6, TO, _wildcardLz(10 ether));
        assertEq(fee, 2 ether);
    }

    function testSendMessageRevertsMaxFeeTooLow_LzToken() external {
        endpoint.setQuote(0, 1 ether);

        // fund and approve lzToken
        lzToken.mint(address(this), 1 ether);
        lzToken.approve(address(mover), 1 ether);

        // mint shares and approve
        vault.mint(address(this), 1e6);
        vault.approve(address(mover), 1e6);

        vm.expectRevert(
            abi.encodeWithSelector(
                LayerZeroShareMover.LayerZeroShareMover__FeeExceedsMax.selector,
                dstEid,
                1 ether,
                0.5 ether
            )
        );
        mover.bridge(1e6, TO, _wildcardLz(0.5 ether));
    }

    function testSendMessageSucceedsWhenMaxFeeOk_LzToken() external {
        endpoint.setQuote(0, 1 ether);

        lzToken.mint(address(this), 1 ether);
        lzToken.approve(address(mover), 1 ether);

        vault.mint(address(this), 1e6);
        vault.approve(address(mover), 1e6);

        mover.bridge(1e6, TO, _wildcardLz(2 ether));
    }
}

// ============================  EXTENDED RATE-LIMIT WINDOW TEST  ============================

contract LayerZeroShareMoverRateLimitWindowTest is Test {
    LayerZeroShareMoverHarness harness;
    MockVault vault;

    function setUp() external {
        vault = new MockVault(18);
        MockEndpoint ep = new MockEndpoint();
        harness = new LayerZeroShareMoverHarness(address(vault), address(0x1234), address(ep));

        // Configure a long rate-limit window
        uint32 eid = 777;
        PairwiseRateLimiter.RateLimitConfig[] memory cfg = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfg[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: eid, limit: 10, window: 3600});
        harness.exposeSetOutboundLimits(cfg);
    }

    function testRateLimitResetsAcrossWindows() external {
        uint32 eid = 777;

        // consume full limit in current window
        harness.exposeOutboundCheck(eid, 10);

        // further send should revert
        vm.expectRevert(PairwiseRateLimiter.OutboundRateLimitExceeded.selector);
        harness.exposeOutboundCheck(eid, 1);

        // move into next window
        vm.warp(block.timestamp + 3601);

        // limit should reset
        harness.exposeOutboundCheck(eid, 10);
    }
}

contract LayerZeroShareMoverDecimalFuzz is Test {
    LayerZeroShareMoverHarness internal harness;
    MockVault internal vault;
    address internal user = address(0xF00F);
    MessageLibHarness internal lib;

    function setUp() external {
        vault = new MockVault(18);
        MockEndpoint ep = new MockEndpoint();
        harness = new LayerZeroShareMoverHarness(address(vault), address(0x1234), address(ep));
        lib = new MessageLibHarness();
    }

    function testFuzz_decimalConversion(uint8 dstDecimals, uint128 amount) external {
        vm.assume(dstDecimals > 0 && dstDecimals <= 27);
        vm.assume(amount > 0);

        // Ensure scaling fits into uint128 after conversion
        uint8 srcDecimals = 18;
        uint256 factor;
        if (dstDecimals > srcDecimals) {
            factor = 10 ** uint256(dstDecimals - srcDecimals);
            vm.assume(uint256(amount) * factor <= type(uint128).max);
        }

        // Add chain with dstDecimals
        uint32 eid = uint32(200 + dstDecimals); // unique
        bytes32 peer = bytes32(uint256(uint160(address(0xABCD))));
        harness.addChain(eid, true, true, peer, 500_000, dstDecimals, LayerZeroShareMover.ChainType.EVM);

        vm.assume(amount <= type(uint96).max);
        uint96 amt96 = uint96(amount);

        // Mint shares to user and approve
        vault.mint(user, amt96);
        vm.prank(user);
        vault.approve(address(harness), amt96);

        // Attempt conversion and skip cases that would revert due to dust/overflow
        uint128 expected;
        try lib.convert(amt96, srcDecimals, dstDecimals) returns (uint128 conv) {
            expected = conv;
        } catch {
            // Skip this iteration if conversion would revert (e.g., dust/overflow)
            return;
        }

        // Perform bridge using dummy wildcard (chain id inside wildcard must match "eid")
        bytes memory wc = abi.encode(eid, address(0), 0);
        vm.prank(user);
        harness.bridge(amt96, bytes32(uint256(uint160(user))), wc);

        ( , uint128 gotAmount) = harness.lastMessage();
        assertEq(gotAmount, expected, "decimal conversion mismatch");
    }
}

// ============================  PERMIT FLOW TESTS (REAL MOVER)  ============================

contract LayerZeroShareMoverPermitRealTest is Test {
    LayerZeroShareMover internal mover;
    MockEndpoint internal endpoint;
    MockVault internal vault;

    address internal constant USER = address(0xBEEF);
    uint32 internal constant DST_EID = 99;
    bytes32 internal constant TO = bytes32(uint256(uint160(address(0xCAFE))));
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;


    function setUp() external {
        vault = new MockVault(18);
        endpoint = new MockEndpoint();

        // Deploy mover with dummy LZ token
        mover = new LayerZeroShareMover(
            address(this), // owner
            address(0),    // authority
            address(vault),
            address(endpoint),
            address(this), // delegate
            address(0xdead)
        );

        // Permit path uses native fee; set quote to zero to avoid value requirement
        endpoint.setQuote(0, 0);

        // High outbound limit and chain addition
        PairwiseRateLimiter.RateLimitConfig[] memory cfg = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfg[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: DST_EID, limit: 1e24, window: 1});
        mover.setOutboundRateLimits(cfg);
        mover.addChain(DST_EID, true, true, bytes32(uint256(uint160(address(0x1)))), 500000, 18, LayerZeroShareMover.ChainType.EVM);

        // Mint shares to user
        vault.mint(USER, 1e9);
    }

    function _wildcard() internal pure returns (bytes memory) {
        return abi.encode(DST_EID, NATIVE, 0);
    }

    function testBridgeWithPermitSuccess() external {
        vault.setPermitBehavior(false); // permit succeeds

        vm.prank(USER);
        mover.bridgeWithPermit(1e6, TO, _wildcard(), 0, 0, 0, 0);

        assertTrue(vault.permitCalled(), "permit not called on vault");
        assertEq(vault.balanceOf(USER), 1e9 - 1e6, "User balance not reduced");
    }

    function testBridgeWithPermitReverts() external {
        vault.setPermitBehavior(true); // force permit revert

        vm.prank(USER);
        vm.expectRevert(ShareMover.ShareMover__InvalidPermit.selector);
        mover.bridgeWithPermit(1e6, TO, _wildcard(), 0, 0, 0, 0);
    }
}