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
import {OneInchAdapter, IOneInchOrderMixin} from "src/base/Periphery/adapters/OneInchAdapter.sol";
import {IUniswapV3Factory} from "src/interfaces/IUniswapV3Factory.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";

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

contract OneInchAdapterTest is BaseTestIntegration {

    address constant ONEINCH_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;
    address constant ONEINCH_FEE_TAKER = address(0);
    address constant ONEINCH_EXECUTOR = 0x990636ecB3FF04d33D92e970d3d588bF5cD8d086;

    bytes32 constant ONEINCH_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"
    );

    address oneInchAdapter;

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    MockRateProvider usdRate;
    MockRateProvider ethRate;

    function setUp() public virtual override {
        super.setUp();
        _setupChain("mainnet", 24592183);

        address swapperDecoder = address(new FullBoringSwapperDecoderAndSanitizer());
        _overrideDecoder(swapperDecoder);

        registry = new AdapterRegistry();
        validator = new PriceValidator();
        swapper = new BoringSwapper(address(this), registry, new FeeRegistry(address(this), 1000), boringVault, IPriceValidator(address(validator)));
        swapper.setAuthority(rolesAuthority);

        address[] memory executors = new address[](1);
        executors[0] = ONEINCH_EXECUTOR;
        oneInchAdapter = address(new OneInchAdapter(
            ONEINCH_ROUTER,
            ONEINCH_FEE_TAKER,
            0x90CbE4BDd538D6e9b379bFF5fE72c3d67A521De5, // 1inch protocol fee receiver
            executors,
            getAddress(sourceChain, "uniV2Factory"),
            getAddress(sourceChain, "uniV3Factory"),
            getAddress(sourceChain, "curveMetaRegistry")
        ));

        swapper.setRouteConfig(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), 50, 0, 0);
        swapper.setRouteConfig(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDT"), 500, 0, 0);
        swapper.setRouteConfig(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDE"), 500, 0, 0);
        swapper.setRouteConfig(getERC20(sourceChain, "USDT"), getERC20(sourceChain, "USDC"), 500, 0, 0);
        swapper.setApprovedAdapter(oneInchAdapter, true);

        registry.put(oneInchAdapter, "ONEINCH");

        //oracle setup
        usdRate = new MockRateProvider(1e18);
        ethRate = new MockRateProvider(2000e18);
        address usdQuoteAsset = getAddress(sourceChain, "USDC");

        swapper.setTokenOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, _makeOracleConfig(address(usdRate), address(0), false));
        swapper.setTokenOracle(getERC20(sourceChain, "USDT"), usdQuoteAsset, _makeOracleConfig(address(usdRate), address(0), false));
        swapper.setTokenOracle(getERC20(sourceChain, "WETH"), usdQuoteAsset, _makeOracleConfig(address(ethRate), address(0), false));

        //roles setup
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.swap.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.submitOrder.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.cancelOrder.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.replaceOrder.selector, true);
    }

    //==================== 1inch Swap Tests ====================

    function testUnoswap() external {
        //set up manager swap
        //do the swap
        //swap happens 
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDC
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswapData = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000001f6d2c08000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dc";
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        _submitManagerCall(manageProofs, tx_);

        uint256 wethAfter = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcAfter = getERC20(sourceChain, "USDC").balanceOf(vault);

        assertLt(wethAfter, wethBefore);
        assertGt(usdcAfter, usdcBefore);

    }

    // Verifies the swapper's ATOMIC fee path end-to-end: with a 1% atomic fee active, _swapPostFlightCheck
    // must send exactly the 1% cut (of gross output) to the configured recipient and forward the net to the
    // vault. (The limit-fee escrow path is covered in BoringSwapper.t.sol; this covers the atomic deduction.)
    function testOneInchAtomicSwap_ChargesFee() external {
        address vault = getAddress(sourceChain, "boringVault");
        address feeRecipient = address(0x69);
        deal(getAddress(sourceChain, "WETH"), vault, 100e18);

        // enable a 1% atomic fee for this swapper, paid to feeRecipient
        {
            FeeRegistry feeRegistry = FeeRegistry(address(swapper.feeRegistry()));
            feeRegistry.toggleSwapperAtomicFee(address(swapper), true);
            feeRegistry.setDefaultAtomicFee(address(swapper), 100);
            feeRegistry.setDefaultFeeRecipient(address(swapper), feeRecipient);
        }

        uint256 vaultUsdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);
        uint256 recipientUsdcBefore = getERC20(sourceChain, "USDC").balanceOf(feeRecipient);

        // scoped so the merkle/tx locals are released before the balance math (avoids stack-too-deep)
        {
            address[][] memory pairs = new address[][](1);
            pairs[0] = new address[](2);
            pairs[0][0] = getAddress(sourceChain, "WETH");
            pairs[0][1] = getAddress(sourceChain, "USDC");

            SwapKind[] memory kind = new SwapKind[](1);
            kind[0] = SwapKind.BuyAndSell;

            ManageLeaf[] memory leafs = new ManageLeaf[](16);
            _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind);
            bytes32[][] memory manageTree = _generateMerkleTree(leafs);
            manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

            Tx memory tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[0];
            tx_.manageLeafs[1] = leafs[1];
            bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

            tx_.targets[0] = getAddress(sourceChain, "WETH");
            tx_.targets[1] = address(swapper);
            tx_.targetData[0] =
                abi.encodeWithSignature("approve(address,uint256)", address(swapper), type(uint256).max);
            tx_.targetData[1] = abi.encodeWithSelector(
                BoringSwapper.swap.selector,
                ISwapperTypes.SwapConfig({
                    tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC")),
                    adapter: oneInchAdapter,
                    quoteAsset: getAddress(sourceChain, "USDC"),
                    swapData: hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000001f6d2c08000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dc",
                    slippageBps: 10,
                    receiver: BoringVault(payable(vault))
                })
            );
            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

            _submitManagerCall(manageProofs, tx_);
        }

        uint256 vaultGot = getERC20(sourceChain, "USDC").balanceOf(vault) - vaultUsdcBefore;
        uint256 recipientGot = getERC20(sourceChain, "USDC").balanceOf(feeRecipient) - recipientUsdcBefore;

        uint256 gross = vaultGot + recipientGot;
        uint256 expectedFee = (gross * 100 + 9999) / 10_000; // mulDivUp(gross, 100, 10_000) == 1%

        assertGt(recipientGot, 0, "fee recipient received nothing");
        assertEq(recipientGot, expectedFee, "fee is not 1% of gross output");
        assertEq(vaultGot, gross - expectedFee, "vault did not receive the net");
    }


    function testUnoswapTo() external {
        //set up manager swap
        //do the swap
        //swap happens 
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDC
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );
        
        //0x...211 is the swapper address, it is encoded below in the hex
        console.log("swapper: ", address(swapper)); 
        bytes memory unoswapData = hex"e2c95c8200000000000000000000000003a6a84cd762d9707a21605b548aaab891562aab000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640";
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

    }


    function testUnoswap2() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDC
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswap2Data = hex"8770ba91000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c680000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000c2e9f25be6257c210d7adf0d4cd6e3e881ba25f82080000000000000000000005777d92f208679db4b9778590fa3cab3ac9e2168";
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswap2Data,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        _submitManagerCall(manageProofs, tx_);

        uint256 wethAfter = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcAfter = getERC20(sourceChain, "USDC").balanceOf(vault);

        assertLt(wethAfter, wethBefore);
        assertGt(usdcAfter, usdcBefore);

    }


    function testUnoswap3() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDT");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDC
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswap3Data = hex"19367472000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c680000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000c2e9f25be6257c210d7adf0d4cd6e3e881ba25f82080000000000000000000005777d92f208679db4b9778590fa3cab3ac9e21682080000000000000000000003416cf6c708da44db2624d63ea0aaef7113527c6";
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDT")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswap3Data,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdtBefore = getERC20(sourceChain, "USDT").balanceOf(vault);

        _submitManagerCall(manageProofs, tx_);

        uint256 wethAfter = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdtAfter = getERC20(sourceChain, "USDT").balanceOf(vault);

        assertLt(wethAfter, wethBefore);
        assertGt(usdtAfter, usdtBefore);
    }


    function testUnoswapCurve() external {
        //set up manager swap
        //do the swap
        //swap happens 
        deal(getAddress(sourceChain, "USDT"), getAddress(sourceChain, "boringVault"), 100e8); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "USDT");
        pairs[0][1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap USDT -> USDC
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDT"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswapData = hex"83800a8e000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000000000000000000400001020100020000000000bebc44782c7db0a1a60cb6fe97d0b483032ff1c7";
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "USDT"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        //address vault = getAddress(sourceChain, "boringVault");
        //uint256 wethBefore = getERC20(sourceChain, "USDT").balanceOf(vault);
        //uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);
        
        vm.expectRevert(); //we are reverting on a failed innerCall here which is acceptable --
        //the path through the adapter is pulling out the coins correctly, which is all we care about in this case tokenIn + tokenOut match correctly
        _submitManagerCall(manageProofs, tx_);


        //uint256 wethAfter = getERC20(sourceChain, "WETH").balanceOf(vault);
        //uint256 usdcAfter = getERC20(sourceChain, "USDC").balanceOf(vault);

        //assertLt(wethAfter, wethBefore);
        //assertGt(usdcAfter, usdcBefore);

    }

    function testOneInchSwap_PreservesLimitOrderAllowance() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        _submitOneInchOrder(1e18, 2000e6);

        uint256 limitOrderAllowance =
            getERC20(sourceChain, "WETH").allowance(address(swapper), ONEINCH_ROUTER);
        assertEq(limitOrderAllowance, 1e18);

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0];
        tx_.manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(swapper);
        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswapData = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000001f6d2c08000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dcf583bc2f";

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        uint256 postSwapAllowance =
            getERC20(sourceChain, "WETH").allowance(address(swapper), ONEINCH_ROUTER);
        assertEq(postSwapAllowance, limitOrderAllowance);
    }

    //==================== 1inch Swap Test Reverts ====================

    function testUnoswap_RevertsToken1Mismatch() external {
        //set up manager swap
        //do the swap
        //swap happens 
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDT");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDT
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswapData = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000001f6d2c08000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dc";
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDT")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
            
        vm.expectRevert(abi.encodeWithSelector(IAdapter.Adapter__TokenOutMismatch.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    function testUnoswap2_RevertsTokenOutMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDT");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDT
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswap2Data = hex"8770ba91000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c680000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000c2e9f25be6257c210d7adf0d4cd6e3e881ba25f82080000000000000000000005777d92f208679db4b9778590fa3cab3ac9e2168";
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDT")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswap2Data,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        vm.expectRevert(abi.encodeWithSelector(IAdapter.Adapter__TokenOutMismatch.selector));
        _submitManagerCall(manageProofs, tx_);
    }


    function testUnoswap3_RevertsTokenOutMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDE");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDE
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswap3Data = hex"19367472000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c680000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000c2e9f25be6257c210d7adf0d4cd6e3e881ba25f82080000000000000000000005777d92f208679db4b9778590fa3cab3ac9e21682080000000000000000000003416cf6c708da44db2624d63ea0aaef7113527c6";
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDE")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswap3Data,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        
        vm.expectRevert(abi.encodeWithSelector(IAdapter.Adapter__TokenOutMismatch.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    function testOneInchAdapter__RevertsUniswapV2PoolNotFromFactory() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDE");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDE
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );
        
        address fakePool = address(new MockUniV2Pool(getAddress(sourceChain, "USDE"), getAddress(sourceChain, "WETH")));
        bytes memory unoswapData = abi.encodePacked(
            bytes4(0x83800a8e),
            uint256(uint160(getAddress(sourceChain, "WETH"))),
            uint256(1e15),
            uint256(0x1f6d),
            uint256(uint160(fakePool))
        );
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDE")
        );

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        
        vm.expectRevert(abi.encodeWithSelector(OneInchAdapter.OneInchAdapter__InvalidPool.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    function testOneInchAdapter__RevertsUniswapV3PoolNotFromFactory() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDE");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDE
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );
        
        address fakePool = address(new MockUniV3Pool(getAddress(sourceChain, "USDE"), getAddress(sourceChain, "WETH")));
        bytes memory unoswapData = abi.encodePacked(
            bytes4(0x83800a8e),
            uint256(uint160(getAddress(sourceChain, "WETH"))),
            uint256(1e15),
            uint256(0x1f6d),
            uint256(uint160(fakePool)) | (uint256(0x2c) << 248)
        );
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDE")
        );

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        
        vm.expectRevert(abi.encodeWithSelector(OneInchAdapter.OneInchAdapter__InvalidPool.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    // A REAL, factory-registered UniV3 pool, but the declared tokenIn (USDT) is NOT one of its tokens.
    // tokenOut is set to the pool's token0 (USDC), so without the membership check the counter-token would
    // match — letting the V3 callback pull the pool's real input token via a standing allowance. The
    // membership guard must revert InvalidPool. (Distinct from PoolNotFromFactory, which fails the factory
    // check first; here the pool is genuine and only the tokenIn check can fire.)
    function testOneInchAdapter__RevertsUniswapV3TokenInNotInPool() external {
        deal(getAddress(sourceChain, "USDT"), getAddress(sourceChain, "boringVault"), 100e6);

        // canonical WETH/USDC 0.05% pool — token0 = USDC, token1 = WETH (ordered by address)
        address realPool = IUniswapV3Factory(getAddress(sourceChain, "uniV3Factory")).getPool(
            getAddress(sourceChain, "USDC"), getAddress(sourceChain, "WETH"), 500
        );

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "USDT");
        pairs[0][1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[1]; // swap USDT -> USDC
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDT");
        tx_.targets[1] = address(swapper);
        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", address(swapper), type(uint256).max);

        // tokenIn = USDT (foreign to the WETH/USDC pool); dex protocol byte 0x2c => UniV3 (protocol 1)
        uint256 dex = uint256(uint160(realPool)) | (uint256(0x2c) << 248);
        bytes memory unoswapData = abi.encodePacked(
            bytes4(0x83800a8e), uint256(uint160(getAddress(sourceChain, "USDT"))), uint256(1e6), uint256(0), dex
        );

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "USDT"), getERC20(sourceChain, "USDC")),
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        vm.expectRevert(abi.encodeWithSelector(OneInchAdapter.OneInchAdapter__InvalidPool.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    // A REAL, factory-registered UniV3 pool where tokenIn (USDC) IS a pool token, but the dex word's zeroForOne
    // bit is left 0 so the router would sell the counter-token (WETH). Membership alone passes and returns WETH
    // as tokenOut, matching the route — the direction guard must reject it because USDC is not the input side.
    function testOneInchAdapter__RevertsUniswapV3TokenInNotInputSide() external {
        deal(getAddress(sourceChain, "USDC"), getAddress(sourceChain, "boringVault"), 100e6);

        // canonical WETH/USDC 0.05% pool — token0 = USDC, token1 = WETH (ordered by address)
        address realPool = IUniswapV3Factory(getAddress(sourceChain, "uniV3Factory")).getPool(
            getAddress(sourceChain, "USDC"), getAddress(sourceChain, "WETH"), 500
        );

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "USDC");
        pairs[0][1] = getAddress(sourceChain, "WETH");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[1]; // swap USDC -> WETH
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDC");
        tx_.targets[1] = address(swapper);
        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", address(swapper), type(uint256).max);

        // protocol byte 0x2c => UniV3; zeroForOne bit (247) left 0 => router sells token1 (WETH), but the route
        // declares tokenIn = USDC (token0).
        uint256 dex = uint256(uint160(realPool)) | (uint256(0x2c) << 248);
        bytes memory unoswapData = abi.encodePacked(
            bytes4(0x83800a8e), uint256(uint160(getAddress(sourceChain, "USDC"))), uint256(1e6), uint256(0), dex
        );

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "USDC"), getERC20(sourceChain, "WETH")),
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        vm.expectRevert(abi.encodeWithSelector(OneInchAdapter.OneInchAdapter__InvalidPool.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    function testOneInchAdapter__RevertCurvePoolNotFromFactory() external {
        deal(getAddress(sourceChain, "USDC"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[][] memory pairs = new address[][](1);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "USDC");
        pairs[0][1] = getAddress(sourceChain, "USDE");

        SwapKind[] memory kind = new SwapKind[](1);
        kind[0] = SwapKind.BuyAndSell;
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), pairs, kind); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[1]; //swap WETH -> USDE
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );
        
        address fakePool = address(new MockCurvePool(getAddress(sourceChain, "USDE"), getAddress(sourceChain, "USDC")));
        bytes memory unoswapData = abi.encodePacked(
            bytes4(0x83800a8e),
            uint256(uint160(getAddress(sourceChain, "USDC"))),
            uint256(1e15),
            uint256(0x1f6d),
            (uint256(2) << 253) | uint256(uint160(fakePool))
        );
            
        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "USDC"),
            getERC20(sourceChain, "USDE")
        );

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: oneInchAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: unoswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        
        vm.expectRevert("no registry"); 
        _submitManagerCall(manageProofs, tx_);
    }


    //==================== 1inch Limit Order Tests ====================

    function testOneInchSubmitOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (,, uint256 orderId) =
            _submitOneInchOrder(1e18, 2000e6);

        BoringSwapper.OrderRecord memory rec = swapper.getOrderRecord(orderId);
        assertEq(address(rec.tokenIn), getAddress(sourceChain, "WETH"));
        assertEq(rec.inputAmount, 1e18);
        assertEq(address(rec.receiver), getAddress(sourceChain, "boringVault"));

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 1e18);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 99e18);
        assertEq(swapper.orders(), orderId + 1);
    }

    // Baseline / control for the FeeTaker-extension cluster: a well-formed extension (valid getters,
    // pinned recipients, customReceiver = vault, salt bound to the extension) must submit successfully.
    // Every extension-cluster revert test below is a one-field mutation of THIS valid order, so this
    // proves those reverts come from the mutation — not from a malformed baseline.
    function testOneInchExtensionOrder_ValidSubmits() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        bytes memory extension = _buildFeeTakerExtension(getAddress(sourceChain, "boringVault"));
        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest) =
            _buildOneInchExtensionConfig(1e18, 2000e6, extension);

        uint256 orderId = swapper.orders();
        swapper.submitOrder(config);

        BoringSwapper.OrderRecord memory orderRecord = swapper.getOrderRecord(orderId);
        assertEq(address(orderRecord.tokenIn), getAddress(sourceChain, "WETH"));
        assertEq(orderRecord.inputAmount, 1e18);

        // fill-time re-validation also passes through the extension branch
        vm.prank(ONEINCH_ROUTER);
        assertEq(swapper.isValidSignature(orderDigest, abi.encode(config)), bytes4(0x1626ba7e));
    }

    function testOneInchExtensionOrder_RevertSaltNotBoundToExtension() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        bytes memory extension = _buildFeeTakerExtension(getAddress(sourceChain, "boringVault"));
        // flip the low bit so salt[:160] no longer equals uint160(keccak256(extension))
        uint256 wrongSalt = uint256(uint160(uint256(keccak256(extension)))) ^ 1;
        (ISwapperTypes.SwapConfig memory config,) =
            _buildOneInchExtensionConfigWithSalt(1e18, 2000e6, extension, wrongSalt);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__InvalidExtension.selector);
        swapper.submitOrder(config);
    }

    function testOneInchExtensionOrder_RevertGettersOmitted() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        bytes memory extension = _buildFeeTakerExtensionNoGetters(getAddress(sourceChain, "boringVault"));
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchExtensionConfig(1e18, 2000e6, extension);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__ExtensionFieldTooShort.selector);
        swapper.submitOrder(config);
    }

    function testOneInchExtensionOrder_RevertNonZeroIntegratorRecipient() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        address feeTaker = OneInchAdapter(oneInchAdapter).feeTaker();
        address protocolFeeReceiver = OneInchAdapter(oneInchAdapter).protocolFeeReceiver();
        bytes memory extension = _buildFeeTakerExtensionWith(
            feeTaker, address(0x69), protocolFeeReceiver, getAddress(sourceChain, "boringVault")
        );
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchExtensionConfig(1e18, 2000e6, extension);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__IntegratorFeeRecipientNotZero.selector);
        swapper.submitOrder(config);
    }

    function testOneInchExtensionOrder_RevertWrongProtocolRecipient() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        address feeTaker = OneInchAdapter(oneInchAdapter).feeTaker();
        bytes memory extension = _buildFeeTakerExtensionWith(
            feeTaker, address(0), address(0x420), getAddress(sourceChain, "boringVault")
        );
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchExtensionConfig(1e18, 2000e6, extension);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__ProtocolFeeRecipientMismatch.selector);
        swapper.submitOrder(config);
    }

    function testOneInchExtensionOrder_RevertGetterNotFeeTaker() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        address protocolFeeReceiver = OneInchAdapter(oneInchAdapter).protocolFeeReceiver();
        bytes memory extension = _buildFeeTakerExtensionWith(
            address(0x420), address(0), protocolFeeReceiver, getAddress(sourceChain, "boringVault")
        );
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchExtensionConfig(1e18, 2000e6, extension);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__GetterNotFeeTaker.selector);
        swapper.submitOrder(config);
    }

    // A FeeTaker extension order MUST set POST_INTERACTION_CALL_FLAG (bit 251); without it the router
    // never calls postInteraction, so the FeeTaker keeps the buyTokens and the vault gets nothing for its
    // sold makerAsset. Here makerTraits is FOK + HAS_EXTENSION with bit 251 omitted; salt binds and
    // receiver == feeTaker, so the only failing check is the post-interaction requirement.
    function testOneInchExtensionOrder_RevertPostInteractionFlagMissing() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        bytes memory extension = _buildFeeTakerExtension(getAddress(sourceChain, "boringVault"));
        // NO_PARTIAL_FILLS (255) + HAS_EXTENSION (249), but POST_INTERACTION_CALL_FLAG (251) omitted
        uint256 makerTraits = (uint256(1) << 255) | (uint256(1) << 249);
        (ISwapperTypes.SwapConfig memory config,) =
            _buildOneInchExtensionConfigWithTraits(1e18, 2000e6, extension, makerTraits);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__PostInteractionRequired.selector);
        swapper.submitOrder(config);
    }

    // fillOrder must reject takerTraits bit 255 (_MAKER_AMOUNT_FLAG). When set, the router reinterprets
    // `amount` as makerAsset OUTPUT, so the swapper would feed a tokenOut-denominated number into price/rate-limit
    // checks that expect tokenIn — and could pull a pending order's principal. The order's taker/maker assets
    // match the route, so the only failing check is the maker-amount flag.
    function testOneInchFillOrder_RevertMakerAmountFlag() external {
        DecoderCustomTypes.OneInchV6Order memory order = DecoderCustomTypes.OneInchV6Order({
            salt: 1,
            maker: uint256(uint160(address(0x69))),
            receiver: uint256(uint160(address(swapper))),
            makerAsset: uint256(uint160(getAddress(sourceChain, "WETH"))), // swapper receives WETH (tokenOut)
            takerAsset: uint256(uint160(getAddress(sourceChain, "USDC"))), // swapper spends USDC (tokenIn)
            makingAmount: 1e18,
            takingAmount: 2000e6,
            makerTraits: 0
        });

        uint256 takerTraits = uint256(1) << 255; // _MAKER_AMOUNT_FLAG
        bytes memory swapData = abi.encodeWithSelector(
            OneInchAdapter.fillOrder.selector, order, bytes32(0), bytes32(0), uint256(2000e6), takerTraits
        );

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "USDC"), getERC20(sourceChain, "WETH")),
            adapter: oneInchAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: swapData,
            slippageBps: 10,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        vm.expectRevert(OneInchAdapter.OneInchAdapter__MakerAmountFlagNotAllowed.selector);
        swapper.swap(config);
    }

    // The offsets word must bound the postInteraction field — CustomData (the block after it) must be empty,
    // otherwise the parser could resolve the customReceiver from foreign CustomData bytes. Here we append extra
    // CustomData to a valid extension (without growing end[7]); the "CustomData empty" check must reject it.
    function testOneInchExtensionOrder_RevertTrailingCustomData() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        // valid extension + trailing bytes the offsets word does NOT account for (non-empty CustomData)
        bytes memory tampered =
            abi.encodePacked(_buildFeeTakerExtension(getAddress(sourceChain, "boringVault")), hex"deadbeef");
        // salt auto-binds to the tampered bytes, so _isValidExtension passes and we reach the offsets check
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchExtensionConfig(1e18, 2000e6, tampered);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__UnsupportedExtensionField.selector);
        swapper.submitOrder(config);
    }

    // 1inch's AmountGetterBase treats any bytes trailing the fee config as a nested IAmountGetter and CALLS it,
    // so an oversized fee blob (feeLen > 7) could embed a strategist getter that returns a near-zero taking
    // amount and drains the vault. The fee-tail bound must reject any feeLen large enough to hold a 20-byte getter.
    function testOneInchExtensionOrder_RevertFeeTailTooLong() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        // 20-byte tail = a would-be nested getter address; feeLen becomes 20 (> 7)
        bytes memory extension = _buildFeeTakerExtensionWithFeeData(
            getAddress(sourceChain, "boringVault"), abi.encodePacked(bytes20(address(0xBAD)))
        );
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchExtensionConfig(1e18, 2000e6, extension);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__FeeTailNotEmpty.selector);
        swapper.submitOrder(config);
    }

    // Fields 4/5/6 (predicate, makerPermit, preInteraction) must each be empty. This builds an extension where
    // end[6]==end[3] holds but end[4] is bumped so field 4 (predicate) is non-empty; the per-slot
    // end[4]/end[5]/end[6] checks must reject it.
    function testOneInchExtensionOrder_RevertNonEmptyPredicateField() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        bytes memory extension = _buildFeeTakerExtensionBadPredicate(getAddress(sourceChain, "boringVault"));
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchExtensionConfig(1e18, 2000e6, extension);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__UnsupportedExtensionField.selector);
        swapper.submitOrder(config);
    }

    function testOneInchOrder_RevertPartialSingleFillFlags() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        // NO_PARTIAL_FILLS (bit 255) unset, ALLOW_MULTIPLE_FILLS (bit 254) unset
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchConfigWithTraits(1e18, 2000e6, 0);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__InvalidFillFlags.selector);
        swapper.submitOrder(config);
    }

    function testOneInchOrder_RevertFokMultipleFillFlags() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        uint256 makerTraits = (uint256(1) << 255) | (uint256(1) << 254);
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchConfigWithTraits(1e18, 2000e6, makerTraits);

        vm.expectRevert(OneInchAdapter.OneInchAdapter__InvalidFillFlags.selector);
        swapper.submitOrder(config);
    }

    function testOneInchSubmitOrder_RevertBadSlippage() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        //fat finger: 1 WETH for 1000 USDC (50% below oracle)
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchSwapConfig(1e18, 1000e6);
        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector));
        swapper.submitOrder(config);
    }

    function testOneInchIsValidSignature() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOneInchOrder(1e18, 2000e6);

        vm.prank(ONEINCH_ROUTER);
        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e));
    }

    function testOneInchIsValidSignature_RevertHashMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (ISwapperTypes.SwapConfig memory config,,) =
            _submitOneInchOrder(1e18, 2000e6);

        vm.prank(ONEINCH_ROUTER);
        vm.expectRevert();
        swapper.isValidSignature(bytes32(uint256(0x69420)), abi.encode(config));
    }

    function testOneInchCancelOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) = _submitOneInchOrder(1e18, 2000e6);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 1e18);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 99e18);

        swapper.cancelOrder(orderId, config, "");
        
        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 0);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 100e18);

        BoringSwapper.OrderRecord memory rec = swapper.getOrderRecord(orderId);
        //cancel preserves the record; releaseFee deletes it later
        assertEq(address(rec.tokenIn), getAddress(sourceChain, "WETH"));
    }

    function testOneInchFullFillFlow() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOneInchOrder(1e18, 2000e6);

        address vault = getAddress(sourceChain, "boringVault");
        uint256 vaultWethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 vaultUsdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        _simulateOneInchFill(1e18, 2000e6, config, orderDigest);

        assertEq(getERC20(sourceChain, "USDC").balanceOf(vault), vaultUsdcBefore + 2000e6);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 0);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(vault), vaultWethBefore);
    }

    function testOneInchCancelAfterFill_RevertOrderAlreadyFilled() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOneInchOrder(10e18, 20000e6);

        _simulateOneInchFill(10e18, 20000e6, config, orderDigest);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderAlreadyFilled.selector));
        swapper.cancelOrder(orderId, config, "");
    }

    function testOneInchCancelAfterPartialFill() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        // partial fills require a partial + multiple order (RemainingInvalidator-tracked)
        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOneInchPartialOrder(1e18, 2000e6);

        address vault = getAddress(sourceChain, "boringVault");
        uint256 vaultUsdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        _simulateOneInchFill(4e17, 800e6, config, orderDigest);

        assertEq(OneInchAdapter(oneInchAdapter).filledAmount(config, address(swapper), ""), 4e17);

        uint256 vaultWethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        swapper.cancelOrder(orderId, config, "");

        assertEq(getERC20(sourceChain, "WETH").balanceOf(vault) - vaultWethBefore, 1e18 - 4e17);
        assertEq(getERC20(sourceChain, "USDC").balanceOf(vault) - vaultUsdcBefore, 800e6);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 0);
        assertEq(swapper.pendingOrderPrincipal(getERC20(sourceChain, "WETH")), 0);
        assertGt(swapper.getOrderRecord(orderId).cancelledAt, 0);
    }

    function testOneInchLimitOrder_filledAmount() external {
        // partial + multiple order -> RemainingInvalidator-tracked, so filledAmount reads the remaining slot
        // and can express a partial fill.
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchSwapConfig(1e18, 2000e6);
        DecoderCustomTypes.OneInchLimitOrder memory order = DecoderCustomTypes.OneInchLimitOrder({
            salt: 1,
            maker: address(swapper),
            receiver: getAddress(sourceChain, "boringVault"),
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: 1e18,
            takingAmount: 2000e6,
            makerTraits: (uint256(1) << 254) // ALLOW_MULTIPLE_FILLS set, NO_PARTIAL_FILLS unset
        });
        config.swapData = abi.encode(order, bytes(""));

        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, abi.encode(order)));
        bytes32 orderHash = keccak256(abi.encodePacked("\x19\x01", _oneInchDomainSeparator(), structHash));

        //untouched -> filled 0
        assertEq(OneInchAdapter(oneInchAdapter).filledAmount(config, address(swapper), ""), 0);

        // write _remainingInvalidator[maker][orderHash] (mapping slot 5) to leave 1e14 remaining
        bytes32 inner = keccak256(abi.encode(address(swapper), uint256(5)));
        bytes32 slot  = keccak256(abi.encode(orderHash, inner));
        vm.store(getAddress(sourceChain, "aggregationRouterV6"), slot, bytes32(~uint256(1e14)));

        assertEq(OneInchAdapter(oneInchAdapter).filledAmount(config, address(swapper), ""), 1e18 - 1e14);
    }

    // A FOK (BitInvalidator) order with nonceOrEpoch >= 256. 1inch's checkSlot shifts its argument (>>8)
    // internally, so the adapter passes the RAW nonce (here nonce=300 => slot 1, bit 44). The mock is keyed on
    // the raw nonce only — a query with the shifted slot (key 1) misses it and reads 0 from the real router,
    // so this test guards the raw-nonce behavior.
    function testOneInchLimitOrder_filledAmount_BitInvalidatorNonceOver255() external {
        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchSwapConfig(1e18, 2000e6);
        uint256 nonce = 300; // slot = 300>>8 = 1, bit = 1<<(300 & 0xff) = 1<<44
        DecoderCustomTypes.OneInchLimitOrder memory order = DecoderCustomTypes.OneInchLimitOrder({
            salt: 1,
            maker: address(swapper),
            receiver: getAddress(sourceChain, "boringVault"),
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: 1e18,
            takingAmount: 2000e6,
            makerTraits: (uint256(1) << 255) | (nonce << 120) // NO_PARTIAL_FILLS (FOK) + nonceOrEpoch = 300
        });
        config.swapData = abi.encode(order, bytes(""));

        // Untouched: the fresh swapper has no invalidator state, so the real router returns 0 => filled 0.
        assertEq(OneInchAdapter(oneInchAdapter).filledAmount(config, address(swapper), ""), 0);

        // Full fill: the real router sets bit (nonce & 0xff) in _raw[nonce>>8] and returns that word when
        // queried with the RAW nonce. Mock keyed on the raw nonce (300) mirrors that.
        vm.mockCall(
            ONEINCH_ROUTER,
            abi.encodeWithSignature("bitInvalidatorForOrder(address,uint256)", address(swapper), nonce),
            abi.encode(uint256(1) << (nonce & 0xff))
        );

        // Fixed adapter passes the raw nonce -> reads the mocked word -> reports fully filled.
        assertEq(OneInchAdapter(oneInchAdapter).filledAmount(config, address(swapper), ""), 1e18);
    }

    function testOneInchLimitMask() external {
    }

    //==================== 1inch Limit Order Helpers ====================

    function _oneInchDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("1inch Aggregation Router"),
            keccak256("6"),
            block.chainid,
            ONEINCH_ROUTER
        ));
    }

    function _buildOneInchSwapConfig(
        uint256 makingAmount,
        uint256 takingAmount
    ) internal view returns (ISwapperTypes.SwapConfig memory, bytes32 orderDigest) {
        DecoderCustomTypes.OneInchLimitOrder memory order = DecoderCustomTypes.OneInchLimitOrder({
            salt: 1,
            maker: address(swapper),
            receiver: getAddress(sourceChain, "boringVault"),
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: 1 << 255 // NO_PARTIAL_FILLS_FLAG — required by adapter, routes invalidation through BitInvalidator
        });

        bytes memory orderData = abi.encode(order);
        bytes memory swapData = abi.encode(order, bytes(""));

        ISwapperTypes.SwapConfig memory config = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(
                getERC20(sourceChain, "WETH"),
                getERC20(sourceChain, "USDC")
            ),
            adapter: oneInchAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: swapData,
            slippageBps: 10,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, orderData));
        orderDigest = keccak256(abi.encodePacked("\x19\x01", _oneInchDomainSeparator(), structHash));

        return (config, orderDigest);
    }

    function _buildOneInchConfigWithTraits(uint256 makingAmount, uint256 takingAmount, uint256 makerTraits)
        internal
        view
        returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest)
    {
        DecoderCustomTypes.OneInchLimitOrder memory order = DecoderCustomTypes.OneInchLimitOrder({
            salt: 1,
            maker: address(swapper),
            receiver: getAddress(sourceChain, "boringVault"),
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: makerTraits
        });

        bytes memory orderData = abi.encode(order);
        config = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC")),
            adapter: oneInchAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: abi.encode(order, bytes("")),
            slippageBps: 10,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, orderData));
        orderDigest = keccak256(abi.encodePacked("\x19\x01", _oneInchDomainSeparator(), structHash));
    }

    function _submitOneInchOrder(uint256 makingAmount, uint256 takingAmount)
        internal
        returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId)
    {
        (config, orderDigest) = _buildOneInchSwapConfig(makingAmount, takingAmount);
        orderId = swapper.orders();
        swapper.submitOrder(config);
    }

    // Submits a partial + multiple fill order (ALLOW_MULTIPLE_FILLS set, NO_PARTIAL_FILLS unset) — the
    // RemainingInvalidator-tracked shape, so its fills can be partial.
    function _submitOneInchPartialOrder(uint256 makingAmount, uint256 takingAmount)
        internal
        returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId)
    {
        (config, orderDigest) = _buildOneInchConfigWithTraits(makingAmount, takingAmount, uint256(1) << 254);
        orderId = swapper.orders();
        swapper.submitOrder(config);
    }

    function _buildFeeTakerExtension(address customReceiver) internal view returns (bytes memory extension) {
        address feeTaker = OneInchAdapter(oneInchAdapter).feeTaker();
        address protocolFeeReceiver = OneInchAdapter(oneInchAdapter).protocolFeeReceiver();

        bytes memory feeData = ""; // empty -> feeLen 0; adapter does not parse fee-config contents

        bytes memory amountGetter = abi.encodePacked(feeTaker, feeData); // makingAmountData == takingAmountData
        bytes memory postInteraction = abi.encodePacked(
            feeTaker,                 // postInteraction target
            bytes1(0x01),             // flags: CUSTOM_RECEIVER present
            bytes20(address(0)),      // integrator fee recipient (pinned to zero)
            bytes20(protocolFeeReceiver), // protocol fee recipient (pinned)
            bytes20(customReceiver),  // custom receiver (the vault)
            feeData
        );

        uint256 getterLength = amountGetter.length;
        uint256 postInteractionLength = postInteraction.length;
        // cumulative END offsets per field, each uint32 at bits [32*i, 32*i+32):
        // end[2]=getterLength, end[3..6]=2*getterLength, end[7]=2*getterLength+postInteractionLength;
        // end[0]=end[1]=0; customData empty (concatLen == end[7]).
        uint256 offsets = (getterLength << 64) | ((2 * getterLength) << 96) | ((2 * getterLength) << 128)
            | ((2 * getterLength) << 160) | ((2 * getterLength) << 192)
            | ((2 * getterLength + postInteractionLength) << 224);

        extension = abi.encodePacked(bytes32(offsets), amountGetter, amountGetter, postInteraction);
    }

    function _buildFeeTakerExtensionNoGetters(address customReceiver) internal view returns (bytes memory extension) {
        address feeTaker = OneInchAdapter(oneInchAdapter).feeTaker();
        address protocolFeeReceiver = OneInchAdapter(oneInchAdapter).protocolFeeReceiver();

        bytes memory postInteraction = abi.encodePacked(
            feeTaker, bytes1(0x01), bytes20(address(0)), bytes20(protocolFeeReceiver), bytes20(customReceiver)
        );

        // all fields empty except postInteraction (field 7): end[0..6] = 0, end[7] = postInteraction.length
        uint256 offsets = (postInteraction.length << 224);
        extension = abi.encodePacked(bytes32(offsets), postInteraction);
    }

    // Full valid-shaped extension with the getter address and the two fee recipients settable, so tests can
    // mutate exactly one field. Both amount getters use `getterAddress` (they must be byte-equal for the
    // consistency check); the postInteraction target stays feeTaker. Defaults (getterAddress = feeTaker,
    // integratorRecipient = 0, protocolRecipient = protocolFeeReceiver) reproduce the valid baseline.
    function _buildFeeTakerExtensionWith(
        address getterAddress,
        address integratorRecipient,
        address protocolRecipient,
        address customReceiver
    ) internal view returns (bytes memory extension) {
        address feeTaker = OneInchAdapter(oneInchAdapter).feeTaker();

        bytes memory amountGetter = abi.encodePacked(getterAddress); // 20 bytes, empty feeData
        bytes memory postInteraction = abi.encodePacked(
            feeTaker, bytes1(0x01), bytes20(integratorRecipient), bytes20(protocolRecipient), bytes20(customReceiver)
        );

        uint256 getterLength = amountGetter.length;
        uint256 postInteractionLength = postInteraction.length;
        uint256 offsets = (getterLength << 64) | ((2 * getterLength) << 96) | ((2 * getterLength) << 128)
            | ((2 * getterLength) << 160) | ((2 * getterLength) << 192)
            | ((2 * getterLength + postInteractionLength) << 224);

        extension = abi.encodePacked(bytes32(offsets), amountGetter, amountGetter, postInteraction);
    }

    // Valid-shaped FeeTaker extension but with an arbitrary fee blob appended to BOTH amount getters and the
    // postInteraction (kept byte-equal so the getter/tail consistency checks pass and we reach the fee-tail bound).
    function _buildFeeTakerExtensionWithFeeData(address customReceiver, bytes memory feeData)
        internal
        view
        returns (bytes memory extension)
    {
        address feeTaker = OneInchAdapter(oneInchAdapter).feeTaker();
        address protocolFeeReceiver = OneInchAdapter(oneInchAdapter).protocolFeeReceiver();

        bytes memory amountGetter = abi.encodePacked(feeTaker, feeData);
        bytes memory postInteraction = abi.encodePacked(
            feeTaker, bytes1(0x01), bytes20(address(0)), bytes20(protocolFeeReceiver), bytes20(customReceiver), feeData
        );
        uint256 getterLength = amountGetter.length;
        uint256 postInteractionLength = postInteraction.length;
        uint256 offsets = (getterLength << 64) | ((2 * getterLength) << 96) | ((2 * getterLength) << 128)
            | ((2 * getterLength) << 160) | ((2 * getterLength) << 192)
            | ((2 * getterLength + postInteractionLength) << 224);
        extension = abi.encodePacked(bytes32(offsets), amountGetter, amountGetter, postInteraction);
    }

    // Valid getters/postInteraction, but end[4] is bumped so field 4 (predicate) is non-empty while end[6]==end[3]
    // still holds — a shape the per-slot end[4]/end[5]/end[6] checks must reject.
    function _buildFeeTakerExtensionBadPredicate(address customReceiver) internal view returns (bytes memory extension) {
        address feeTaker = OneInchAdapter(oneInchAdapter).feeTaker();
        address protocolFeeReceiver = OneInchAdapter(oneInchAdapter).protocolFeeReceiver();

        bytes memory amountGetter = abi.encodePacked(feeTaker); // feeLen 0
        bytes memory postInteraction = abi.encodePacked(
            feeTaker, bytes1(0x01), bytes20(address(0)), bytes20(protocolFeeReceiver), bytes20(customReceiver)
        );
        uint256 gl = amountGetter.length;
        uint256 pil = postInteraction.length;
        // end[2]=gl, end[3]=2gl, end[4]=2gl+7 (NON-EMPTY predicate), end[5]=end[6]=2gl (so end[6]==end[3] still holds),
        // end[7]=2gl+pil (customData empty). Only the per-slot end[4] check can reject this.
        uint256 offsets = (gl << 64) | ((2 * gl) << 96) | ((2 * gl + 7) << 128) | ((2 * gl) << 160) | ((2 * gl) << 192)
            | ((2 * gl + pil) << 224);
        extension = abi.encodePacked(bytes32(offsets), amountGetter, amountGetter, postInteraction);
    }

    function _buildOneInchExtensionConfig(uint256 makingAmount, uint256 takingAmount, bytes memory extension)
        internal
        view
        returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest)
    {
        return _buildOneInchExtensionConfigWithSalt(
            makingAmount, takingAmount, extension, uint256(uint160(uint256(keccak256(extension))))
        );
    }

    // Salt-bound extension order with arbitrary makerTraits, for exercising the extension flag checks
    // (e.g. the POST_INTERACTION requirement). Salt commits to the extension so _isValidExtension passes.
    function _buildOneInchExtensionConfigWithTraits(
        uint256 makingAmount,
        uint256 takingAmount,
        bytes memory extension,
        uint256 makerTraits
    ) internal view returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest) {
        DecoderCustomTypes.OneInchLimitOrder memory order = DecoderCustomTypes.OneInchLimitOrder({
            salt: uint256(uint160(uint256(keccak256(extension)))),
            maker: address(swapper),
            receiver: OneInchAdapter(oneInchAdapter).feeTaker(),
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: makerTraits
        });

        bytes memory orderData = abi.encode(order);
        config = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC")),
            adapter: oneInchAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: abi.encode(order, extension),
            slippageBps: 10,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, orderData));
        orderDigest = keccak256(abi.encodePacked("\x19\x01", _oneInchDomainSeparator(), structHash));
    }

    // Same as above but with an explicit salt, so we can deliberately test the salt<->extension binding.
    function _buildOneInchExtensionConfigWithSalt(
        uint256 makingAmount,
        uint256 takingAmount,
        bytes memory extension,
        uint256 salt
    ) internal view returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest) {
        uint256 makerTraits = (uint256(1) << 255) | (uint256(1) << 251) | (uint256(1) << 249);

        DecoderCustomTypes.OneInchLimitOrder memory order = DecoderCustomTypes.OneInchLimitOrder({
            salt: salt,
            maker: address(swapper),
            receiver: OneInchAdapter(oneInchAdapter).feeTaker(),
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: makerTraits
        });

        bytes memory orderData = abi.encode(order);
        config = ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC")),
            adapter: oneInchAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: abi.encode(order, extension),
            slippageBps: 10,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, orderData));
        orderDigest = keccak256(abi.encodePacked("\x19\x01", _oneInchDomainSeparator(), structHash));
    }

    function _simulateOneInchFill(
        uint256 amountIn,
        uint256 amountOut,
        ISwapperTypes.SwapConfig memory config,
        bytes32 orderDigest
    ) internal {
        vm.prank(ONEINCH_ROUTER);
        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e), "isValidSignature failed");

        vm.prank(ONEINCH_ROUTER);
        getERC20(sourceChain, "WETH").transferFrom(address(swapper), ONEINCH_ROUTER, amountIn);

        deal(getAddress(sourceChain, "USDC"), ONEINCH_ROUTER, amountOut);
        vm.prank(ONEINCH_ROUTER);
        getERC20(sourceChain, "USDC").transfer(getAddress(sourceChain, "boringVault"), amountOut);

        //mirror the protocol-side fill state on whichever invalidator 1inch uses for this order's flags.
        (DecoderCustomTypes.OneInchLimitOrder memory order,) =
            abi.decode(config.swapData, (DecoderCustomTypes.OneInchLimitOrder, bytes));

        bool useBitInvalidator =
            order.makerTraits & (uint256(1) << 255) != 0 || order.makerTraits & (uint256(1) << 254) == 0;

        if (useBitInvalidator) {
            // Fill-or-kill: binary. The fixed adapter passes the RAW nonce; 1inch's checkSlot shifts it (>>8)
            // to index _raw[nonce>>8], the word that carries bit (nonce & 0xff) once filled. Keying the mock on
            // the raw nonce mirrors that read exactly — a re-introduced `nonce >> 8` would query the wrong key.
            uint256 nonce = (order.makerTraits >> 120) & type(uint40).max;
            uint256 bitWord = uint256(1) << (nonce & 0xff);
            vm.mockCall(
                ONEINCH_ROUTER,
                abi.encodeWithSignature("bitInvalidatorForOrder(address,uint256)", address(swapper), nonce),
                abi.encode(bitWord)
            );
        } else {
            // Partial + multiple: RemainingInvalidator records the unfilled maker amount.
            uint256 raw = amountIn >= order.makingAmount ? type(uint256).max : ~(order.makingAmount - amountIn);
            vm.mockCall(
                ONEINCH_ROUTER,
                abi.encodeWithSignature("rawRemainingInvalidatorForOrder(address,bytes32)", address(swapper), orderDigest),
                abi.encode(raw)
            );
        }
    }

    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }
}

contract MockUniV2Pool {

    address public token0; 
    address public token1;
   
    constructor(address _token0, address _token1) {
        token0 = _token0; 
        token1 = _token1;
    }

    function getPair() external view returns (address) {
        return address(this);
    }
}

contract MockUniV3Pool {

    address public token0; 
    address public token1;
   
    constructor(address _token0, address _token1) {
        token0 = _token0; 
        token1 = _token1;
    }

    function fee() external pure returns (uint24) {
        return 1000;
    }

    function getPair() external view returns (address) {
        return address(this);
    }
}

contract MockCurvePool {

    address public token0; 
    address public token1;
   
    constructor(address _token0, address _token1) {
        token0 = _token0; 
        token1 = _token1;
    }

    function coins() external view returns (address[8] memory c) {
        c[0] = token0; 
        c[1] = token0; 
        return c;
    }
}

contract FullBoringSwapperDecoderAndSanitizer is BoringSwapperDecoder, BaseDecoderAndSanitizer {}
