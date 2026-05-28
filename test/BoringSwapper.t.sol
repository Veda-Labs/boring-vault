// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {CowswapAdapter} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";
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

    // Mirror events for vm.expectEmit (emit ContractName.Event crashes solc 0.8.21 NatSpec)
    event OrderCancelled(uint256 indexed orderId, uint256 refundAmount);
    event OrderSubmitted(uint256 indexed orderId, bytes32 indexed routeId, uint256 amountIn, address indexed receiver);
    event LimitFeeToggleUpdated(address indexed swapper, bool active);
    event MaxFeeBpsUpdated(uint16 newMaxFeeBps);

    //cow protocol constants
    address constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    bytes32 constant GPV2_ORDER_TYPE_HASH = keccak256(
        "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,string kind,bool partiallyFillable,string sellTokenBalance,string buyTokenBalance)"
    );
    bytes32 constant KIND_SELL = keccak256("sell");
    bytes32 constant BALANCE_ERC20 = keccak256("erc20");

    uint8 constant ADMIN_ROLE = 1;

    BoringVault public boringVault;
    BoringSwapper public swapper;
    AdapterRegistry public registry;
    PriceValidator public validator;
    CowswapAdapter public cowAdapter;
    RolesAuthority public rolesAuthority;
    FeeRegistry public feeRegistry;

    MockRateProvider public wethRate;
    MockRateProvider public usdcRate;
    MockRateProvider public steth_ethRate;

    ERC20 internal WETH;
    ERC20 internal USDC;
    ERC20 internal STETH;

    function setUp() external {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 24592183;
        uint256 forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);

        WETH = ERC20(getAddress(sourceChain, "WETH"));
        USDC = ERC20(getAddress(sourceChain, "USDC"));
        STETH = ERC20(getAddress(sourceChain, "WSTETH"));

        //create vault
        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        //roles
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);

        //registry + swapper
        registry = new AdapterRegistry();
        feeRegistry = new FeeRegistry(address(this), 1000);
        validator = new PriceValidator();
        swapper = new BoringSwapper(address(this), registry, feeRegistry, boringVault, IPriceValidator(address(validator)));

        //auth setup
        swapper.setAuthority(rolesAuthority);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.pause.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.unpause.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setAdapterPaused.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setRouteConfig.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setMaxSlippageBps.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setApprovedAdapter.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setTokenOracle.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setBaseAssetOracle.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setPriceValidator.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setRateLimit.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.sweep.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.setFeeRegistry.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.swap.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.submitOrder.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.cancelOrder.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.replaceOrder.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.releaseFee.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(swapper), BoringSwapper.claimFees.selector, true);

        cowAdapter = new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER);

        registry.put(address(cowAdapter), "COWSWAP");

        //swapper config
        swapper.setRouteConfig(WETH, USDC, 50, 0, 0);
        swapper.setRouteConfig(STETH, USDC, 500, 0, 0);
        swapper.setApprovedAdapter(address(cowAdapter), true);

        //oracles
        wethRate = new MockRateProvider(2000e18); //in USD
        usdcRate = new MockRateProvider(1e18); //USD
        steth_ethRate = new MockRateProvider(1.1e18); //in ETH
        address usdQuoteAsset = address(USDC);

        swapper.setTokenOracle(WETH,  usdQuoteAsset, _makeOracleConfig(address(wethRate), address(0), false));
        swapper.setTokenOracle(USDC,  usdQuoteAsset, _makeOracleConfig(address(usdcRate), address(0), false));
        swapper.setTokenOracle(STETH, usdQuoteAsset, _makeOracleConfig(address(steth_ethRate), address(WETH), false));

        swapper.setBaseAssetOracle(WETH, usdQuoteAsset, _toArray(address(wethRate)));
        swapper.setBaseAssetOracle(USDC, usdQuoteAsset, _toArray(address(usdcRate)));  

        //allow swapper to pull from vault
        vm.startPrank(address(boringVault));
        WETH.approve(address(swapper), type(uint256).max);
        STETH.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }


    //==================== Submit Order Tests ====================

    function testSubmitOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //order record stored
        BoringSwapper.OrderRecord memory rec = swapper.getOrderRecord(orderId);
        assertEq(address(rec.tokenIn), address(WETH));
        assertEq(rec.inputAmount, 1e18);
        assertEq(address(rec.receiver), address(boringVault));

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

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(USDC, WETH),
            adapter: address(cowAdapter),
            quoteAsset: address(USDC),
            swapData: cowswapData,
            slippageBps: 10,
            receiver: boringVault
        });

        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__ExceedsRouteMaxSlippage.selector));
        swapper.submitOrder(config);
    }

    function testSubmitOrder_RevertBadSlippage() external {
        deal(address(WETH), address(boringVault), 100e18);

        //fat finger: 1 WETH for 1000 USDC (50% below oracle)
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 1000e6, uint32(block.timestamp + 3600));
        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector));
        swapper.submitOrder(config);
    }

    function testSubmitOrder_RevertUnapprovedProtocol() external {
        deal(address(WETH), address(boringVault), 100e18);

        //use approved route but unapproved protocol
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        config.adapter = address(0xdead);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__AdapterNotApproved.selector));
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

    // Byte-identical resubmissions are rejected. Backend retries must vary validTo / salt / appData
    // so the EIP-712 hash differs; otherwise the second submission would reuse the same approvedHash
    // slot — pointing two orderIds at one protocol-side order and breaking the cancel/release accounting.
    function testSubmitOrder_RevertDuplicateOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        uint32 validTo = uint32(block.timestamp + 3600);
        _submitOrder(1e18, 2000e6, validTo);

        (ISwapperTypes.SwapConfig memory dupConfig,) = _buildSwapConfig(1e18, 2000e6, validTo);
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__DuplicateOrder.selector));
        swapper.submitOrder(dupConfig);
    }

    // Sanity check that varying validTo defeats the duplicate guard — confirms the rejection is
    // hash-based, not e.g. tokenIn/inputAmount-based.
    function testSubmitOrder_DistinctValidToSucceeds() external {
        deal(address(WETH), address(boringVault), 100e18);

        _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));
        _submitOrder(1e18, 2000e6, uint32(block.timestamp + 7200));

        assertEq(swapper.orders(), 2);
    }

    //==================== IsValidSignature Tests ====================

    function testIsValidSignature() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));
        
        vm.prank(COW_SETTLEMENT);
        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e));
    }

    function testIsValidSignature_RevertHashMismatch() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 digest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //use a garbage hash
        vm.expectRevert(abi.encodeWithSelector(
            BoringSwapper.BoringSwapper__HashMismatch.selector,
            digest,  // the real protocol hash
            bytes32(uint256(0x69420))  // the garbage hash you passed
        ));
        vm.prank(COW_SETTLEMENT);
        swapper.isValidSignature(bytes32(uint256(0x69420)), abi.encode(config));
    }

    function testIsValidSignature_RevertAfterRouteRevoked() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //verify it works before revocation
        vm.prank(COW_SETTLEMENT);
        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e));

        //revoke route by setting max slippage to 0 and unapproving
        //note: there's no removeApprovedRoute — this is a gap. skip for now.
    }

    function testIsValidSignature_RevertUnapprovedProtocol() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //swap adapter to something unapproved before calling isValidSignature
        config.adapter = address(0xdead);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__AdapterNotApproved.selector));
        swapper.isValidSignature(orderDigest, abi.encode(config));
    }

    //==================== Cancel Order Tests ====================

    function testCancelOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, , uint256 orderId) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        assertEq(WETH.balanceOf(address(swapper)), 1e18);
        assertEq(WETH.balanceOf(address(boringVault)), 99e18);

        swapper.cancelOrder(orderId, config, "");

        //funds returned to vault
        assertEq(WETH.balanceOf(address(swapper)), 0);
        assertEq(WETH.balanceOf(address(boringVault)), 100e18);

        //record marked as cancelled (preserved until releaseFee)
        BoringSwapper.OrderRecord memory rec = swapper.getOrderRecord(orderId);
        assertEq(address(rec.tokenIn), address(WETH));
        assertGt(rec.cancelledAt, 0);
    }

    function testCancelOrder_RevertNotFound() external {
        // Build a dummy SwapConfig since there's no real order
        ISwapperTypes.SwapConfig memory dummyConfig = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(WETH, USDC),
            adapter: address(cowAdapter),
            quoteAsset: address(USDC),
            swapData: "",
            slippageBps: 10,
            receiver: boringVault
        });
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderNotFound.selector));
        swapper.cancelOrder(999, dummyConfig, "");
    }

    function testCancelOrder_RevertDoubleCancelation() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, , uint256 orderId) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));
        swapper.cancelOrder(orderId, config, "");

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__AlreadyCancelled.selector));
        swapper.cancelOrder(orderId, config, "");
    }

    function testCancelOrder_OneOfMultiple() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config0, , uint256 orderId0) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));
        (, , uint256 orderId1) = _submitOrder(2e18, 4000e6, uint32(block.timestamp + 7200));

        assertEq(WETH.balanceOf(address(swapper)), 3e18);

        //cancel only the first order
        swapper.cancelOrder(orderId0, config0, "");

        //only 1e18 returned, 2e18 still on swapper for order 1
        assertEq(WETH.balanceOf(address(swapper)), 2e18);
        assertEq(WETH.balanceOf(address(boringVault)), 98e18);

        //order 0 marked cancelled (record preserved), order 1 still pending
        BoringSwapper.OrderRecord memory rec0 = swapper.getOrderRecord(orderId0);
        assertEq(address(rec0.tokenIn), address(WETH));
        assertGt(rec0.cancelledAt, 0);

        BoringSwapper.OrderRecord memory rec1 = swapper.getOrderRecord(orderId1);
        assertEq(rec1.cancelledAt, 0);
        assertEq(address(rec1.tokenIn), address(WETH));
        assertEq(rec1.inputAmount, 2e18);
    }

    //==================== Full Fill Flow ====================

    function testFullFillFlow() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
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

    // Any non-zero `filledAmount` on CoW means the order is no longer cancellable. The CoW adapter
    // rejects partial-fill orders at submit, so the only path to a non-zero `filledAmount` is a real
    // settlement — and once that lands, the swapper's adapter-driven isFilled blocks cancel.
    function testCancelAfterPartialFill_RevertOrderAlreadyFilled() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOrder(10e18, 20000e6, uint32(block.timestamp + 3600));

        _simulateFill(5e18, 10000e6, config, orderDigest);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderAlreadyFilled.selector));
        swapper.cancelOrder(orderId, config, "");
    }

    function testCancelAfterFullFill_RevertOrderAlreadyFilled() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        _simulateFill(1e18, 2000e6, config, orderDigest);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderAlreadyFilled.selector));
        swapper.cancelOrder(orderId, config, "");
    }

    //==================== Rate Limit Tests ====================

    function testRateLimit_ConsumedOnSubmit() external {
        deal(address(WETH), address(boringVault), 100e18);
        bytes32 routeKey = swapper.getRouteId(WETH, USDC);

        // 10 normalized tokens capacity, no refill
        swapper.setRateLimit(routeKey, 10e18, 0);

        _submitOrder(3e18, 6000e6, uint32(block.timestamp + 3600));

        // 3 WETH (18 dec): (3e18 * 1e18) / 1e18 = 3e18 normalized consumed
        (, uint256 remaining,,) = swapper.rateLimitPerRoute(routeKey);
        assertEq(remaining, 7e18);
    }

    function testRateLimit_ExceededReverts() external {
        deal(address(WETH), address(boringVault), 100e18);
        bytes32 routeKey = swapper.getRouteId(WETH, USDC);

        swapper.setRateLimit(routeKey, 2e18, 0);

        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(3e18, 6000e6, uint32(block.timestamp + 3600));
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__RateLimitExceeded.selector));
        swapper.submitOrder(config);
    }

    function testRateLimit_RestoredOnCancel() external {
        deal(address(WETH), address(boringVault), 100e18);
        bytes32 routeKey = swapper.getRouteId(WETH, USDC);

        swapper.setRateLimit(routeKey, 5e18, 0);

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) = _submitOrder(3e18, 6000e6, uint32(block.timestamp + 3600));

        (, uint256 remaining,,) = swapper.rateLimitPerRoute(routeKey);
        assertEq(remaining, 2e18);

        swapper.cancelOrder(orderId, config, "");

        (, remaining,,) = swapper.rateLimitPerRoute(routeKey);
        assertEq(remaining, 5e18); // fully restored, capped at capacity
    }

    function testRateLimit_RefillsOverTime() external {
        deal(address(WETH), address(boringVault), 100e18);
        bytes32 routeKey = swapper.getRouteId(WETH, USDC);

        // capacity 10 WETH, refill at 1 normalized token/sec
        swapper.setRateLimit(routeKey, 10e18, 1e18);

        _submitOrder(10e18, 20000e6, uint32(block.timestamp + 3600));

        (, uint256 remaining,,) = swapper.rateLimitPerRoute(routeKey);
        assertEq(remaining, 0);

        // warp 5 seconds → 5e18 refilled, then consume 3e18
        vm.warp(block.timestamp + 5);
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(3e18, 6000e6, uint32(block.timestamp + 7200));
        swapper.submitOrder(config);

        (, remaining,,) = swapper.rateLimitPerRoute(routeKey);
        assertEq(remaining, 2e18); // 5e18 refilled - 3e18 consumed
    }

    function testRateLimit_Normalization() external {
        deal(address(WETH), address(boringVault), 100e18);
        bytes32 routeKey = swapper.getRouteId(WETH, USDC);

        // capacity of exactly 1 normalized token
        swapper.setRateLimit(routeKey, 1e18, 0);

        // 1 WETH (18 dec): (1e18 * 1e18) / 1e18 = 1e18 — exactly exhausts bucket
        _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        (, uint256 remaining,,) = swapper.rateLimitPerRoute(routeKey);
        assertEq(remaining, 0);

        // bucket empty — any further submit reverts
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 7200));
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__RateLimitExceeded.selector));
        swapper.submitOrder(config);
    }

    //==================== Sweep ====================

    function testSweep() external {
        //simulate tokens stuck on swapper
        deal(address(USDC), address(swapper), 500e6);

        assertEq(USDC.balanceOf(address(swapper)), 500e6);
        assertEq(USDC.balanceOf(address(boringVault)), 0);

        swapper.sweep(USDC);

        assertEq(USDC.balanceOf(address(swapper)), 0);
        assertEq(USDC.balanceOf(address(boringVault)), 500e6);
    }

    function testSweep_NoBalance() external {
        //should be a no-op, not revert
        swapper.sweep(USDC);
        assertEq(USDC.balanceOf(address(boringVault)), 0);
    }

    //==================== Adapter Registry ====================
    
    //TODO pull these out to their own file? 
    function testRegistryOverwriteReverts() external {
        CowswapAdapter duplicateAdapter = new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER);
        registry.put(address(duplicateAdapter), "COWSWAP_V2");

        vm.expectRevert(AdapterRegistry.AdapterRegistry__AlreadyRegistered.selector);
        registry.put(address(duplicateAdapter), "COWSWAP_V2");
    }

    function testRegistryGetAdapters() external {
        (address[] memory addrs, string[] memory names) = registry.getAdapters();

        assertEq(addrs.length, 1);
        assertEq(addrs[0], address(cowAdapter));
        assertEq(keccak256(bytes(names[0])), keccak256(bytes("COWSWAP")));
    }

    function testRegistryNameLookup() external {
        string memory name = registry.adapterName(address(cowAdapter));
        assertEq(keccak256(bytes(name)), keccak256(bytes("COWSWAP")));
    }

    function testRegistryPut_RevertNameRequired() external {
        CowswapAdapter newAdapter = new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER);
        vm.expectRevert(AdapterRegistry.AdapterRegistry__NameRequired.selector);
        registry.put(address(newAdapter), "");
    }

    function testRegistryRemove() external {
        registry.remove(address(cowAdapter));
        assertFalse(registry.registeredAdapters(address(cowAdapter)));
        (address[] memory addrs,) = registry.getAdapters();
        assertEq(addrs.length, 0);
    }

    function testRegistryRemove_RevertNotRegistered() external {
        vm.expectRevert(AdapterRegistry.AdapterRegistry__NotRegistered.selector);
        registry.remove(address(0xdead));
    }

    //==================== Pause Tests ====================

    function testGlobalPause_BlocksSubmitOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        swapper.pause();

        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__Paused.selector));
        swapper.submitOrder(config);

        //unpause and it works again
        swapper.unpause();
        swapper.submitOrder(config);
        assertEq(swapper.orders(), 1);
    }

    function testGlobalPause_BlocksIsValidSignature() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //pause should block fills
        swapper.pause();
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__Paused.selector));
        swapper.isValidSignature(orderDigest, abi.encode(config));
    }

    function testProtocolPause_BlocksSubmitOrder() external {
        deal(address(WETH), address(boringVault), 100e18);

        swapper.setAdapterPaused(address(cowAdapter), true);

        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__AdapterPaused.selector));
        swapper.submitOrder(config);

        //unpause and it works again
        swapper.setAdapterPaused(address(cowAdapter), false);
        swapper.submitOrder(config);
        assertEq(swapper.orders(), 1);
    }

    function testProtocolPause_BlocksIsValidSignature() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        //pause cowswap should block fills
        swapper.setAdapterPaused(address(cowAdapter), true);
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__AdapterPaused.selector));
        swapper.isValidSignature(orderDigest, abi.encode(config));
    }

    function testProtocolPause_DoesNotAffectOtherProtocols() external {
        deal(address(WETH), address(boringVault), 100e18);

        //pause a different adapter (not cowswap)
        CowswapAdapter otherAdapter = new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER);
        swapper.setAdapterPaused(address(otherAdapter), true);

        //cowswap should still work
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        swapper.submitOrder(config);
        assertEq(swapper.orders(), 1);
    }

    //==================== Admin Tests ====================

    function testSetRouteConfig() external {
        //new route USDC -> WETH with 100 bps max slippage
        swapper.setRouteConfig(USDC, WETH, 100, 0, 0);

        bytes32 key = swapper.getRouteId(USDC, WETH);
        assertEq(swapper.maxSlippageBpsPerRoute(key), 100);
    }

    function testAddApprovedAdapter() external {
        CowswapAdapter newAdapter = new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER);
        registry.put(address(newAdapter), "COWSWAP_V2");

        assertFalse(swapper.approvedAdapters(address(newAdapter)));
        swapper.setApprovedAdapter(address(newAdapter), true);
        assertTrue(swapper.approvedAdapters(address(newAdapter)));
    }

    function testSetTokenOracle() external {
        address newOracle = address(0x69420);
        address quoteAsset = address(USDC);

        swapper.setTokenOracle(WETH, quoteAsset, _makeOracleConfig(newOracle, address(0), false));
        (address[] memory rateProviders, address[] memory intermediaries, bool skipValidation) = swapper.getBaseAssetOracle(WETH, quoteAsset);
        assertEq(rateProviders[0], newOracle);
        assertEq(intermediaries[0], address(0));
        assertEq(skipValidation, false);
    }

    function testSetTokenOracleWithIntermediary() external {
        address newOracle = address(0x69420); //steth/eth oracle
        address quoteAsset = address(USDC);

        swapper.setTokenOracle(STETH, quoteAsset, _makeOracleConfig(newOracle, address(WETH), false));
        (address[] memory rateProviders, address[] memory intermediaries, bool skipValidation) = swapper.getBaseAssetOracle(STETH, quoteAsset);
        assertEq(rateProviders[0], newOracle);
        assertEq(intermediaries[0], address(WETH));
        assertEq(skipValidation, false);
    }

    function testSetBaseAssetOracle() external {
        address newOracle = address(0x69420);
        address quoteAsset = address(USDC);

        swapper.setBaseAssetOracle(WETH, quoteAsset, _toArray(newOracle));
        assertEq(swapper.oracles(WETH, quoteAsset, 0), newOracle);
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

    function testGetOracles() external {
        address quoteAsset = address(USDC);

        //oracles were set in setUp via setTokenOracle
        (address[] memory wethRateProviders, address[] memory wethIntermediaries, bool wethSkip) = swapper.getBaseAssetOracle(WETH, quoteAsset);
        assertEq(wethRateProviders[0], address(wethRate));
        assertEq(wethIntermediaries[0], address(0));
        assertEq(wethSkip, false);

        (address[] memory usdcRateProviders, address[] memory usdcIntermediaries, bool usdcSkip) = swapper.getBaseAssetOracle(USDC, quoteAsset);
        assertEq(usdcRateProviders[0], address(usdcRate));
        assertEq(usdcIntermediaries[0], address(0));
        assertEq(usdcSkip, false);

        //unregistered oracle returns empty arrays
        (address[] memory emptyProviders,,) = swapper.getBaseAssetOracle(ERC20(address(0x420)), quoteAsset);
        assertEq(emptyProviders.length, 0);
    }

    //==================== Price Validator ====================
    
    function testPriceValidator_TwoHopTrade() external {
        deal(address(STETH), address(boringVault), 100e18);
        address usdQuoteAsset = address(USDC);
        
        //submit a 2 hop trade
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2200e6, uint32(block.timestamp + 3600), address(STETH));
        swapper.submitOrder(config);
    }

    function testPriceValidator_RevertTwoHopTrade() external {
        deal(address(STETH), address(boringVault), 100e18);
        address usdQuoteAsset = address(USDC);
        
        //submit a 2 hop trade
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600), address(STETH));
        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector));
        swapper.submitOrder(config);
    }

    function testPriceValidator_RevertExceedsMaxSlippageBps() external {
        deal(address(WETH), address(boringVault), 100e18);

        //route max slippage is 50 bps, use 51 bps
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        config.slippageBps = 51;

        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__ExceedsRouteMaxSlippage.selector));
        swapper.submitOrder(config);
    }

    function testPriceValidator_RevertNotConfigured() external {
        deal(address(WETH), address(boringVault), 100e18);
        address usdQuoteAsset = address(USDC);

        //overwrite any oracles
        swapper.setTokenOracle(WETH, usdQuoteAsset, _makeOracleConfig(address(0), address(0), false)); //should not skip, should revert
        (ISwapperTypes.SwapConfig memory config,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));

        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__OracleNotConfigured.selector));
        swapper.submitOrder(config);
    }

    //==================== Replace Swap Tests ====================

    function testReplaceSwap() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory oldConfig,, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        assertEq(WETH.balanceOf(address(swapper)), 1e18);
        assertEq(WETH.balanceOf(address(boringVault)), 99e18);

        (ISwapperTypes.SwapConfig memory newConfig,) =
            _buildSwapConfig(2e18, 4000e6, uint32(block.timestamp + 7200));

        uint256 newOrderId = swapper.orders();
        swapper.replaceOrder(orderId, oldConfig, "", newConfig);

        // old order record marked cancelled (preserved until releaseFee)
        BoringSwapper.OrderRecord memory oldRec = swapper.getOrderRecord(orderId);
        assertEq(address(oldRec.tokenIn), address(WETH));
        assertGt(oldRec.cancelledAt, 0);

        // new order record exists with correct data
        BoringSwapper.OrderRecord memory newRec = swapper.getOrderRecord(newOrderId);
        assertEq(newRec.cancelledAt, 0);
        assertEq(address(newRec.tokenIn), address(WETH));
        assertEq(newRec.inputAmount, 2e18);

        // old 1e18 returned, new 2e18 pulled
        assertEq(WETH.balanceOf(address(swapper)), 2e18);
        assertEq(WETH.balanceOf(address(boringVault)), 98e18);

        // order counter incremented
        assertEq(swapper.orders(), newOrderId + 1);
    }

    function testReplaceSwap_OldHashInvalidated() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory oldConfig, bytes32 oldDigest, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        (ISwapperTypes.SwapConfig memory newConfig,) =
            _buildSwapConfig(2e18, 4000e6, uint32(block.timestamp + 7200));

        swapper.replaceOrder(orderId, oldConfig, "", newConfig);

        // old hash removed from approvedHashes
        assertFalse(swapper.approvedHashes(oldDigest));

        // isValidSignature with old order should revert as unapproved
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderNotApproved.selector));
        vm.prank(COW_SETTLEMENT);
        swapper.isValidSignature(oldDigest, abi.encode(oldConfig));
    }

    function testReplaceSwap_NewHashValid() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory oldConfig,, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        (ISwapperTypes.SwapConfig memory newConfig, bytes32 newDigest) =
            _buildSwapConfig(2e18, 4000e6, uint32(block.timestamp + 7200));

        swapper.replaceOrder(orderId, oldConfig, "", newConfig);

        // new hash is approved
        assertTrue(swapper.approvedHashes(newDigest));

        // settlement can validate the new order
        vm.prank(COW_SETTLEMENT);
        bytes4 result = swapper.isValidSignature(newDigest, abi.encode(newConfig));
        assertEq(result, bytes4(0x1626ba7e));
    }


    function testReplaceSwap_RevertOrderNotFound() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory cancelConfig,) = _buildSwapConfig(1e18, 2000e6, uint32(block.timestamp + 3600));
        (ISwapperTypes.SwapConfig memory newConfig,) = _buildSwapConfig(2e18, 4000e6, uint32(block.timestamp + 7200));

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderNotFound.selector));
        swapper.replaceOrder(999, cancelConfig, "", newConfig);
    }

    function testReplaceSwap_EmitsEvents() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory oldConfig,, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        (ISwapperTypes.SwapConfig memory newConfig,) =
            _buildSwapConfig(2e18, 4000e6, uint32(block.timestamp + 7200));

        uint256 newOrderId = swapper.orders();
        bytes32 routeId = swapper.getRouteId(WETH, USDC);

        vm.expectEmit(true, false, false, true, address(swapper));
        emit OrderCancelled(orderId, 1e18);

        vm.expectEmit(true, true, true, true, address(swapper));
        emit OrderSubmitted(newOrderId, routeId, 2e18, address(boringVault));

        swapper.replaceOrder(orderId, oldConfig, "", newConfig);
    }

    //==================== FeeRegistry Unit Tests ====================

    function testFeeRegistry_SameGroup() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        feeRegistry.setTokenGroup(address(this), address(USDC), 1);
        feeRegistry.setTokenGroup(address(this), address(WETH), 1);
        feeRegistry.setLimitGroupPairFee(address(this), 1, 1, 5);
        feeRegistry.setDefaultFeeRecipient(address(this), address(0x69));

        uint16 feeBps = feeRegistry.getLimitFee(address(this), address(USDC), address(WETH));
        address recipient = feeRegistry.getFeeRecipientLimit(address(this), ERC20(address(WETH)));
        assertEq(feeBps, 5);
        assertEq(recipient, address(0x69));
    }

    function testFeeRegistry_CrossGroup() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        feeRegistry.setTokenGroup(address(this), address(WETH), 2);
        feeRegistry.setTokenGroup(address(this), address(USDC), 1);
        feeRegistry.setLimitGroupPairFee(address(this), 1, 2, 30);

        uint16 feeBps = feeRegistry.getLimitFee(address(this), address(WETH), address(USDC));
        assertEq(feeBps, 30);
        // symmetric: (B,A) should return same fee as (A,B)
        uint16 feeBps2 = feeRegistry.getLimitFee(address(this), address(USDC), address(WETH));
        assertEq(feeBps2, 30);
    }

    function testFeeRegistry_DefaultFallback() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        feeRegistry.setDefaultLimitFee(address(this), 20);
        feeRegistry.setDefaultFeeRecipient(address(this), address(0x69));

        uint16 feeBps = feeRegistry.getLimitFee(address(this), address(WETH), address(USDC));
        address recipient = feeRegistry.getFeeRecipientLimit(address(this), ERC20(address(USDC)));
        assertEq(feeBps, 20);
        assertEq(recipient, address(0x69));
    }

    function testFeeRegistry_GroupPairOverridesDefault() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        feeRegistry.setDefaultLimitFee(address(this), 20);
        feeRegistry.setTokenGroup(address(this), address(WETH), 2);
        feeRegistry.setTokenGroup(address(this), address(USDC), 1);
        feeRegistry.setLimitGroupPairFee(address(this), 1, 2, 5);

        uint16 feeBps = feeRegistry.getLimitFee(address(this), address(WETH), address(USDC));
        assertEq(feeBps, 5);
    }

    function testFeeRegistry_IsolatedPerSwapper() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        // configure for address(this) — address(0x420) swapper should see zero fee
        feeRegistry.setDefaultLimitFee(address(this), 20);

        uint16 feeBps = feeRegistry.getLimitFee(address(0x420), address(WETH), address(USDC));
        address recipient = feeRegistry.getFeeRecipientLimit(address(0x420), ERC20(address(USDC)));
        assertEq(feeBps, 0);
        assertEq(recipient, address(0));
    }

    function testFeeRegistry_RevertFeeTooHigh() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        feeRegistry.setLimitGroupPairFee(address(this), 0, 1, 1001);
    }

    function testFeeRegistry_RevertInvalidRecipient() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        vm.expectRevert(FeeRegistry.FeeRegistry__InvalidRecipient.selector);
        feeRegistry.setDefaultFeeRecipient(address(this), address(0));
    }

    function testFeeRegistry_SetSwapperActive() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        assertEq(feeRegistry.limitFeeActive(address(0x420)), false);

        vm.expectEmit(true, false, false, true, address(feeRegistry));
        emit LimitFeeToggleUpdated(address(0x420), true);
        feeRegistry.toggleSwapperLimitFee(address(0x420), true);
        assertEq(feeRegistry.limitFeeActive(address(0x420)), true);

        vm.expectEmit(true, false, false, true, address(feeRegistry));
        emit LimitFeeToggleUpdated(address(0x420), false);
        feeRegistry.toggleSwapperLimitFee(address(0x420), false);
        assertEq(feeRegistry.limitFeeActive(address(0x420)), false);
    }

    function testFeeRegistry_SetMaxFeeBps() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        assertEq(feeRegistry.maxFeeBps(), 1000);

        vm.expectEmit(false, false, false, true, address(feeRegistry));
        emit MaxFeeBpsUpdated(500);
        feeRegistry.setMaxFeeBps(500);
        assertEq(feeRegistry.maxFeeBps(), 500);

        // fee above new cap is rejected
        vm.expectRevert(FeeRegistry.FeeRegistry__FeeTooHigh.selector);
        feeRegistry.setLimitGroupPairFee(address(this), 0, 1, 501);
    }

    //==================== BoringSwapper Fee Tests ====================

    function testSetFeeRegistry() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        swapper.setFeeRegistry(IFeeRegistry(address(feeRegistry)));
        assertEq(address(swapper.feeRegistry()), address(feeRegistry));
    }

    function testSetFeeRegistry_Unauthorized() external {
        feeRegistry = new FeeRegistry(address(this), 1000);
        vm.prank(address(0x42069));
        vm.expectRevert();
        swapper.setFeeRegistry(IFeeRegistry(address(feeRegistry)));
    }

    function testSubmitOrder_FeeLockedInSwapper() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry = new FeeRegistry(address(this), 1000);
        // 10 bps fee on WETH → USDC, scoped to address(swapper)
        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);
        swapper.setFeeRegistry(IFeeRegistry(address(feeRegistry)));

        uint256 inputAmount = 1e18;
        uint256 expectedFee = inputAmount * 10 / 10_000;

        _submitOrder(inputAmount, 2000e6, uint32(block.timestamp + 3600));

        // swapper holds inputAmount + fee (both locked)
        assertEq(WETH.balanceOf(address(swapper)), inputAmount + expectedFee);
        // vault was debited inputAmount + fee
        assertEq(WETH.balanceOf(address(boringVault)), 100e18 - inputAmount - expectedFee);
        // fee NOT yet forwarded — tracked in feesInToken
        assertEq(swapper.feesInToken(WETH), expectedFee);
        assertEq(WETH.balanceOf(address(0x69)), 0);
    }

    function testSubmitOrder_NoFeeWhenSwapperNotActive() external {
        deal(address(WETH), address(boringVault), 100e18);

        // swapper is not active in fee registry — no fee taken
        (,, uint256 orderId) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        assertEq(WETH.balanceOf(address(swapper)), 1e18);
        assertEq(WETH.balanceOf(address(boringVault)), 99e18);
    }

    function testSubmitOrder_ZeroFeeBps_NoFeeCharged() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry = new FeeRegistry(address(this), 1000);
        // fee bps = 0 means no fee even with a registry set and swapper active
        feeRegistry.setDefaultLimitFee(address(swapper), 0);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);
        swapper.setFeeRegistry(IFeeRegistry(address(feeRegistry)));

        (,, uint256 orderId) = _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        assertEq(WETH.balanceOf(address(swapper)), 1e18);
        assertEq(WETH.balanceOf(address(boringVault)), 99e18);
    }

    //==================== Limit Order Fee Tests ====================

    function testLimitOrderFee_HeldInSwapper() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10); // 10 bps
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);

        uint256 inputAmount = 1e18;
        uint256 expectedFee = inputAmount * 10 / 10_000;

        _submitOrder(inputAmount, 2000e6, uint32(block.timestamp + 3600));

        assertEq(swapper.feesInToken(WETH), expectedFee);
        assertEq(WETH.balanceOf(address(swapper)), inputAmount + expectedFee);
        assertEq(WETH.balanceOf(address(boringVault)), 100e18 - inputAmount - expectedFee);
        assertEq(swapper.claimableFees(WETH), 0);
    }

    function testLimitOrderFee_SweepExcludesLockedFees() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);

        uint256 inputAmount = 1e18;
        uint256 expectedFee = inputAmount * 10 / 10_000;

        _submitOrder(inputAmount, 2000e6, uint32(block.timestamp + 3600));

        // sweep: both pendingOrderPrincipal and feesInToken are locked — nothing sweepable
        swapper.sweep(WETH);

        assertEq(WETH.balanceOf(address(swapper)), inputAmount + expectedFee);
        assertEq(swapper.pendingOrderPrincipal(WETH), inputAmount);
        assertEq(swapper.feesInToken(WETH), expectedFee);
    }

    function testReleaseFee_MovesToClaimable() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);

        uint256 inputAmount = 1e18;
        uint256 expectedFee = inputAmount * 10 / 10_000;

        (ISwapperTypes.SwapConfig memory config, bytes32 digest, uint256 orderId) =
            _submitOrder(inputAmount, 2000e6, uint32(block.timestamp + 3600));

        _simulateFill(inputAmount, 2000e6, config, digest);

        assertEq(swapper.feesInToken(WETH), expectedFee);
        assertEq(swapper.claimableFees(WETH), 0);

        swapper.releaseFee(orderId);

        assertEq(swapper.feesInToken(WETH), 0);
        assertEq(swapper.claimableFees(WETH), expectedFee);
    }

    function testReleaseFee_ClearsApprovedHash() external {
        deal(address(WETH), address(boringVault), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 digest, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        assertTrue(swapper.approvedHashes(digest));

        _simulateFill(1e18, 2000e6, config, digest);

        swapper.releaseFee(orderId);

        assertFalse(swapper.approvedHashes(digest));
    }

    function testReleaseFee_RevertOrderNotFound() external {
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderNotFound.selector));
        swapper.releaseFee(999);
    }

    function testReleaseFee_ZeroFee_ClearsRecord() external {
        deal(address(WETH), address(boringVault), 100e18);

        // swapper not active — no fee charged
        (ISwapperTypes.SwapConfig memory config, bytes32 digest, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        _simulateFill(1e18, 2000e6, config, digest);

        swapper.releaseFee(orderId);

        BoringSwapper.OrderRecord memory rec = swapper.getOrderRecord(orderId);
        assertEq(address(rec.tokenIn), address(0));
        assertFalse(swapper.approvedHashes(digest));
        assertEq(swapper.claimableFees(WETH), 0);
    }

    // H-2 grief defense: strategist cancels after a fill landed off-chain (front-running releaseFee).
    // The bot must still be able to claim the fee during the cancel-delay window via releaseFee.
    // Replaces the former H-2 grief defense (cancel-after-fill → releaseFee redirects to claimableFees).
    // The new gate refuses cancel against any order the protocol considers filled, removing the grief
    // vector entirely. The bot's normal releaseFee path is covered by testReleaseFee_MovesToClaimable.
    function testCancelOrder_RevertOrderAlreadyFilled() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);

        (ISwapperTypes.SwapConfig memory config, bytes32 digest, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        _simulateFill(1e18, 2000e6, config, digest);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderAlreadyFilled.selector));
        swapper.cancelOrder(orderId, config, "");
    }

    function testClaimFees_SendsToRecipient() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);
        feeRegistry.setDefaultFeeRecipient(address(swapper), address(0x69));

        uint256 inputAmount = 1e18;
        uint256 expectedFee = inputAmount * 10 / 10_000;

        (ISwapperTypes.SwapConfig memory config, bytes32 digest, uint256 orderId) =
            _submitOrder(inputAmount, 2000e6, uint32(block.timestamp + 3600));

        _simulateFill(inputAmount, 2000e6, config, digest);
        swapper.releaseFee(orderId);

        assertEq(swapper.claimableFees(WETH), expectedFee);

        swapper.claimFees(WETH);

        assertEq(swapper.claimableFees(WETH), 0);
        assertEq(WETH.balanceOf(address(0x69)), expectedFee);
    }

    function testClaimFees_ZeroBalance_NoOp() external {
        // no fees released — should return without reverting
        swapper.claimFees(WETH);
        assertEq(swapper.claimableFees(WETH), 0);
    }

    function testClaimFees_RevertNoRecipient() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);
        // no setDefaultFeeRecipient — recipient is address(0)

        (ISwapperTypes.SwapConfig memory config, bytes32 digest, uint256 orderId) =
            _submitOrder(1e18, 2000e6, uint32(block.timestamp + 3600));

        _simulateFill(1e18, 2000e6, config, digest);
        swapper.releaseFee(orderId);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__FeeRecipientNotSet.selector));
        swapper.claimFees(WETH);
    }

    function testCancelOrder_WithFee_PrincipalRefundedFeeHeld() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);

        uint256 inputAmount = 1e18;
        uint256 expectedFee = inputAmount * 10 / 10_000;

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) =
            _submitOrder(inputAmount, 2000e6, uint32(block.timestamp + 3600));

        assertEq(WETH.balanceOf(address(boringVault)), 100e18 - inputAmount - expectedFee);

        swapper.cancelOrder(orderId, config, "");

        // vault gets only principal back; fee stays locked in feesInToken until releaseFee
        assertEq(WETH.balanceOf(address(boringVault)), 100e18 - expectedFee);
        assertEq(WETH.balanceOf(address(swapper)), expectedFee);
        assertEq(swapper.feesInToken(WETH), expectedFee);
        assertEq(swapper.claimableFees(WETH), 0);
    }

    function testCancelOrder_WithFee_NotMovedToClaimable() external {
        deal(address(WETH), address(boringVault), 100e18);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10);
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);

        uint256 inputAmount = 1e18;
        uint256 expectedFee = inputAmount * 10 / 10_000;

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) =
            _submitOrder(inputAmount, 2000e6, uint32(block.timestamp + 3600));

        swapper.cancelOrder(orderId, config, "");

        // cancel leaves the fee locked in feesInToken and does NOT populate claimableFees
        assertEq(swapper.claimableFees(WETH), 0);
        assertEq(swapper.feesInToken(WETH), expectedFee);
    }

    function testRateLimit_Cancel_FeeExcludedFromRestore() external {
        deal(address(WETH), address(boringVault), 100e18);

        bytes32 routeKey = swapper.getRouteId(WETH, USDC);
        swapper.setRateLimit(routeKey, 5e18, 0);

        feeRegistry.setTokenGroup(address(swapper), address(WETH), 1);
        feeRegistry.setTokenGroup(address(swapper), address(USDC), 2);
        feeRegistry.setLimitGroupPairFee(address(swapper), 1, 2, 10); // 10 bps
        feeRegistry.toggleSwapperLimitFee(address(swapper), true);

        uint256 inputAmount = 3e18;
        uint256 expectedFee = inputAmount * 10 / 10_000;

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) =
            _submitOrder(inputAmount, 6000e6, uint32(block.timestamp + 3600));

        (, uint256 remaining,,) = swapper.rateLimitPerRoute(routeKey);
        assertEq(remaining, 2e18); // 5e18 - 3e18 consumed

        swapper.cancelOrder(orderId, config, "");

        // restored = remaining(2e18) + unfilledOrder(3e18) = 5e18 — fee excluded
        (, remaining,,) = swapper.rateLimitPerRoute(routeKey);
        assertEq(remaining, 5e18);
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
    ) internal view returns (ISwapperTypes.SwapConfig memory, bytes32 orderDigest) {
        return _buildSwapConfig(sellAmount, buyAmount, validTo, address(WETH));
    }

    function _buildSwapConfig(
        uint256 sellAmount,
        uint256 buyAmount,
        uint32 validTo,
        address tokenIn
    ) internal view returns (ISwapperTypes.SwapConfig memory, bytes32 orderDigest) {
        bytes memory cowswapData = abi.encode(
            tokenIn,      //sellToken
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

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(ERC20(tokenIn), USDC),
            adapter: address(cowAdapter),
            quoteAsset: address(USDC),
            swapData: cowswapData,
            slippageBps: 10,
            receiver: boringVault
        });

        //compute the EIP-712 order digest
        bytes32 structHash = keccak256(abi.encode(
            GPV2_ORDER_TYPE_HASH,
            address(tokenIn),
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
        returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId)
    {
        (config, orderDigest) = _buildSwapConfig(sellAmount, buyAmount, validTo);
        orderId = swapper.orders();
        swapper.submitOrder(config);
    }

    //simulate settlement pulling tokenIn from swapper and sending tokenOut to vault
    function _simulateFill(
        uint256 amountIn,
        uint256 amountOut,
        ISwapperTypes.SwapConfig memory config,
        bytes32 orderDigest
    ) internal {
        //verify signature (as settlement would)
        vm.prank(COW_SETTLEMENT);
        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e), "isValidSignature failed");

        //settlement pulls tokenIn from swapper using the pre-approval
        vm.prank(COW_VAULT_RELAYER);
        WETH.transferFrom(address(swapper), COW_SETTLEMENT, amountIn);

        //settlement sends tokenOut directly to the vault
        deal(address(USDC), COW_SETTLEMENT, amountOut);
        vm.prank(COW_SETTLEMENT);
        USDC.transfer(address(boringVault), amountOut);

        //mirror the protocol-side fill state: GPv2Settlement writes sellAmount into filledAmount[orderUid].
        //Required for BoringSwapper._cancelOrder's isFilled check to fire correctly in tests.
        DecoderCustomTypes.GPv2OrderData memory order =
            abi.decode(config.swapData, (DecoderCustomTypes.GPv2OrderData));
        bytes memory orderUid = abi.encodePacked(orderDigest, address(swapper), order.validTo);
        vm.mockCall(
            COW_SETTLEMENT,
            abi.encodeWithSelector(bytes4(keccak256("filledAmount(bytes)")), orderUid),
            abi.encode(amountIn)
        );
    }

    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }

    function _toArray(address addr) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = addr;
        return arr;
    }
}
