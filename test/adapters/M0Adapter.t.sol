// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {M0Adapter} from "src/base/Periphery/adapters/M0HookAdapter.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {IM0OrderBook} from "src/interfaces/IM0OrderBook.sol";


import {Test, console} from "@forge-std/Test.sol";
import {Vm} from "@forge-std/Vm.sol";

contract MockRateProvider is IRateProvider {
    uint256 internal rate;

    constructor(uint256 _rate) {
        rate = _rate;
    }

    function getRate() public view override returns (uint256) {
        return rate;
    }
}

contract M0AdapterTest is BaseTestIntegration {
    using AddressToBytes32Lib for bytes32;
    using AddressToBytes32Lib for address;
    using FixedPointMathLib for uint256;

    address m0Adapter;

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    MockRateProvider usdRate;
    MockRateProvider ethRate;

    function setUp() public override {
        super.setUp();
        _setupChain("mainnet", 24886820);

        address swapperDecoder = address(new BoringSwapperDecoder());
        _overrideDecoder(swapperDecoder);

        registry = new AdapterRegistry();
        validator = new PriceValidator();
        swapper = new BoringSwapper(address(this), registry, new FeeRegistry(address(this), 1000), boringVault, IPriceValidator(address(validator)));
        swapper.setAuthority(rolesAuthority);

        m0Adapter = address(new M0Adapter(getAddress(sourceChain, "m0OrderBook")));

        swapper.setRouteConfig(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), 500, 0, 0);
        swapper.setApprovedAdapter(m0Adapter, true);

        registry.put(m0Adapter, "M0");

        usdRate = new MockRateProvider(1e18);
        ethRate = new MockRateProvider(2000e18);
        address usdQuoteAsset = getAddress(sourceChain, "USDC");

        swapper.setTokenOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, _makeOracleConfig(address(usdRate), address(0), false));
        swapper.setTokenOracle(getERC20(sourceChain, "WETH"), usdQuoteAsset, _makeOracleConfig(address(ethRate), address(0), false));

        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.swap.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.submitOrder.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.cancelOrder.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.replaceOrder.selector, true);
    }

    // ====================================== Entrypoint Functions ====================================== 
        
    function testM0OrderBook__OpenOrder() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(1),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        vm.recordLogs();
        _submitManagerCall(manageProofs, tx_); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        //get the orderId from m0?

        bytes32 sig = keccak256(
            "OrderOpened(bytes32,address,address,uint128,uint32,bytes32,uint128,bytes32)"
        );

        bytes32 m0OrderId;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == sig) {
                // non-indexed, in emit order
                (
                    bytes32 orderId,
                    /*tokenIn*/,
                    /*amountIn*/,
                    /*tokenOut*/,
                    /*amountOut*/
                ) = abi.decode(entries[i].data, (bytes32, address, uint128, bytes32, uint128));

                m0OrderId = orderId;
                break;
            }
        }
        
        //verify an incorrect id doesn't work
        uint256 swapperOrderId = 1; 
        BoringSwapper.OrderRecord memory rec = swapper.getOrderRecord(swapperOrderId);
        assertEq(rec.context.length, 0);
        
        //verify the correct one does
        swapperOrderId = 0; 
        rec = swapper.getOrderRecord(swapperOrderId);
        bytes32 predicted = abi.decode(rec.context, (bytes32)); 
        assertEq(m0OrderId, predicted);
    }

    function testM0OrderBook__Cancel() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(block.chainid),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ManageLeaf[] memory leafs) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        vm.recordLogs();
        _submitManagerCall(manageProofs, tx_); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        //get the orderId from m0?

        bytes32 sig = keccak256(
            "OrderOpened(bytes32,address,address,uint128,uint32,bytes32,uint128,bytes32)"
        );

        bytes32 m0OrderId;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == sig) {
                // non-indexed, in emit order
                (
                    bytes32 orderId,
                    /*tokenIn*/,
                    /*amountIn*/,
                    /*tokenOut*/,
                    /*amountOut*/
                ) = abi.decode(entries[i].data, (bytes32, address, uint128, bytes32, uint128));

                m0OrderId = orderId;
                break;
            }
        }
        
        DecoderCustomTypes.OrderData memory orderData = IM0OrderBook(getAddress(sourceChain, "m0OrderBook")).getOrderData(m0OrderId);
        
        //setup the cancel leaves
        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        bytes memory cancelFunctionAndArgs = abi.encodeWithSignature(
            "cancelOrder(bytes32,(uint16,bytes32,uint64,uint32,uint32,uint64,uint64,bytes32,bytes32,uint128,uint128,bytes32,bytes32))",
            m0OrderId,
            orderData
        );


        Tx memory cancelTx = _getTxArrays(1);
        cancelTx.manageLeafs[0] = leafs[7]; //approve token
        cancelTx.targets[0] = address(swapper);  
        cancelTx.targetData[0] = abi.encodeWithSignature(
            "cancelOrder(uint256,((address,address),address,address,bytes,uint256,address),bytes)", 
            0,
            config,            
            cancelFunctionAndArgs 
        );
        cancelTx.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        bytes32[][] memory cancelProofs = _getProofsUsingTree(cancelTx.manageLeafs, manageTree);

        _submitManagerCall(cancelProofs, cancelTx); 

        //verify the cancel actually went through
        IM0OrderBook.Order memory order = IM0OrderBook(getAddress(sourceChain, "m0OrderBook")).getOrder(m0OrderId);
        assertEq(uint8(order.status), uint8(IM0OrderBook.OrderStatus.Cancelled)); //cast enums to uint8 for assert to work
    }
    
    function testM0OrderBook__FilledAmount() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(block.chainid),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        vm.recordLogs();
        _submitManagerCall(manageProofs, tx_); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        //get the orderId from m0?

        bytes32 sig = keccak256(
            "OrderOpened(bytes32,address,address,uint128,uint32,bytes32,uint128,bytes32)"
        );

        bytes32 m0OrderId;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == sig) {
                // non-indexed, in emit order
                (
                    bytes32 orderId,
                    /*tokenIn*/,
                    /*amountIn*/,
                    /*tokenOut*/,
                    /*amountOut*/
                ) = abi.decode(entries[i].data, (bytes32, address, uint128, bytes32, uint128));

                m0OrderId = orderId;
                break;
            }
        }
        
        //should be valid context 
        BoringSwapper.OrderRecord memory rec = swapper.getOrderRecord(0);
        assertGt(rec.context.length, 0);
        
        //initial state should be 0
        uint256 filledAmount = M0Adapter(m0Adapter).filledAmount(config, address(swapper), rec.context);  
        assertEq(filledAmount, 0); 

        IM0OrderBook.FillParams memory fillParams = 
            IM0OrderBook.FillParams({
                amountOutToFill: uint128(100),
                originRecipient: address(swapper).toBytes32(),
                refundAddress: address(swapper).toBytes32()
            });

        DecoderCustomTypes.OrderData memory orderData = IM0OrderBook(getAddress(sourceChain, "m0OrderBook")).getOrderData(m0OrderId);
        
        deal(getAddress(sourceChain, "USDC"), address(this), 1000000e6);
        getERC20(sourceChain, "USDC").approve(getAddress(sourceChain, "m0OrderBook"), type(uint256).max);

        assertEq(getERC20(sourceChain, "USDC").balanceOf(address(boringVault)), 0);
        IM0OrderBook(getAddress(sourceChain, "m0OrderBook")).fillOrder(
            m0OrderId,
            orderData,
            fillParams
        );
        
        //amountIn * amountOutFilled / amountOut (in original order)
        //we want to get the amount of amountIn that has been filled, so we need to convert tokenOut to tokenIn
        //which is exactly what m0 does as well
        //we reconstruct from first principals to ensure that we are not bots 
        uint256 expectedFillAmount = uint256(1e15).mulDivDown(100, 2_200_000);
        filledAmount = M0Adapter(m0Adapter).filledAmount(config, address(swapper), rec.context);  
        assertEq(filledAmount, expectedFillAmount); 
        
        //verify the vault receives the filled amounts here
        assertEq(getERC20(sourceChain, "USDC").balanceOf(address(boringVault)), 100);
    }

    // ====================================== Revert Cases ====================================== 
    //
    function testM0OrderBook__TokenInReverts() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(block.chainid),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "USDT"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        vm.expectRevert(IAdapter.Adapter__TokenInMismatch.selector);
        _submitManagerCall(manageProofs, tx_); 
    }

    function testM0OrderBook__TokenOutReverts() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(block.chainid),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDT"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        vm.expectRevert(IAdapter.Adapter__TokenOutMismatch.selector);
        _submitManagerCall(manageProofs, tx_); 
    }

    function testM0OrderBook__ReceiverReverts() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(block.chainid),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(this).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        vm.expectRevert(IAdapter.Adapter__ReceiverMismatch.selector);
        _submitManagerCall(manageProofs, tx_); 
    }

    function testM0OrderBook__CrossChainNotAllowedReverts() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(696969),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        vm.expectRevert(M0Adapter.M0Adapter__CrossChainNotAllowed.selector);
        _submitManagerCall(manageProofs, tx_); 
    }

    function testM0OrderBook__PrivateOrdersNotAllowedReverts() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(1),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(this).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        vm.expectRevert(M0Adapter.M0Adapter__PrivateOrdersNotAllowed.selector);
        _submitManagerCall(manageProofs, tx_); 
    }

    function testM0OrderBook__NotCancelFunctionReverts() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(block.chainid),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ManageLeaf[] memory leafs) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        vm.recordLogs();
        _submitManagerCall(manageProofs, tx_); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        //get the orderId from m0?

        bytes32 sig = keccak256(
            "OrderOpened(bytes32,address,address,uint128,uint32,bytes32,uint128,bytes32)"
        );

        bytes32 m0OrderId;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == sig) {
                // non-indexed, in emit order
                (
                    bytes32 orderId,
                    /*tokenIn*/,
                    /*amountIn*/,
                    /*tokenOut*/,
                    /*amountOut*/
                ) = abi.decode(entries[i].data, (bytes32, address, uint128, bytes32, uint128));

                m0OrderId = orderId;
                break;
            }
        }
        
        DecoderCustomTypes.OrderData memory orderData = IM0OrderBook(getAddress(sourceChain, "m0OrderBook")).getOrderData(m0OrderId);
        
        //setup the cancel leaves
        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        bytes memory cancelFunctionAndArgs = abi.encodeWithSignature(
            "cancelOrderButWithASurprise(bytes32,(uint16,bytes32,uint64,uint32,uint32,uint64,uint64,bytes32,bytes32,uint128,uint128,bytes32,bytes32))",
            m0OrderId,
            orderData
        );

        Tx memory cancelTx = _getTxArrays(1);
        cancelTx.manageLeafs[0] = leafs[7]; //approve token
        cancelTx.targets[0] = address(swapper);  
        cancelTx.targetData[0] = abi.encodeWithSignature(
            "cancelOrder(uint256,((address,address),address,address,bytes,uint256,address),bytes)", 
            0,
            config,            
            cancelFunctionAndArgs 
        );
        cancelTx.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        bytes32[][] memory cancelProofs = _getProofsUsingTree(cancelTx.manageLeafs, manageTree);
            
        vm.expectRevert(M0Adapter.M0Adapter__NotCancelFunction.selector);
        _submitManagerCall(cancelProofs, cancelTx); 
    }

    function testM0OrderBook__OrderIdMismatchOnCancelReverts() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory m0Data = abi.encode(
            DecoderCustomTypes.OrderParams({ 
                destChainId: uint32(block.chainid),
                fillDeadline: uint32(block.timestamp + 3600),
                tokenIn: getAddress(sourceChain, "WETH"),
                tokenOut: getBytes32(sourceChain, "USDC"),
                amountIn: 1000000000000000,
                amountOut: 2200000,
                recipient: address(boringVault).toBytes32(), 
                solver: address(0).toBytes32() 
            })
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: m0Adapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: m0Data,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ManageLeaf[] memory leafs) = _setupLeavesAndState(config);
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        vm.recordLogs();
        _submitManagerCall(manageProofs, tx_); 
        Vm.Log[] memory entries = vm.getRecordedLogs();

        //get the orderId from m0?

        bytes32 sig = keccak256(
            "OrderOpened(bytes32,address,address,uint128,uint32,bytes32,uint128,bytes32)"
        );

        bytes32 m0OrderId;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == sig) {
                // non-indexed, in emit order
                (
                    bytes32 orderId,
                    /*tokenIn*/,
                    /*amountIn*/,
                    /*tokenOut*/,
                    /*amountOut*/
                ) = abi.decode(entries[i].data, (bytes32, address, uint128, bytes32, uint128));

                m0OrderId = orderId;
                break;
            }
        }
        
        DecoderCustomTypes.OrderData memory orderData = IM0OrderBook(getAddress(sourceChain, "m0OrderBook")).getOrderData(m0OrderId);
        
        //setup the cancel leaves
        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        bytes memory cancelFunctionAndArgs = abi.encodeWithSignature(
            "cancelOrder(bytes32,(uint16,bytes32,uint64,uint32,uint32,uint64,uint64,bytes32,bytes32,uint128,uint128,bytes32,bytes32))",
            bytes32("bilmuriIsGoated"),
            orderData
        );

        Tx memory cancelTx = _getTxArrays(1);
        cancelTx.manageLeafs[0] = leafs[7]; //approve token
        cancelTx.targets[0] = address(swapper);  
        cancelTx.targetData[0] = abi.encodeWithSignature(
            "cancelOrder(uint256,((address,address),address,address,bytes,uint256,address),bytes)", 
            0,
            config,            
            cancelFunctionAndArgs 
        );
        cancelTx.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        bytes32[][] memory cancelProofs = _getProofsUsingTree(cancelTx.manageLeafs, manageTree);
            
        vm.expectRevert(M0Adapter.M0Adapter__OrderIdMismatch.selector);
        _submitManagerCall(cancelProofs, cancelTx); 
    }



    //====================================== Internal Test Functions ====================================== 
    
    function _setupLeavesAndState(ISwapperTypes.SwapConfig memory config) internal returns (bytes32[][] memory manageTree, Tx memory, ManageLeaf[] memory leafs) {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");
    
        leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[6]; //swap WETH -> USDC
        

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.submitOrder.selector,
            config
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        return (manageTree, tx_, leafs);
    }
    
    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }

}
