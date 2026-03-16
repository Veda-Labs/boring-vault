// SPDX-License-Identifier: SEL-1.0
// Copyright (c) 2025 Veda Tech Labs
// Derived from Boring Vault Software (c) 2025 Veda Tech Labs (TEST ONLY - NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {
    LayerZeroTellerWithRateLimiting
} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerWithRateLimiting.sol";
import {LayerZeroTellerLib} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerLib.sol";
import {PairwiseRateLimiterLib} from "src/base/Roles/CrossChain/PairwiseRateLimiterLib.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MockLayerZeroEndPoint} from "src/helper/MockLayerZeroEndPoint.sol";
import {TellerWithMultiAssetSupport, ComplianceData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract LayerZeroTellerWithRateLimitingTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;

    MockLayerZeroEndPoint public endPoint;
    LayerZeroTellerWithRateLimiting public sourceTeller;
    LayerZeroTellerWithRateLimiting public destinationTeller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;

    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    ERC20 internal ZRO;
    address internal WEETH_RATE_PROVIDER;

    uint32 public constant SOURCE_ID = 1;
    uint32 public constant DESTINATION_ID = 2;

    address public solver = vm.addr(54);

    // Re-declare library events to avoid solc 0.8.21 cross-contract emit bug.
    event ChainAdded(uint256 chainId, bool allowMessagesFrom, bool allowMessagesTo, address targetTeller);
    event ChainRemoved(uint256 chainId);
    event ChainStopMessagesFrom(uint256 chainId);
    event ChainStopMessagesTo(uint256 chainId);
    event OutboundRateLimitsChanged(PairwiseRateLimiterLib.RateLimitConfig[] rateLimitConfigs);
    event InboundRateLimitsChanged(PairwiseRateLimiterLib.RateLimitConfig[] rateLimitConfigs);

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21023546;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        ZRO = getERC20(sourceChain, "ZRO");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        endPoint = new MockLayerZeroEndPoint();

        sourceTeller = new LayerZeroTellerWithRateLimiting(
            address(this),
            address(boringVault),
            address(accountant),
            address(WETH),
            address(endPoint),
            address(this),
            address(ZRO)
        );

        destinationTeller = new LayerZeroTellerWithRateLimiting(
            address(this),
            address(boringVault),
            address(accountant),
            address(WETH),
            address(endPoint),
            address(this),
            address(ZRO)
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        sourceTeller.setAuthority(rolesAuthority);
        destinationTeller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        rolesAuthority.setUserRole(address(sourceTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(sourceTeller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(destinationTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(destinationTeller), BURNER_ROLE, true);

        sourceTeller.updateAssetData(WETH, true, true, 0);
        sourceTeller.updateAssetData(ERC20(NATIVE), true, true, 0);
        sourceTeller.updateAssetData(EETH, true, true, 0);
        sourceTeller.updateAssetData(WEETH, true, true, 0);

        destinationTeller.updateAssetData(WETH, true, true, 0);
        destinationTeller.updateAssetData(ERC20(NATIVE), true, true, 0);
        destinationTeller.updateAssetData(EETH, true, true, 0);
        destinationTeller.updateAssetData(WEETH, true, true, 0);

        endPoint.setFee(NATIVE_ERC20, 0.001e18);
        endPoint.setFee(ZRO, 0);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));

        endPoint.setSenderToId(address(sourceTeller), SOURCE_ID);
        endPoint.setSenderToId(address(destinationTeller), DESTINATION_ID);

        // Give BoringVault some WETH, and this address some shares.
        deal(address(WETH), address(boringVault), 1_000e18);
        deal(address(boringVault), address(this), 1_000e18, true);

        // Setup chains on bridge.
        sourceTeller.addChain(DESTINATION_ID, true, true, address(destinationTeller), 1_000_000);
        destinationTeller.addChain(SOURCE_ID, true, true, address(sourceTeller), 1_000_000);
    }

    // ========================================= RATE LIMIT TESTS =========================================

    function testSetOutboundRateLimits() external {
        uint256 limit = 100e18;
        uint256 window = 1 hours;

        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: limit, window: window});

        vm.expectEmit(true, true, true, true);
        emit OutboundRateLimitsChanged(configs);
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        (uint256 amountInFlight, uint256 lastUpdated, uint256 storedLimit, uint256 storedWindow) =
            sourceTeller.outboundRateLimits(DESTINATION_ID);

        assertEq(storedLimit, limit, "Outbound limit should be set.");
        assertEq(storedWindow, window, "Outbound window should be set.");
        assertEq(amountInFlight, 0, "Amount in flight should be zero.");
        assertEq(lastUpdated, block.timestamp, "Last updated should be current timestamp.");
    }

    function testSetInboundRateLimits() external {
        uint256 limit = 200e18;
        uint256 window = 2 hours;

        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: limit, window: window});

        vm.expectEmit(true, true, true, true);
        emit InboundRateLimitsChanged(configs);
        destinationTeller.setRateLimits(new PairwiseRateLimiterLib.RateLimitConfig[](0), configs);

        (uint256 amountInFlight, uint256 lastUpdated, uint256 storedLimit, uint256 storedWindow) =
            destinationTeller.inboundRateLimits(SOURCE_ID);

        assertEq(storedLimit, limit, "Inbound limit should be set.");
        assertEq(storedWindow, window, "Inbound window should be set.");
        assertEq(amountInFlight, 0, "Amount in flight should be zero.");
        assertEq(lastUpdated, block.timestamp, "Last updated should be current timestamp.");
    }

    function testBridgeWithinOutboundRateLimit() external {
        uint256 limit = 100e18;
        uint256 window = 1 hours;

        // Set outbound rate limit on source.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: limit, window: window});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        uint96 sharesToBridge = 50e18;
        address to = vm.addr(1);

        // Bridge within limit should succeed.
        sourceTeller.bridge{value: 0.001e18}(
            sharesToBridge, to, abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        // Verify outbound amount in flight was updated.
        (uint256 amountInFlight,,,) = sourceTeller.outboundRateLimits(DESTINATION_ID);
        assertEq(amountInFlight, uint256(sharesToBridge), "Amount in flight should equal bridged shares.");
    }

    function testBridgeExceedsOutboundRateLimit() external {
        uint256 limit = 10e18;
        uint256 window = 1 hours;

        // Set a tight outbound rate limit on source.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: limit, window: window});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        uint96 sharesToBridge = 11e18;

        // Bridge exceeding limit should revert.
        vm.expectRevert(bytes(abi.encodeWithSelector(PairwiseRateLimiterLib.OutboundRateLimitExceeded.selector)));
        sourceTeller.bridge{value: 0.001e18}(
            sharesToBridge, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    function testReceiveWithinInboundRateLimit() external {
        uint256 limit = 100e18;
        uint256 window = 1 hours;

        // Set outbound rate limit on source so bridge call succeeds.
        PairwiseRateLimiterLib.RateLimitConfig[] memory outConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        outConfigs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: window});
        sourceTeller.setRateLimits(outConfigs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Set inbound rate limit on destination.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: limit, window: window});
        destinationTeller.setRateLimits(new PairwiseRateLimiterLib.RateLimitConfig[](0), configs);

        uint96 sharesToBridge = 50e18;
        address to = vm.addr(1);

        // Bridge from source.
        sourceTeller.bridge{value: 0.001e18}(
            sharesToBridge, to, abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();

        // Deliver to destination -- should succeed within inbound limit.
        vm.prank(address(endPoint));
        LayerZeroTellerWithRateLimiting(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);

        assertEq(boringVault.balanceOf(to), uint256(sharesToBridge), "Recipient should have received shares.");

        // Verify inbound amount in flight was updated.
        (uint256 amountInFlight,,,) = destinationTeller.inboundRateLimits(SOURCE_ID);
        assertEq(amountInFlight, uint256(sharesToBridge), "Inbound amount in flight should equal bridged shares.");
    }

    function testReceiveExceedsInboundRateLimit() external {
        uint256 limit = 10e18;
        uint256 window = 1 hours;

        // Set outbound rate limit on source so bridge call succeeds.
        PairwiseRateLimiterLib.RateLimitConfig[] memory outConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        outConfigs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: window});
        sourceTeller.setRateLimits(outConfigs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Set a tight inbound rate limit on destination.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: limit, window: window});
        destinationTeller.setRateLimits(new PairwiseRateLimiterLib.RateLimitConfig[](0), configs);

        uint96 sharesToBridge = 11e18;
        address to = vm.addr(1);

        // Bridge from source (no outbound rate limit set, so this succeeds).
        sourceTeller.bridge{value: 0.001e18}(
            sharesToBridge, to, abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();

        // Deliver to destination -- should revert because inbound limit exceeded.
        vm.prank(address(endPoint));
        vm.expectRevert(bytes(abi.encodeWithSelector(PairwiseRateLimiterLib.InboundRateLimitExceeded.selector)));
        LayerZeroTellerWithRateLimiting(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);
    }

    function testRateLimitDecay() external {
        uint256 limit = 100e18;
        uint256 window = 1 hours;

        // Set outbound rate limit.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: limit, window: window});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Use up the full limit.
        sourceTeller.bridge{value: 0.001e18}(
            uint96(100e18), vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        // Verify nothing can be sent now.
        (uint256 outboundInFlight, uint256 canSend) = sourceTeller.getAmountCanBeSent(DESTINATION_ID);
        assertEq(canSend, 0, "No capacity should remain immediately after maxing out.");
        assertEq(outboundInFlight, 100e18, "Full amount should be in flight.");

        // Advance half the window.
        skip(window / 2);

        // Half the limit should have decayed.
        (outboundInFlight, canSend) = sourceTeller.getAmountCanBeSent(DESTINATION_ID);
        assertEq(outboundInFlight, 50e18, "Half the amount should have decayed.");
        assertEq(canSend, 50e18, "Half the capacity should be restored.");

        // Bridge again within the recovered capacity.
        deal(address(boringVault), address(this), 1_000e18, true);
        sourceTeller.bridge{value: 0.001e18}(
            uint96(50e18), vm.addr(2), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    function testRateLimitFullDecay() external {
        uint256 limit = 100e18;
        uint256 window = 1 hours;

        // Set outbound rate limit.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: limit, window: window});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Use up the full limit.
        sourceTeller.bridge{value: 0.001e18}(
            uint96(100e18), vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        // Advance the full window.
        skip(window);

        // Full capacity should be restored.
        (uint256 outboundInFlight, uint256 canSend) = sourceTeller.getAmountCanBeSent(DESTINATION_ID);
        assertEq(outboundInFlight, 0, "Amount in flight should be zero after full decay.");
        assertEq(canSend, limit, "Full capacity should be restored.");

        // Bridge the full limit again.
        deal(address(boringVault), address(this), 1_000e18, true);
        sourceTeller.bridge{value: 0.001e18}(
            uint96(100e18), vm.addr(2), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    function testGetAmountCanBeSent() external {
        uint256 limit = 100e18;
        uint256 window = 1 hours;

        // Set outbound rate limit.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: limit, window: window});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Initially, full capacity available.
        (uint256 outboundInFlight, uint256 canSend) = sourceTeller.getAmountCanBeSent(DESTINATION_ID);
        assertEq(outboundInFlight, 0, "No amount in flight initially.");
        assertEq(canSend, limit, "Full limit available initially.");

        // Bridge 30e18 shares.
        sourceTeller.bridge{value: 0.001e18}(
            uint96(30e18), vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        (outboundInFlight, canSend) = sourceTeller.getAmountCanBeSent(DESTINATION_ID);
        assertEq(outboundInFlight, 30e18, "30e18 should be in flight.");
        assertEq(canSend, 70e18, "70e18 should remain sendable.");

        // Advance 25% of window.
        skip(window / 4);

        // decay = 100e18 * (window/4) / window = 25e18
        // currentAmountInFlight = 30e18 - 25e18 = 5e18
        // canSend = 100e18 - 5e18 = 95e18
        (outboundInFlight, canSend) = sourceTeller.getAmountCanBeSent(DESTINATION_ID);
        assertEq(outboundInFlight, 5e18, "5e18 should remain in flight after 25% decay.");
        assertEq(canSend, 95e18, "95e18 should be sendable after partial decay.");
    }

    function testGetAmountCanBeReceived() external {
        uint256 limit = 100e18;
        uint256 window = 1 hours;

        // Set outbound rate limit on source so bridge call succeeds.
        PairwiseRateLimiterLib.RateLimitConfig[] memory outConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        outConfigs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: window});
        sourceTeller.setRateLimits(outConfigs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Set inbound rate limit on destination.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: limit, window: window});
        destinationTeller.setRateLimits(new PairwiseRateLimiterLib.RateLimitConfig[](0), configs);

        // Initially, full capacity available.
        (uint256 inboundInFlight, uint256 canReceive) = destinationTeller.getAmountCanBeReceived(SOURCE_ID);
        assertEq(inboundInFlight, 0, "No inbound amount in flight initially.");
        assertEq(canReceive, limit, "Full inbound limit available initially.");

        // Bridge and deliver 40e18 shares.
        uint96 sharesToBridge = 40e18;
        address to = vm.addr(1);
        sourceTeller.bridge{value: 0.001e18}(
            sharesToBridge, to, abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();
        vm.prank(address(endPoint));
        LayerZeroTellerWithRateLimiting(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);

        (inboundInFlight, canReceive) = destinationTeller.getAmountCanBeReceived(SOURCE_ID);
        assertEq(inboundInFlight, uint256(sharesToBridge), "40e18 should be in flight inbound.");
        assertEq(canReceive, 60e18, "60e18 should remain receivable.");

        // Advance 50% of window.
        skip(window / 2);

        // decay = 100e18 * (window/2) / window = 50e18
        // currentAmountInFlight = max(0, 40e18 - 50e18) = 0
        // canReceive = 100e18 - 0 = 100e18
        (inboundInFlight, canReceive) = destinationTeller.getAmountCanBeReceived(SOURCE_ID);
        assertEq(inboundInFlight, 0, "Inbound in-flight should be zero after sufficient decay.");
        assertEq(canReceive, limit, "Full inbound capacity should be restored.");
    }

    function testUpdateRateLimitsCheckpoints() external {
        uint256 limit = 100e18;
        uint256 window = 1 hours;

        // Set outbound rate limit.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: limit, window: window});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Bridge 80e18 to create in-flight amount.
        sourceTeller.bridge{value: 0.001e18}(
            uint96(80e18), vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        // Advance 50% of window: decay = 50e18, currentInFlight = 80e18 - 50e18 = 30e18.
        skip(window / 2);

        // Now update rate limits with a new configuration.
        // The checkpoint should capture the current decayed in-flight amount (30e18).
        uint256 newLimit = 200e18;
        uint256 newWindow = 2 hours;
        configs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: newLimit, window: newWindow});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Verify the checkpoint: amountInFlight should be the decayed value (30e18),
        // and the new limit/window should be applied.
        (uint256 amountInFlight, uint256 lastUpdated, uint256 storedLimit, uint256 storedWindow) =
            sourceTeller.outboundRateLimits(DESTINATION_ID);

        assertEq(amountInFlight, 30e18, "Checkpoint should capture decayed in-flight amount.");
        assertEq(lastUpdated, block.timestamp, "Last updated should be current timestamp after checkpoint.");
        assertEq(storedLimit, newLimit, "New limit should be applied.");
        assertEq(storedWindow, newWindow, "New window should be applied.");

        // Verify the view function reflects new capacity.
        (uint256 outboundInFlight, uint256 canSend) = sourceTeller.getAmountCanBeSent(DESTINATION_ID);
        assertEq(outboundInFlight, 30e18, "Outbound in-flight should reflect checkpointed value.");
        assertEq(canSend, newLimit - 30e18, "Can send should be new limit minus checkpointed in-flight.");
    }

    // ========================================= CHAIN MANAGEMENT TESTS =========================================

    function testAddChain() external {
        uint32 newChainId = 3;
        address targetTeller = vm.addr(10);
        uint128 gasLimit = 500_000;

        vm.expectEmit(true, true, true, true);
        emit ChainAdded(newChainId, true, true, targetTeller);
        sourceTeller.addChain(newChainId, true, true, targetTeller, gasLimit);

        (bool allowFrom, bool allowTo, uint128 msgGasLimit) = sourceTeller.idToChains(newChainId);
        assertEq(allowFrom, true, "Should allow messages from new chain.");
        assertEq(allowTo, true, "Should allow messages to new chain.");
        assertEq(msgGasLimit, gasLimit, "Should store gas limit.");
    }

    function testAddSecondChainIndependent() external {
        // setUp already added DESTINATION_ID. Add a third chain.
        uint32 thirdChainId = 3;
        address thirdTeller = vm.addr(10);
        sourceTeller.addChain(thirdChainId, true, false, thirdTeller, 500_000);

        // Verify original chain is unaffected.
        (bool allowFrom, bool allowTo, uint128 msgGasLimit) = sourceTeller.idToChains(DESTINATION_ID);
        assertEq(allowFrom, true, "Original chain allowFrom should be unchanged.");
        assertEq(allowTo, true, "Original chain allowTo should be unchanged.");
        assertEq(msgGasLimit, 1_000_000, "Original chain gas limit should be unchanged.");

        // Verify new chain.
        (allowFrom, allowTo, msgGasLimit) = sourceTeller.idToChains(thirdChainId);
        assertEq(allowFrom, true, "Third chain should allow from.");
        assertEq(allowTo, false, "Third chain should not allow to.");
        assertEq(msgGasLimit, 500_000, "Third chain gas limit should be set.");
    }

    function testAddChainOverwritesExisting() external {
        // DESTINATION_ID was already added in setUp with (true, true, 1_000_000).
        // Overwrite it with different params.
        address newTarget = vm.addr(20);
        vm.expectEmit(true, true, true, true);
        emit ChainAdded(DESTINATION_ID, false, true, newTarget);
        sourceTeller.addChain(DESTINATION_ID, false, true, newTarget, 2_000_000);

        (bool allowFrom, bool allowTo, uint128 msgGasLimit) = sourceTeller.idToChains(DESTINATION_ID);
        assertEq(allowFrom, false, "Overwritten chain should not allow from.");
        assertEq(allowTo, true, "Overwritten chain should allow to.");
        assertEq(msgGasLimit, 2_000_000, "Overwritten chain gas limit should be updated.");
    }

    function testAddChainZeroGasLimitRevertsWhenAllowTo() external {
        vm.expectRevert(bytes(abi.encodeWithSelector(LayerZeroTellerLib.LayerZeroTeller__ZeroMessageGasLimit.selector)));
        sourceTeller.addChain(3, true, true, vm.addr(10), 0);
    }

    function testAddChainZeroGasLimitAllowedWhenNoAllowTo() external {
        // allowMessagesTo=false, so gasLimit=0 is acceptable.
        sourceTeller.addChain(3, true, false, vm.addr(10), 0);

        (bool allowFrom, bool allowTo,) = sourceTeller.idToChains(3);
        assertEq(allowFrom, true, "Should allow from.");
        assertEq(allowTo, false, "Should not allow to.");
    }

    function testRemoveChain() external {
        vm.expectEmit(true, true, true, true);
        emit ChainRemoved(DESTINATION_ID);
        sourceTeller.removeChain(DESTINATION_ID);

        (bool allowFrom, bool allowTo, uint128 msgGasLimit) = sourceTeller.idToChains(DESTINATION_ID);
        assertEq(allowFrom, false, "Removed chain should not allow from.");
        assertEq(allowTo, false, "Removed chain should not allow to.");
        assertEq(msgGasLimit, 0, "Removed chain gas limit should be zeroed.");
    }

    function testRemoveChainThenBridgeReverts() external {
        // Set rate limits so the revert is from chain removal, not rate limit.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        sourceTeller.removeChain(DESTINATION_ID);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    LayerZeroTellerLib.LayerZeroTeller__MessagesNotAllowedTo.selector, DESTINATION_ID
                )
            )
        );
        sourceTeller.bridge{value: 0.001e18}(
            1e18, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    function testRemoveChainThenReAdd() external {
        sourceTeller.removeChain(DESTINATION_ID);

        // Re-add with different params.
        sourceTeller.addChain(DESTINATION_ID, true, true, address(destinationTeller), 2_000_000);

        (bool allowFrom, bool allowTo, uint128 msgGasLimit) = sourceTeller.idToChains(DESTINATION_ID);
        assertEq(allowFrom, true, "Re-added chain should allow from.");
        assertEq(allowTo, true, "Re-added chain should allow to.");
        assertEq(msgGasLimit, 2_000_000, "Re-added chain should have new gas limit.");

        // Should be able to bridge again after re-adding.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        sourceTeller.bridge{value: 0.001e18}(
            1e18, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    function testStopMessagesFrom() external {
        vm.expectEmit(true, true, true, true);
        emit ChainStopMessagesFrom(DESTINATION_ID);
        sourceTeller.stopMessages(DESTINATION_ID, true, false);

        (bool allowFrom, bool allowTo, uint128 msgGasLimit) = sourceTeller.idToChains(DESTINATION_ID);
        assertEq(allowFrom, false, "Should have stopped messages from.");
        assertEq(allowTo, true, "Should still allow messages to.");
        assertEq(msgGasLimit, 1_000_000, "Gas limit should be unchanged.");
    }

    function testStopMessagesTo() external {
        vm.expectEmit(true, true, true, true);
        emit ChainStopMessagesTo(DESTINATION_ID);
        sourceTeller.stopMessages(DESTINATION_ID, false, true);

        (bool allowFrom, bool allowTo, uint128 msgGasLimit) = sourceTeller.idToChains(DESTINATION_ID);
        assertEq(allowFrom, true, "Should still allow messages from.");
        assertEq(allowTo, false, "Should have stopped messages to.");
        assertEq(msgGasLimit, 1_000_000, "Gas limit should be unchanged.");
    }

    function testStopMessagesBoth() external {
        vm.expectEmit(true, true, true, true);
        emit ChainStopMessagesFrom(DESTINATION_ID);
        vm.expectEmit(true, true, true, true);
        emit ChainStopMessagesTo(DESTINATION_ID);
        sourceTeller.stopMessages(DESTINATION_ID, true, true);

        (bool allowFrom, bool allowTo,) = sourceTeller.idToChains(DESTINATION_ID);
        assertEq(allowFrom, false, "Should have stopped messages from.");
        assertEq(allowTo, false, "Should have stopped messages to.");
    }

    function testStopMessagesNeither() external {
        // Passing (false, false) should be a no-op.
        sourceTeller.stopMessages(DESTINATION_ID, false, false);

        (bool allowFrom, bool allowTo,) = sourceTeller.idToChains(DESTINATION_ID);
        assertEq(allowFrom, true, "Should still allow messages from.");
        assertEq(allowTo, true, "Should still allow messages to.");
    }

    function testStopMessagesToThenBridgeReverts() external {
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        sourceTeller.stopMessages(DESTINATION_ID, false, true);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    LayerZeroTellerLib.LayerZeroTeller__MessagesNotAllowedTo.selector, DESTINATION_ID
                )
            )
        );
        sourceTeller.bridge{value: 0.001e18}(
            1e18, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    function testStopMessagesFromThenReceiveReverts() external {
        // Set rate limits so bridge succeeds on source.
        PairwiseRateLimiterLib.RateLimitConfig[] memory outConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        outConfigs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(outConfigs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        PairwiseRateLimiterLib.RateLimitConfig[] memory inConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        inConfigs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: 1_000e18, window: 1 hours});
        destinationTeller.setRateLimits(new PairwiseRateLimiterLib.RateLimitConfig[](0), inConfigs);

        // Bridge from source.
        sourceTeller.bridge{value: 0.001e18}(
            1e18, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();

        // Stop messages from source on destination.
        destinationTeller.stopMessages(SOURCE_ID, true, false);

        // Deliver should revert.
        vm.prank(address(endPoint));
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(LayerZeroTellerLib.LayerZeroTeller__MessagesNotAllowedFrom.selector, SOURCE_ID)
            )
        );
        LayerZeroTellerWithRateLimiting(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);
    }

    // ========================================= MULTI-CHAIN RATE LIMIT TESTS =========================================

    function testSetRateLimitsMultiplePeers() external {
        uint32 thirdChainId = 3;
        sourceTeller.addChain(thirdChainId, true, true, vm.addr(10), 500_000);

        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](2);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 100e18, window: 1 hours});
        configs[1] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: thirdChainId, limit: 200e18, window: 2 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        (,, uint256 limit1, uint256 window1) = sourceTeller.outboundRateLimits(DESTINATION_ID);
        assertEq(limit1, 100e18, "First peer limit.");
        assertEq(window1, 1 hours, "First peer window.");

        (,, uint256 limit2, uint256 window2) = sourceTeller.outboundRateLimits(thirdChainId);
        assertEq(limit2, 200e18, "Second peer limit.");
        assertEq(window2, 2 hours, "Second peer window.");
    }

    function testSetBothOutboundAndInboundInSameCall() external {
        PairwiseRateLimiterLib.RateLimitConfig[] memory outConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        outConfigs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 100e18, window: 1 hours});

        PairwiseRateLimiterLib.RateLimitConfig[] memory inConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        inConfigs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: 200e18, window: 2 hours});

        vm.expectEmit(true, true, true, true);
        emit OutboundRateLimitsChanged(outConfigs);
        vm.expectEmit(true, true, true, true);
        emit InboundRateLimitsChanged(inConfigs);
        sourceTeller.setRateLimits(outConfigs, inConfigs);

        (,, uint256 outLimit, uint256 outWindow) = sourceTeller.outboundRateLimits(DESTINATION_ID);
        assertEq(outLimit, 100e18, "Outbound limit.");
        assertEq(outWindow, 1 hours, "Outbound window.");

        (,, uint256 inLimit, uint256 inWindow) = sourceTeller.inboundRateLimits(SOURCE_ID);
        assertEq(inLimit, 200e18, "Inbound limit.");
        assertEq(inWindow, 2 hours, "Inbound window.");
    }

    function testSetRateLimitsEmptyArraysIsNoop() external {
        // Set initial limits.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 100e18, window: 1 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        (uint256 aif, uint256 lu, uint256 limit, uint256 window) = sourceTeller.outboundRateLimits(DESTINATION_ID);

        // Call with empty arrays -- should not change anything.
        sourceTeller.setRateLimits(
            new PairwiseRateLimiterLib.RateLimitConfig[](0), new PairwiseRateLimiterLib.RateLimitConfig[](0)
        );

        (uint256 aif2, uint256 lu2, uint256 limit2, uint256 window2) = sourceTeller.outboundRateLimits(DESTINATION_ID);
        assertEq(aif2, aif, "amountInFlight unchanged.");
        assertEq(lu2, lu, "lastUpdated unchanged.");
        assertEq(limit2, limit, "limit unchanged.");
        assertEq(window2, window, "window unchanged.");
    }

    function testRateLimitsIndependentPerChain() external {
        uint32 thirdChainId = 3;
        address thirdTeller = vm.addr(10);
        sourceTeller.addChain(thirdChainId, true, true, thirdTeller, 500_000);
        endPoint.setSenderToId(thirdTeller, thirdChainId);

        // Set different rate limits per chain.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](2);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 100e18, window: 1 hours});
        configs[1] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: thirdChainId, limit: 50e18, window: 1 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Bridge 90e18 to DESTINATION_ID (within its 100e18 limit).
        sourceTeller.bridge{value: 0.001e18}(
            uint96(90e18), vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        // Third chain should still have full capacity.
        (uint256 inFlight, uint256 canSend) = sourceTeller.getAmountCanBeSent(thirdChainId);
        assertEq(inFlight, 0, "Third chain should have no in-flight.");
        assertEq(canSend, 50e18, "Third chain should have full capacity.");

        // DESTINATION_ID should show 90e18 in-flight.
        (inFlight, canSend) = sourceTeller.getAmountCanBeSent(DESTINATION_ID);
        assertEq(inFlight, 90e18, "Destination should have 90e18 in-flight.");
        assertEq(canSend, 10e18, "Destination should have 10e18 remaining.");
    }

    function testBridgeWithoutRateLimitsReverts() external {
        // setUp adds chains but does NOT set rate limits.
        // Default rate limit has limit=0, so canBeSent=0, any bridge should revert.
        vm.expectRevert(bytes(abi.encodeWithSelector(PairwiseRateLimiterLib.OutboundRateLimitExceeded.selector)));
        sourceTeller.bridge{value: 0.001e18}(
            1e18, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    function testUpdateRateLimitsSuccessively() external {
        // Set initial rate limits.
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 100e18, window: 1 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        // Bridge 60e18.
        sourceTeller.bridge{value: 0.001e18}(
            uint96(60e18), vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        // Update rate limit immediately (no time elapsed, so no decay).
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 150e18, window: 2 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        (uint256 aif,, uint256 limit, uint256 window) = sourceTeller.outboundRateLimits(DESTINATION_ID);
        assertEq(aif, 60e18, "In-flight should be checkpointed at 60e18.");
        assertEq(limit, 150e18, "New limit should be applied.");
        assertEq(window, 2 hours, "New window should be applied.");

        // Can now bridge 90e18 more (150 - 60 = 90).
        deal(address(boringVault), address(this), 1_000e18, true);
        sourceTeller.bridge{value: 0.001e18}(
            uint96(90e18), vm.addr(2), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        // 91e18 should exceed.
        deal(address(boringVault), address(this), 1_000e18, true);
        vm.expectRevert(bytes(abi.encodeWithSelector(PairwiseRateLimiterLib.OutboundRateLimitExceeded.selector)));
        sourceTeller.bridge{value: 0.001e18}(
            uint96(1e18), vm.addr(3), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    // ========================================= BRIDGING AND RECEIVE TESTS =========================================

    function testBridgingSharesEndToEnd(uint96 sharesToBridge) external {
        sharesToBridge = uint96(bound(sharesToBridge, 1, 1_000e18));

        // Set rate limits large enough.
        PairwiseRateLimiterLib.RateLimitConfig[] memory outConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        outConfigs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(outConfigs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        PairwiseRateLimiterLib.RateLimitConfig[] memory inConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        inConfigs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: 1_000e18, window: 1 hours});
        destinationTeller.setRateLimits(new PairwiseRateLimiterLib.RateLimitConfig[](0), inConfigs);

        address to = vm.addr(1);
        sourceTeller.bridge{value: 0.001e18}(
            sharesToBridge, to, abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();
        vm.prank(address(endPoint));
        LayerZeroTellerWithRateLimiting(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);

        assertEq(boringVault.balanceOf(to), uint256(sharesToBridge), "Recipient should have received shares.");
    }

    function testPreviewFee(uint256 fee) external {
        endPoint.setFee(NATIVE_ERC20, fee);

        uint256 previewedFee = sourceTeller.previewFee(1e18, address(0), abi.encode(DESTINATION_ID), NATIVE_ERC20);
        assertEq(previewedFee, fee, "Previewed fee should match set fee.");
    }

    function testBridgePausedReverts() external {
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        sourceTeller.pause();

        vm.expectRevert(
            bytes(abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__Paused.selector))
        );
        sourceTeller.bridge{value: 0.001e18}(
            1e18, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
    }

    function testFeeExceedsMaxReverts() external {
        PairwiseRateLimiterLib.RateLimitConfig[] memory configs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(configs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        uint256 highFee = 2e18;
        endPoint.setFee(NATIVE_ERC20, highFee);

        uint256 maxFee = 1e18;
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    LayerZeroTellerLib.LayerZeroTeller__FeeExceedsMax.selector, DESTINATION_ID, highFee, maxFee
                )
            )
        );
        sourceTeller.bridge{value: highFee}(
            1e18, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, maxFee, ComplianceData(0, "")
        );
    }

    function testReceiveFromWrongSourceChainReverts() external {
        PairwiseRateLimiterLib.RateLimitConfig[] memory outConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        outConfigs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(outConfigs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        PairwiseRateLimiterLib.RateLimitConfig[] memory inConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        inConfigs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: 1_000e18, window: 1 hours});
        destinationTeller.setRateLimits(new PairwiseRateLimiterLib.RateLimitConfig[](0), inConfigs);

        sourceTeller.bridge{value: 0.001e18}(
            1e18, vm.addr(1), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );

        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();

        // Tamper with source chain ID.
        m._origin.srcEid = 7;
        vm.prank(address(endPoint));
        vm.expectRevert();
        LayerZeroTellerWithRateLimiting(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);
    }

    function testReceiveWhilePausedStillWorks() external {
        PairwiseRateLimiterLib.RateLimitConfig[] memory outConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        outConfigs[0] =
            PairwiseRateLimiterLib.RateLimitConfig({peerEid: DESTINATION_ID, limit: 1_000e18, window: 1 hours});
        sourceTeller.setRateLimits(outConfigs, new PairwiseRateLimiterLib.RateLimitConfig[](0));

        PairwiseRateLimiterLib.RateLimitConfig[] memory inConfigs = new PairwiseRateLimiterLib.RateLimitConfig[](1);
        inConfigs[0] = PairwiseRateLimiterLib.RateLimitConfig({peerEid: SOURCE_ID, limit: 1_000e18, window: 1 hours});
        destinationTeller.setRateLimits(new PairwiseRateLimiterLib.RateLimitConfig[](0), inConfigs);

        address to = vm.addr(1);
        sourceTeller.bridge{value: 0.001e18}(
            1e18, to, abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18, ComplianceData(0, "")
        );
        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();

        // Pause destination teller -- messages should still go through.
        destinationTeller.pause();

        vm.prank(address(endPoint));
        LayerZeroTellerWithRateLimiting(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);

        assertEq(boringVault.balanceOf(to), 1e18, "Shares should arrive even when paused.");
    }

    function testVersion() external view {
        string memory v = sourceTeller.version();
        assertEq(
            keccak256(bytes(v)),
            keccak256(bytes("LayerZero Rate Limiting V0.1, Cross Chain V0.1, Base V0.2")),
            "Version string mismatch."
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
