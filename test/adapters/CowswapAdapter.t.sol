// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {CowswapAdapter, IGPv2Settlement} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";

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

contract CowswapAdapterTest is BaseTestIntegration {

    address cowswapAdapter;

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    MockRateProvider usdRate;
    MockRateProvider ethRate;

    function setUp() public override {
        super.setUp();
        _setupChain("mainnet", 24886820);

        address swapperDecoder = address(new FullBoringSwapperDecoderAndSanitizer());
        _overrideDecoder(swapperDecoder);

        registry = new AdapterRegistry();
        validator = new PriceValidator();
        swapper = new BoringSwapper(address(this), registry, new FeeRegistry(address(this), 1000), boringVault, IPriceValidator(address(validator)));
        swapper.setAuthority(rolesAuthority);

        cowswapAdapter = address(new CowswapAdapter(getAddress(sourceChain, "cowswapSettlement"), getAddress(sourceChain, "cowswapVaultRelayer")));

        swapper.setRouteConfig(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), 500, 0, 0);
        swapper.setApprovedAdapter(cowswapAdapter, true);

        registry.put(cowswapAdapter, "COWSWAP");

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

    //====================================== Adapter Functions ====================================== 
    
    function testFilledAmount() external {

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        bytes memory cowswapData = abi.encode(DecoderCustomTypes.GPv2OrderData({
          sellToken: getAddress(sourceChain, "WETH"),
          buyToken: getAddress(sourceChain, "USDC"),
          receiver: getAddress(sourceChain, "boringVault"),
          sellAmount: 1000000000000000,
          buyAmount: 2200000,
          validTo: uint32(block.timestamp + 86400),
          appData: bytes32(0),
          feeAmount: 0,
          kind: keccak256("sell"),
          partiallyFillable: true,
          sellTokenBalance: keccak256("erc20"),
          buyTokenBalance: keccak256("erc20")
        }));
        
        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: cowswapAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: cowswapData,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ) = _setupLeavesAndState(config);
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);


        bytes32 domainSeparator = IGPv2Settlement(getAddress(sourceChain, "cowswapSettlement")).domainSeparator();
        bytes32 structHash = keccak256(abi.encodePacked(
            keccak256("Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,string kind,bool partiallyFillable,string sellTokenBalance,string buyTokenBalance)"),
            cowswapData 
        ));
        bytes32 orderHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        bytes memory orderUid = abi.encodePacked(orderHash, address(swapper), uint32(block.timestamp + 86400));
        
        //check initial state (should be 0)
        uint256 filledAmount = IAdapter(cowswapAdapter).filledAmount(config, address(swapper), "");
        assertEq(filledAmount, 0);

        bytes32 slot = keccak256(abi.encodePacked(orderUid, uint256(2)));
        vm.store(getAddress(sourceChain, "cowswapSettlement"), slot, bytes32(uint256(5e11)));

        filledAmount = IAdapter(cowswapAdapter).filledAmount(config, address(swapper), "");
        assertEq(filledAmount, 5e11);
    }

    function testCancelAfterPartialFill() external {

        bytes memory cowswapData = abi.encode(DecoderCustomTypes.GPv2OrderData({
          sellToken: getAddress(sourceChain, "WETH"),
          buyToken: getAddress(sourceChain, "USDC"),
          receiver: getAddress(sourceChain, "boringVault"),
          sellAmount: 1000000000000000,
          buyAmount: 2200000,
          validTo: uint32(block.timestamp + 86400),
          appData: bytes32(0),
          feeAmount: 0,
          kind: keccak256("sell"),
          partiallyFillable: true,
          sellTokenBalance: keccak256("erc20"),
          buyTokenBalance: keccak256("erc20")
        }));

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC")),
            adapter: cowswapAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: cowswapData,
            slippageBps: 250,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        (bytes32[][] memory manageTree, Tx memory tx_, ManageLeaf[] memory leafs) = _setupLeavesAndState(config);
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);

        {
            bytes32 structHash = keccak256(abi.encodePacked(
                keccak256("Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,string kind,bool partiallyFillable,string sellTokenBalance,string buyTokenBalance)"),
                cowswapData
            ));
            bytes32 orderHash = keccak256(abi.encodePacked("\x19\x01", IGPv2Settlement(getAddress(sourceChain, "cowswapSettlement")).domainSeparator(), structHash));
            bytes memory orderUid = abi.encodePacked(orderHash, address(swapper), uint32(block.timestamp + 86400));
            vm.store(getAddress(sourceChain, "cowswapSettlement"), keccak256(abi.encodePacked(orderUid, uint256(2))), bytes32(uint256(4e14)));
        }

        assertEq(IAdapter(cowswapAdapter).filledAmount(config, address(swapper), ""), 4e14);

        Tx memory cancelTx = _getTxArrays(1);
        cancelTx.manageLeafs[0] = leafs[3];
        cancelTx.targets[0] = address(swapper);
        cancelTx.targetData[0] = abi.encodeWithSignature(
            "cancelOrder(uint256,((address,address),address,address,bytes,uint256,address),bytes)",
            1,
            config,
            bytes("")
        );
        cancelTx.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 vaultWethBefore = getERC20(sourceChain, "WETH").balanceOf(address(boringVault));
        _submitManagerCall(_getProofsUsingTree(cancelTx.manageLeafs, manageTree), cancelTx);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(boringVault)) - vaultWethBefore, 1e15 - 4e14);
        assertEq(swapper.pendingOrderPrincipal(getERC20(sourceChain, "WETH")), 0);
        assertGt(swapper.getOrderRecord(1).cancelledAt, 0);
    }


    //====================================== Helpers ======================================
    
    function _setupLeavesAndState(ISwapperTypes.SwapConfig memory config) internal returns (bytes32[][] memory manageTree, Tx memory, ManageLeaf[] memory leafs) {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;

        leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind);

        manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[2]; //submitOrder WETH -> USDC

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


contract FullBoringSwapperDecoderAndSanitizer is BoringSwapperDecoder, BaseDecoderAndSanitizer {}
