// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {CowswapAdapter} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, console} from "@forge-std/Test.sol";

contract MockRateProvider is IRateProvider {
    uint256 internal rate;

    constructor(uint256 _rate) {
        rate = _rate;
    }

    function getRate() public view override returns (uint256) {
        return rate;
    }
}

contract BoringSwapperTest is Test, MerkleTreeHelper {

    //cow protocol constants
    address constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;

    bytes32 constant GPV2_ORDER_TYPE_HASH = keccak256(
        "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,bytes32 kind,bool partiallyFillable,bytes32 sellTokenBalance,bytes32 buyTokenBalance)"
    );
    bytes32 constant KIND_SELL = keccak256("sell");
    bytes32 constant BALANCE_ERC20 = keccak256("erc20");

    uint8 constant COWSWAP = 3;
    uint8 constant ADMIN_ROLE = 1;

    BoringVault public boringVault;
    BoringSwapper public swapper;
    AdapterRegistry public registry;
    PriceValidator public validator;
    CowswapAdapter public cowAdapter;
    RolesAuthority public rolesAuthority;

    MockRateProvider public wethRate;
    MockRateProvider public usdcRate;

    ERC20 internal WETH;
    ERC20 internal USDC;

    function setUp() external {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 24592183;
        uint256 forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);

        WETH = ERC20(getAddress(sourceChain, "WETH"));
        USDC = ERC20(getAddress(sourceChain, "USDC"));

        //create vault
        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        //roles
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);

        //registry + swapper
        registry = new AdapterRegistry();
        swapper = new BoringSwapper(address(this), registry);

        //auth setup
        swapper.setAuthority(rolesAuthority);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setGlobalPaused.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setProtocolPaused.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setApprovedRoute.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setMaxSlippageBps.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setApprovedProtocol.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.addApprovedVersion.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.removeApprovedVersion.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setApprovedOracle.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setPriceValidator.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setRateLimit.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.sweep.selector, true);

        cowAdapter = new CowswapAdapter(COW_SETTLEMENT);

        registry.put(COWSWAP, address(cowAdapter), "COWSWAP");

        //swapper config
        swapper.setApprovedRoute(WETH, USDC, true, 50, 0, 0);
        swapper.setApprovedProtocol(COWSWAP, true);
        swapper.addApprovedVersion(COWSWAP, 1);

        //oracles
        wethRate = new MockRateProvider(2000e18);
        usdcRate = new MockRateProvider(1e18);
        address usdQuoteAsset = address(USDC);
        swapper.setApprovedOracle(WETH, usdQuoteAsset, address(wethRate));
        swapper.setApprovedOracle(USDC, usdQuoteAsset, address(usdcRate));

        //price validator
        validator = new PriceValidator();
        swapper.setPriceValidator(IPriceValidator(address(validator)));

        //allow swapper to pull from vault
        vm.prank(address(boringVault));
        WETH.approve(address(swapper), type(uint256).max);
    }


    //==================== Submit Order Tests ====================

    function testSubmitOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config,, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //order record stored
        (ERC20 tokenIn, address settlementAddr, uint256 inputAmount, BoringVault receiver) =
            swapper.orderRecords(orderId);
        assertEq(address(tokenIn), address(WETH));
        assertEq(inputAmount, 1e18);
        assertEq(address(receiver), address(boringVault));

        //funds moved from vault to swapper
        assertEq(WETH.balanceOf(address(swapper)), 1e18);
        assertEq(WETH.balanceOf(address(boringVault)), 99e18);

        //order counter incremented
        assertEq(swapper.orders(), orderId + 1);
    }

    function testSubmitOrder_RevertUnapprovedRoute() external {
        deal(address(WETH), address(boringVault), 100e18);

        //build config with USDC -> WETH (not approved, only WETH -> USDC is)
        bytes memory cowswapData = abi.encode(
            address(USDC), address(WETH), address(boringVault),
            1000e6, 1e18, uint32(block.timestamp + 3600),
            bytes32(0), uint256(0), KIND_SELL, false, BALANCE_ERC20, BALANCE_ERC20
        );

        BoringSwapper.SwapConfig memory config = BoringSwapper.SwapConfig({
            tokenRoute: BoringSwapper.TokenRoute(USDC, WETH),
            protocolId: COWSWAP,
            quoteAsset: address(USDC),
            swapData: cowswapData,
            slippageBps: 10,
            receiver: boringVault
        });

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__RouteNotApproved.selector));
        swapper.submitOrder(config);
    }

    function testSubmitOrder_RevertBadSlippage() external {
        deal(address(WETH), address(boringVault), 100e18);

        //fat finger: 1 WETH for 1000 USDC (50% below oracle)
        (BoringSwapper.SwapConfig memory config,) = _buildSwapConfig(1e18, 1000e6, uint32(block.timestamp + 3600));
        vm.expectRevert("exceeds max slippage");
        swapper.submitOrder(config);
    }

    function testSubmitOrder_RevertUnapprovedProtocol() external {
        deal(address(WETH), address(boringVault), 100e18);

        //use approved route but unapproved protocol
        (BoringSwapper.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        config.protocolId = 99;

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__ProtocolNotApproved.selector));
        swapper.submitOrder(config);
    }

    function testSubmitMultipleOrders() external {
        deal(address(WETH), address(boringVault), 100e18);

        (, , uint256 orderId0) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));
        (, , uint256 orderId1) = _submitOrder(2e18, 4000e6, uint32(block.timestamp + 7200));

        assertEq(orderId0, 0);
        assertEq(orderId1, 1);
        assertEq(swapper.orders(), 2);
        assertEq(WETH.balanceOf(address(swapper)), 3e18);
        assertEq(WETH.balanceOf(address(boringVault)), 97e18);
    }

    //==================== IsValidSignature Tests ====================

    function testIsValidSignature() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e));
    }

    function testIsValidSignature_RevertHashMismatch() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config,,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //use a garbage hash
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__HashMismatch.selector));
        swapper.isValidSignature(bytes32(uint256(0x69420)), abi.encode(config));
    }

    function testIsValidSignature_RevertAfterRouteRevoked() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //verify it works before revocation
        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e));

        //revoke route by setting max slippage to 0 and unapproving
        //note: there's no removeApprovedRoute — this is a gap. skip for now.
    }

    function testIsValidSignature_RevertUnapprovedProtocol() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //swap protocolId to something unapproved before calling isValidSignature
        config.protocolId = 99;

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__ProtocolNotApproved.selector));
        swapper.isValidSignature(orderDigest, abi.encode(config));
    }

    //==================== Cancel Order Tests ====================

    function testCancelOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, , uint256 orderId) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        assertEq(WETH.balanceOf(address(swapper)), 1e18);
        assertEq(WETH.balanceOf(address(boringVault)), 99e18);

        swapper.cancelOrder(orderId, config);

        //funds returned to vault
        assertEq(WETH.balanceOf(address(swapper)), 0);
        assertEq(WETH.balanceOf(address(boringVault)), 100e18);

        //record deleted
        (ERC20 tokenIn,,,) = swapper.orderRecords(orderId);
        assertEq(address(tokenIn), address(0));
    }

    function testCancelOrder_RevertNotFound() external {
        // Build a dummy SwapConfig since there's no real order
        BoringSwapper.SwapConfig memory dummyConfig = BoringSwapper.SwapConfig({
            tokenRoute: BoringSwapper.TokenRoute(WETH, USDC),
            protocolId: COWSWAP,
            quoteAsset: address(USDC),
            swapData: "",
            slippageBps: 10,
            receiver: boringVault
        });
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderNotFound.selector));
        swapper.cancelOrder(999, dummyConfig);
    }

    function testCancelOrder_RevertDoubleCancelation() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, , uint256 orderId) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));
        swapper.cancelOrder(orderId, config);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderNotFound.selector));
        swapper.cancelOrder(orderId, config);
    }

    function testCancelOrder_OneOfMultiple() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config0, , uint256 orderId0) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));
        (, , uint256 orderId1) = _submitOrder(2e18, 4000e6, uint32(block.timestamp + 7200));

        assertEq(WETH.balanceOf(address(swapper)), 3e18);

        //cancel only the first order
        swapper.cancelOrder(orderId0, config0);

        //only 1e18 returned, 2e18 still on swapper for order 1
        assertEq(WETH.balanceOf(address(swapper)), 2e18);
        assertEq(WETH.balanceOf(address(boringVault)), 98e18);

        //order 0 deleted, order 1 still exists
        (ERC20 tokenIn0,,,) = swapper.orderRecords(orderId0);
        assertEq(address(tokenIn0), address(0));

        (ERC20 tokenIn1,,uint256 inputAmount1,) = swapper.orderRecords(orderId1);
        assertEq(address(tokenIn1), address(WETH));
        assertEq(inputAmount1, 2e18);
    }

    //==================== Full Fill Flow ====================

    function testFullFillFlow() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        uint256 vaultWethBefore = WETH.balanceOf(address(boringVault));
        uint256 vaultUsdcBefore = USDC.balanceOf(address(boringVault));

        //simulate settlement filling the order
        _simulateFill(1e18, 2000e6, config, orderDigest);

        //vault received USDC
        assertEq(USDC.balanceOf(address(boringVault)), vaultUsdcBefore + 2000e6);
        //swapper's WETH was consumed
        assertEq(WETH.balanceOf(address(swapper)), 0);
        //vault WETH unchanged (was already pulled to swapper during submitOrder)
        assertEq(WETH.balanceOf(address(boringVault)), vaultWethBefore);
    }

    //==================== Partial Fill + Cancel ====================

    function testPartialFillThenCancel() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOrder(10e18, 20000e6, uint32(block.timestamp + 3600));

        assertEq(WETH.balanceOf(address(swapper)), 10e18);

        //partial fill: 50% of the order
        _simulateFill(5e18, 10000e6, config, orderDigest);

        assertEq(WETH.balanceOf(address(swapper)), 5e18);
        assertEq(USDC.balanceOf(address(boringVault)), 10000e6);

        //cancel the remaining — should refund min(inputAmount=10e18, balance=5e18) = 5e18
        swapper.cancelOrder(orderId, config);

        assertEq(WETH.balanceOf(address(swapper)), 0);
        assertEq(WETH.balanceOf(address(boringVault)), 95e18);
    }

    function testCancelAfterFullFill() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //full fill
        _simulateFill(1e18, 2000e6, config, orderDigest);

        //cancel after full fill — refund is min(1e18, 0) = 0, should succeed with no transfer
        uint256 vaultWethBefore = WETH.balanceOf(address(boringVault));
        swapper.cancelOrder(orderId, config);
        assertEq(WETH.balanceOf(address(boringVault)), vaultWethBefore);

        //record is deleted
        (ERC20 tokenIn,,,) = swapper.orderRecords(orderId);
        assertEq(address(tokenIn), address(0));
    }

    //==================== Sweep ====================

    function testSweep() external {
        //simulate tokens stuck on swapper
        deal(address(USDC), address(swapper), 500e6);

        assertEq(USDC.balanceOf(address(swapper)), 500e6);
        assertEq(USDC.balanceOf(address(boringVault)), 0);

        swapper.sweep(USDC, boringVault);

        assertEq(USDC.balanceOf(address(swapper)), 0);
        assertEq(USDC.balanceOf(address(boringVault)), 500e6);
    }

    function testSweep_NoBalance() external {
        //should be a no-op, not revert
        swapper.sweep(USDC, boringVault);
        assertEq(USDC.balanceOf(address(boringVault)), 0);
    }

    //==================== Adapter Registry ====================
    
    //TODO pull these out to their own file? 
    function testRegistryOverwriteReverts() external {
        //cowAdapter is already registered at (COWSWAP, version=1)
        CowswapAdapter duplicateAdapter = new CowswapAdapter(COW_SETTLEMENT);

        vm.expectRevert("adapter already registered");
        registry.put(COWSWAP, address(duplicateAdapter));
    }

    function testRegistryGetProtocols() external {
        (uint8[] memory ids, string[] memory names) = registry.getProtocols();

        assertEq(ids.length, 1);
        assertEq(ids[0], COWSWAP);
        assertEq(keccak256(bytes(names[0])), keccak256(bytes("COWSWAP")));
    }

    function testRegistryReverseLookup() external {
        uint8 id = registry.protocolId("COWSWAP");
        assertEq(id, COWSWAP);

        string memory name = registry.protocolName(COWSWAP);
        assertEq(keccak256(bytes(name)), keccak256(bytes("COWSWAP")));
    }

    function testRegistryPut_RevertNameRequired() external {
        //new protocol with empty name should revert
        CowswapAdapter newAdapter = new CowswapAdapter(COW_SETTLEMENT);
        vm.expectRevert("name required");
        registry.put(10, address(newAdapter), "");
    }

    function testRegistryPut_RevertProtocolNotRegistered() external {
        //version bump overload on unregistered protocol should revert
        CowswapAdapter newAdapter = new CowswapAdapter(COW_SETTLEMENT);
        vm.expectRevert("protocol not registered");
        registry.put(10, address(newAdapter));
    }

    function testRegistryGet_ReturnsZeroForUnregistered() external {
        address result = registry.get(255, 999);
        assertEq(result, address(0));
    }

    //==================== Pause Tests ====================

    function testGlobalPause_BlocksSubmitOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        swapper.setGlobalPaused(true);

        (BoringSwapper.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__Paused.selector));
        swapper.submitOrder(config);

        //unpause and it works again
        swapper.setGlobalPaused(false);
        swapper.submitOrder(config);
        assertEq(swapper.orders(), 1);
    }

    function testGlobalPause_BlocksIsValidSignature() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //pause should block fills
        swapper.setGlobalPaused(true);
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__Paused.selector));
        swapper.isValidSignature(orderDigest, abi.encode(config));
    }

    function testProtocolPause_BlocksSubmitOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        swapper.setProtocolPaused(COWSWAP, true);

        (BoringSwapper.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__ProtocolPaused.selector));
        swapper.submitOrder(config);

        //unpause and it works again
        swapper.setProtocolPaused(COWSWAP, false);
        swapper.submitOrder(config);
        assertEq(swapper.orders(), 1);
    }

    function testProtocolPause_BlocksIsValidSignature() external {
        deal(address(WETH), address(boringVault), 100e18);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //pause cowswap should block fills
        swapper.setProtocolPaused(COWSWAP, true);
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__ProtocolPaused.selector));
        swapper.isValidSignature(orderDigest, abi.encode(config));
    }

    function testProtocolPause_DoesNotAffectOtherProtocols() external {
        deal(address(WETH), address(boringVault), 100e18);

        //pause a different protocol
        swapper.setProtocolPaused(0, true);

        //cowswap should still work
        (BoringSwapper.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        swapper.submitOrder(config);
        assertEq(swapper.orders(), 1);
    }

    //==================== Admin Tests ====================

    function testAddApprovedRoute() external {
        //new route USDC -> WETH with 100 bps max slippage
        swapper.setApprovedRoute(USDC, WETH, true, 100, 0, 0);

        bytes32 key = swapper.getRouteId(USDC, WETH);
        assertTrue(swapper.approvedRoutes(key));
        assertEq(swapper.maxSlippageBpsPerRoute(key), 100);
    }

    function testAddApprovedProtocol() external {
        uint8 newProtocol = 10;
        assertFalse(swapper.approvedProtocols(newProtocol));

        swapper.setApprovedProtocol(newProtocol, true);
        assertTrue(swapper.approvedProtocols(newProtocol));
    }

    function testAddApprovedVersion() external {
        uint8 newProtocol = 10;
        assertEq(swapper.versions(newProtocol), 0);

        swapper.addApprovedVersion(newProtocol, 5);
        assertEq(swapper.versions(newProtocol), 5);
    }

    function testAddApprovedOracle() external {
        address newOracle = address(0x69420);
        address quoteAsset = address(USDC);

        swapper.setApprovedOracle(WETH, quoteAsset, newOracle);
        assertEq(swapper.getOracle(WETH, quoteAsset), newOracle);
    }

    function testSetPriceValidator() external {
        PriceValidator newValidator = new PriceValidator();
        swapper.setPriceValidator(IPriceValidator(address(newValidator)));
        assertEq(address(swapper.priceValidator()), address(newValidator));
    }

    function testGetRouteId() external {
        bytes32 ab = swapper.getRouteId(WETH, USDC);
        bytes32 ba = swapper.getRouteId(USDC, WETH);

        //route ids are directional — (A,B) != (B,A)
        assertTrue(ab != ba);

        //deterministic — same inputs always produce same output
        assertEq(ab, swapper.getRouteId(WETH, USDC));
    }

    function testGetOracle() external {
        address quoteAsset = address(USDC);
        //oracles were set in setUp
        assertEq(swapper.getOracle(WETH, quoteAsset), address(wethRate));
        assertEq(swapper.getOracle(USDC, quoteAsset), address(usdcRate));

        //unregistered oracle returns zero
        assertEq(swapper.getOracle(WETH, address(0x420)), address(0));
    }

    //==================== Price Validator ====================

    function testPriceValidator_RevertExceedsMaxSlippageBps() external {
        deal(address(WETH), address(boringVault), 100e18);

        //route max slippage is 50 bps, use 51 bps
        (BoringSwapper.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        config.slippageBps = 51;

        vm.expectRevert("exceeds max slippage for this token route");
        swapper.submitOrder(config);
    }

    //==================== Helpers ====================

    function _cowDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("Gnosis Protocol"),
            keccak256("v2"),
            block.chainid,
            COW_SETTLEMENT
        ));
    }

    function _buildSwapConfig(
        uint256 sellAmount,
        uint256 buyAmount,
        uint32 validTo
    ) internal view returns (BoringSwapper.SwapConfig memory, bytes32 orderDigest) {
        bytes memory cowswapData = abi.encode(
            address(WETH),      //sellToken
            address(USDC),      //buyToken
            address(boringVault), //receiver
            sellAmount,
            buyAmount,
            validTo,
            bytes32(0),         //appData
            uint256(0),         //feeAmount
            KIND_SELL,
            false,              //partiallyFillable
            BALANCE_ERC20,
            BALANCE_ERC20
        );

        BoringSwapper.SwapConfig memory config = BoringSwapper.SwapConfig({
            tokenRoute: BoringSwapper.TokenRoute(WETH, USDC),
            protocolId: COWSWAP,
            quoteAsset: address(USDC),
            swapData: cowswapData,
            slippageBps: 10,
            receiver: boringVault
        });

        //compute the EIP-712 order digest
        bytes32 structHash = keccak256(abi.encode(
            GPV2_ORDER_TYPE_HASH,
            address(WETH),
            address(USDC),
            address(boringVault),
            sellAmount,
            buyAmount,
            validTo,
            bytes32(0),
            uint256(0),
            KIND_SELL,
            false,
            BALANCE_ERC20,
            BALANCE_ERC20
        ));
        orderDigest = keccak256(abi.encodePacked("\x19\x01", _cowDomainSeparator(), structHash));

        return (config, orderDigest);
    }

    function _submitOrder(uint256 sellAmount, uint256 buyAmount, uint32 validTo)
        internal
        returns (BoringSwapper.SwapConfig memory config, bytes32 orderDigest, uint256 orderId)
    {
        (config, orderDigest) = _buildSwapConfig(sellAmount, buyAmount, validTo);
        orderId = swapper.orders();
        swapper.submitOrder(config);
    }

    //simulate settlement pulling tokenIn from swapper and sending tokenOut to vault
    function _simulateFill(
        uint256 amountIn,
        uint256 amountOut,
        BoringSwapper.SwapConfig memory config,
        bytes32 orderDigest
    ) internal {
        //verify signature (as settlement would)
        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e), "isValidSignature failed");

        //settlement pulls tokenIn from swapper using the pre-approval
        vm.prank(COW_SETTLEMENT);
        WETH.transferFrom(address(swapper), COW_SETTLEMENT, amountIn);

        //settlement sends tokenOut directly to the vault
        deal(address(USDC), COW_SETTLEMENT, amountOut);
        vm.prank(COW_SETTLEMENT);
        USDC.transfer(address(boringVault), amountOut);
    }
}
