// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {MockLayerZeroEndPoint} from "src/helper/MockLayerZeroEndPoint.sol";
import {MockVault} from "test/mocks/MockVault.sol";
import {LayerZeroShareMover} from "src/base/Roles/CrossChain/ShareMover/LayerZeroShareMover.sol";
import {PairwiseRateLimiter} from "src/base/Roles/CrossChain/PairwiseRateLimiter.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {Vm} from "@forge-std/Vm.sol";

// ---------------------------------------------------------------------------
// Minimal token that blindly succeeds on transferFrom; used to simulate LZ token
// ---------------------------------------------------------------------------
contract PermissiveToken {
    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }
    function approve(address, uint256) external pure returns (bool) {
        return true;
    }
    function balanceOf(address) external pure returns (uint256) {
        return type(uint256).max;
    }
    function totalSupply() external pure returns (uint256) {
        return type(uint256).max;
    }
    function decimals() external pure returns (uint8) {
        return 18;
    }
}

/**
 * @title LayerZeroShareMoverIntegrationTest
 * @notice “Integration-lite” test exercising a full cross-chain share transfer
 *         using the real LayerZeroShareMover contracts wired to a mocked
 *         LayerZero endpoint.  The test validates decimal conversion, fee
 *         enforcement, pause behaviour and rate-limit logic without leaving the
 *         Foundry VM.
 */
contract LayerZeroShareMoverIntegrationTest is Test {
    using AddressToBytes32Lib for address;

    // ───────────────────────────  CONSTANTS  ────────────────────────────────
    uint32 internal constant SRC_EID = 101;
    uint32 internal constant DST_EID = 102;

    uint8 internal constant SRC_DECIMALS = 18;
    uint8 internal constant DST_DECIMALS = 6; // different to trigger scaling

    uint96 internal constant SHARES = 1_000e18; // 1,000 shares on source

    address internal constant NATIVE_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE = ERC20(NATIVE_ADDR);

    uint256 internal constant QUOTED_FEE = 0.01 ether;

    // ───────────────────────────  STATE  ────────────────────────────────────
    MockLayerZeroEndPoint internal endpoint;

    MockVault internal sourceVault;
    MockVault internal destVault;

    LayerZeroShareMover internal sourceMover;
    LayerZeroShareMover internal destMover;

    address internal user;

    // ───────────────────────────  SET-UP  ────────────────────────────────────
    function setUp() external {
        user = vm.addr(1);

        // Deploy endpoint & vaults
        endpoint = new MockLayerZeroEndPoint();
        sourceVault = new MockVault(SRC_DECIMALS);
        destVault = new MockVault(DST_DECIMALS);

        // Deploy movers (owner = this, delegate = this)
        sourceMover = new LayerZeroShareMover(
            address(this),
            address(0),
            address(sourceVault),
            address(endpoint),
            address(this),
            address(0xdead)
        );
        destMover = new LayerZeroShareMover(
            address(this),
            address(0),
            address(destVault),
            address(endpoint),
            address(this),
            address(0xdead)
        );

        // Register senders with endpoint
        endpoint.setSenderToId(address(sourceMover), SRC_EID);
        endpoint.setSenderToId(address(destMover), DST_EID);

        // Wire peer mappings & chain configs
        sourceMover.addChain(
            DST_EID,
            true,
            true,
            address(destMover).toBytes32(),
            500_000,
            DST_DECIMALS,
            LayerZeroShareMover.ChainType.EVM
        );
        destMover.addChain(
            SRC_EID,
            true,
            true,
            address(sourceMover).toBytes32(),
            500_000,
            SRC_DECIMALS,
            LayerZeroShareMover.ChainType.EVM
        );

        // Generous rate limits so normal tests don't revert unless we want them to
        PairwiseRateLimiter.RateLimitConfig[] memory cfg = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfg[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: DST_EID, limit: type(uint256).max, window: 1});
        sourceMover.setOutboundRateLimits(cfg);
        destMover.setInboundRateLimits(cfg);

        // Endpoint fee quotes (native & LZ token)
        endpoint.setFee(NATIVE, QUOTED_FEE);
        endpoint.setFee(endpoint.lzToken(), 0);

        // Fund user with shares & approve
        sourceVault.mint(user, SHARES);
        vm.prank(user);
        sourceVault.approve(address(sourceMover), SHARES);

        // Give the user enough native ETH to pay bridge fees
        vm.deal(user, 1 ether);

        // Fund the source mover itself so it can forward the fee to the endpoint.
        vm.deal(address(sourceMover), 1 ether);

        // Configure inbound limit on destination mover (peer = SRC_EID)
        PairwiseRateLimiter.RateLimitConfig[] memory cfgIn = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfgIn[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: SRC_EID, limit: type(uint256).max, window: 1});
        destMover.setInboundRateLimits(cfgIn);
    }

    // ───────────────────────────  HELPERS  ──────────────────────────────────
    function _wildcard(uint256 maxFee) internal pure returns (bytes memory) {
        return abi.encode(DST_EID, NATIVE_ADDR, maxFee);
    }

    function _bridgeAndDeliver(uint96 shareAmount, uint256 maxFee) internal {
        bytes memory wildcard = _wildcard(maxFee);
        bytes32 recip = user.toBytes32();

        // user initiates bridge on source chain
        vm.prank(user);
        sourceMover.bridge{value: QUOTED_FEE}(shareAmount, DST_EID, recip, wildcard, NATIVE);

        // fetch packet from endpoint and deliver to destination mover
        MockLayerZeroEndPoint.Packet memory pkt = endpoint.getLastMessage();
        vm.prank(address(endpoint));
        LayerZeroShareMover(pkt.to).lzReceive(
            pkt._origin,
            pkt._guid,
            pkt._message,
            pkt._executor,
            pkt._extraData
        );
    }

    function _bridgeGetPacket(uint96 shareAmount, uint256 maxFee) internal returns (MockLayerZeroEndPoint.Packet memory) {
        bytes memory wildcard = _wildcard(maxFee);
        bytes32 recip = user.toBytes32();

        vm.prank(user);
        sourceMover.bridge{value: QUOTED_FEE}(shareAmount, DST_EID, recip, wildcard, NATIVE);

        return endpoint.getLastMessage();
    }

    // ───────────────────────────  TESTS  ────────────────────────────────────

    function testHappyPath() external {
        _bridgeAndDeliver(SHARES, 1 ether); // generous maxFee

        // Source vault balance should be zero (burned)
        assertEq(sourceVault.balanceOf(user), 0, "shares not burned");

        // Expect scaled amount on destination: 10^(SRC_DECIMALS - DST_DECIMALS) factor
        uint256 expected = uint256(SHARES) / 1e12; // 18 → 6
        assertEq(destVault.balanceOf(user), expected, "shares not minted correctly");
    }

    function testFeeExceedsMaxReverts() external {
        uint256 lowMaxFee = QUOTED_FEE / 2; // lower than quote
        bytes memory wildcard = _wildcard(lowMaxFee);
        bytes32 recip = user.toBytes32();

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                LayerZeroShareMover.LayerZeroShareMover__FeeExceedsMax.selector,
                DST_EID,
                QUOTED_FEE,
                lowMaxFee
            )
        );
        sourceMover.bridge{value: QUOTED_FEE}(SHARES, DST_EID, recip, wildcard, NATIVE);
    }

    function testOutboundRateLimit() external {
        // Set strict limit: 100 shares per hour
        PairwiseRateLimiter.RateLimitConfig[] memory cfg = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfg[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: DST_EID, limit: 100e18, window: 3600});
        sourceMover.setOutboundRateLimits(cfg);

        // First bridge uses full limit
        _bridgeAndDeliver(100e18, 1 ether);

        // Second bridge within same window should revert
        bytes memory wildcard = _wildcard(1 ether);
        bytes32 recip = user.toBytes32();
        vm.prank(user);
        vm.expectRevert(PairwiseRateLimiter.OutboundRateLimitExceeded.selector);
        sourceMover.bridge{value: QUOTED_FEE}(1e18, DST_EID, recip, wildcard, NATIVE);

        // Advance time past window & succeed
        vm.warp(block.timestamp + 3601);
        _bridgeAndDeliver(1e18, 1 ether);
    }

    function testPauseStopsBridge() external {
        sourceMover.pause();
        bytes memory wildcard = _wildcard(1 ether);
        vm.prank(user);
        vm.expectRevert(LayerZeroShareMover.EnforcedPause.selector);
        sourceMover.bridge{value: QUOTED_FEE}(SHARES, DST_EID, user.toBytes32(), wildcard, NATIVE);
    }

    function testInvalidRecipientFormatReverts() external {
        // Supply non-zero prefix for EVM chain recipient
        bytes32 badRecip = bytes32(uint256(uint160(user)) + (1 << 248));
        bytes memory wildcard = _wildcard(1 ether);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                LayerZeroShareMover.LayerZeroShareMover__InvalidRecipientAddressFormat.selector,
                DST_EID,
                20,
                32
            )
        );
        sourceMover.bridge{value: QUOTED_FEE}(SHARES, DST_EID, badRecip, wildcard, NATIVE);
    }

    // ----------------------  NEW TESTS  ----------------------

    function testInboundRateLimit() external {
        // Limit to 50 destination-decimals shares per hour (6-decimals)
        PairwiseRateLimiter.RateLimitConfig[] memory cfg = new PairwiseRateLimiter.RateLimitConfig[](1);
        cfg[0] = PairwiseRateLimiter.RateLimitConfig({peerEid: SRC_EID, limit: 50e6, window: 3600});
        destMover.setInboundRateLimits(cfg);

        // First delivery within limit (40e18 on source == 40e6 on dest)
        _bridgeAndDeliver(40e18, 1 ether);

        // Second delivery should exceed limit and revert
        MockLayerZeroEndPoint.Packet memory pkt = _bridgeGetPacket(20e18, 1 ether);
        vm.prank(address(endpoint));
        vm.expectRevert(PairwiseRateLimiter.InboundRateLimitExceeded.selector);
        LayerZeroShareMover(pkt.to).lzReceive(
            pkt._origin,
            pkt._guid,
            pkt._message,
            pkt._executor,
            pkt._extraData
        );
    }

    function testLzTokenFeePath() external {
        // Deploy permissive token bytecode to the mover's immutable lzToken address
        address lzTokenAddr = address(sourceMover.lzToken());
        PermissiveToken pt = new PermissiveToken();
        vm.etch(lzTokenAddr, address(pt).code);

        // Quote requires lzToken fee only
        endpoint.setFee(NATIVE, 0);
        endpoint.setFee(ERC20(lzTokenAddr), QUOTED_FEE);

        bytes memory wildcard = abi.encode(DST_EID, lzTokenAddr, 2 ether);
        bytes32 recip = user.toBytes32();

        vm.prank(user);
        // Should succeed without reverting and without native ETH value
        sourceMover.bridge(10e18, DST_EID, recip, wildcard, ERC20(lzTokenAddr));
    }

    function testEventEmission() external {
        vm.recordLogs();
        _bridgeAndDeliver(25e18, 1 ether);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 sentSig = keccak256("MessageSent(bytes32,uint32,bytes32,uint128,address)");
        bytes32 recvSig = keccak256("MessageReceived(bytes32,uint32,bytes32,uint128)");

        bool sentFound;
        bool recvFound;
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == sentSig) sentFound = true;
            if (entries[i].topics[0] == recvSig) recvFound = true;
        }
        assertTrue(sentFound && recvFound, "Expected MessageSent and MessageReceived events not found");
    }

    function testAuthReverts() external {
        // Unprivileged address attempts to pause and should revert with UNAUTHORIZED string.
        vm.prank(user); // user is not owner
        vm.expectRevert(bytes("UNAUTHORIZED"));
        sourceMover.pause();
    }
} 