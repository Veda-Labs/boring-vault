// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {LayerZeroShareMoverHarness} from "test/mocks/LayerZeroShareMoverHarness.sol";
import {MockVault} from "test/mocks/MockVault.sol";
import {LayerZeroShareMover} from "src/base/Roles/CrossChain/ShareMover/LayerZeroShareMover.sol";
import {MockEndpoint} from "test/mocks/MockEndpoint.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {PairwiseRateLimiter} from "src/base/Roles/CrossChain/PairwiseRateLimiter.sol";

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
        vm.expectRevert();
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
        vm.expectRevert();
        harness.exposedDecode(bad);
    }

    function testPause() external {
        harness.pause();
        vm.expectRevert(LayerZeroShareMover.EnforcedPause.selector);
        harness.bridge(1e6, 101, bytes32(uint256(uint160(address(0x1)))), "", ERC20(address(0)));
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

    uint32 constant dstEid = 99;
    bytes32 constant TO = bytes32(uint256(uint160(address(1))));
    address constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() external {
        vault = new MockVault(18);
        endpoint = new MockEndpoint();
        mover = new LayerZeroShareMover(
            address(this), // owner
            address(0),    // authority
            address(vault),
            address(endpoint),
            address(this), // delegate
            address(0xdead)
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
        uint256 fee = mover.previewFee(1e6, dstEid, TO, _wildcard(2 ether), ERC20(NATIVE));
        assertEq(fee, 1 ether);
    }

    function testSendMessageRevertsMaxFeeTooLow() external {
        endpoint.setQuote(1 ether, 0);
        vault.mint(address(this), 1e6);
        vm.expectRevert();
        mover.bridge{value: 1 ether}(1e6, dstEid, TO, _wildcard(0.5 ether), ERC20(NATIVE));
    }

    function testSendMessageSucceedsWhenMaxFeeOk() external {
        endpoint.setQuote(1 ether, 0);
        vault.mint(address(this), 1e6);
        mover.bridge{value: 1 ether}(1e6, dstEid, TO, _wildcard(2 ether), ERC20(NATIVE));
    }
} 