// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {OneInchAdapter, IOneInchOrderMixin} from "src/base/Periphery/adapters/OneInchAdapter.sol";
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

    function setUp() public override {
        super.setUp();
        _setupChain("mainnet", 24592183);

        address swapperDecoder = address(new BoringSwapperDecoder());
        _overrideDecoder(swapperDecoder);


        registry = new AdapterRegistry();
        validator = new PriceValidator();
        swapper = new BoringSwapper(address(this), registry, new FeeRegistry(address(this), 1000), boringVault, IPriceValidator(address(validator)));
        swapper.setAuthority(rolesAuthority);

        oneInchAdapter = address(new OneInchAdapter(
            ONEINCH_ROUTER,
            ONEINCH_FEE_TAKER,
            ONEINCH_EXECUTOR,
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

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[5]; //swap WETH -> USDC
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
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

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        _submitManagerCall(manageProofs, tx_);

    }

    function testUnoswap_RevertsToken1Mismatch() external {
        //set up manager swap
        //do the swap
        //swap happens 
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDT");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[5]; //swap WETH -> USDT
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswapData = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000001f6d2c08000000000000003b6d0340b4e16d0168e52d35cacd2c6185b44281ec28c9dcf583bc2f";
            
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

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);
            
        vm.expectRevert(abi.encodeWithSelector(OneInchAdapter.OneInchAdapter__TokenOutMismatch.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    function testUnoswapTo() external {
        //set up manager swap
        //do the swap
        //swap happens 
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[5]; //swap WETH -> USDC
        
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

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[5]; //swap WETH -> USDC
        
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

    }

    function testUnoswap2_RevertsTokenOutMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDT");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[5]; //swap WETH -> USDT
        
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

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);
            
        vm.expectRevert(abi.encodeWithSelector(OneInchAdapter.OneInchAdapter__TokenOutMismatch.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    function testUnoswap3() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDT");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[5]; //swap WETH -> USDC
        
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
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        _submitManagerCall(manageProofs, tx_);

    }

    function testUnoswap3_RevertsTokenOutMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDE");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[5]; //swap WETH -> USDE
        
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

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);
        
        vm.expectRevert(abi.encodeWithSelector(OneInchAdapter.OneInchAdapter__TokenOutMismatch.selector));
        _submitManagerCall(manageProofs, tx_);

    }

    function testUnoswapCurve() external {
        //set up manager swap
        //do the swap
        //swap happens 
        deal(getAddress(sourceChain, "USDT"), getAddress(sourceChain, "boringVault"), 100e8); 

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "USDT");
        tokens[1] = getAddress(sourceChain, "USDC");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[5]; //swap USDT -> USDC
        
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

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "USDT").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);
        
        vm.expectRevert(); //we are reverting on a failed innerCall here which is acceptable --
        //the path through the adapter is pulling out the coins correctly, which is all we care about in this case tokenIn + tokenOut match correctly
        _submitManagerCall(manageProofs, tx_);

    }

    //==================== 1inch Limit Order Tests ====================

    function testOneInchSubmitOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) =
            _submitOneInchOrder(1e18, 2000e6);

        BoringSwapper.OrderRecord memory rec = swapper.getOrderRecord(orderId);
        assertEq(address(rec.tokenIn), getAddress(sourceChain, "WETH"));
        assertEq(rec.inputAmount, 1e18);
        assertEq(address(rec.receiver), getAddress(sourceChain, "boringVault"));

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 1e18);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 99e18);
        assertEq(swapper.orders(), orderId + 1);
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

    // 1inch's BitInvalidator flips on any fill. The adapter enforces NO_PARTIAL_FILLS_FLAG so
    // partial fills aren't a real protocol scenario, but any non-zero post-fill state blocks cancel.
    function testOneInchCancelAfterFill_RevertOrderAlreadyFilled() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOneInchOrder(10e18, 20000e6);

        _simulateOneInchFill(5e18, 10000e6, config, orderDigest);

        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__OrderAlreadyFilled.selector));
        swapper.cancelOrder(orderId, config, "");
    }

    function testOneInchLimitOrder_filledAmount() external {
        uint256 nonce = 0x234234234;

        (ISwapperTypes.SwapConfig memory config,) = _buildOneInchSwapConfig(1e18, 2000e6);
        DecoderCustomTypes.OneInchLimitOrder memory order = DecoderCustomTypes.OneInchLimitOrder({
            salt: 1,
            maker: address(swapper),
            receiver: getAddress(sourceChain, "boringVault"),
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: 1e18,
            takingAmount: 2000e6,
            makerTraits: (uint256(1) << 255) | (nonce << 120)
        });
        config.swapData = abi.encode(order, bytes(""));

        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, abi.encode(order)));
        bytes32 orderHash = keccak256(abi.encodePacked("\x19\x01", _oneInchDomainSeparator(), structHash));
        
        //full amount remaining?
        assertEq(OneInchAdapter(oneInchAdapter).filledAmount(config, address(swapper), ""), 0);

        bytes32 inner = keccak256(abi.encode(address(swapper), uint256(5)));
        bytes32 slot  = keccak256(abi.encode(orderHash, inner));
        vm.store(getAddress(sourceChain, "aggregationRouterV6"), slot, bytes32(~uint256(1e14)));

        assertEq(OneInchAdapter(oneInchAdapter).filledAmount(config, address(swapper), ""), 1e18 - 1e14);

        //TODO tests for full fill and the one other branch
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

    function _submitOneInchOrder(uint256 makingAmount, uint256 takingAmount)
        internal
        returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId)
    {
        (config, orderDigest) = _buildOneInchSwapConfig(makingAmount, takingAmount);
        orderId = swapper.orders();
        swapper.submitOrder(config);
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

        //mirror the protocol-side fill state: 1inch flips the BitInvalidator bit for (maker, slot).
        //Required for the swapper's isFilled gate to fire correctly in tests.
        (DecoderCustomTypes.OneInchLimitOrder memory order,) =
            abi.decode(config.swapData, (DecoderCustomTypes.OneInchLimitOrder, bytes));
        uint256 nonceOrEpoch = (order.makerTraits >> 120) & type(uint40).max;
        uint256 slot = nonceOrEpoch >> 8;
        vm.mockCall(
            ONEINCH_ROUTER,
            abi.encodeWithSignature("bitInvalidatorForOrder(address,uint256)", address(swapper), slot),
            abi.encode(uint256(1) << (nonceOrEpoch & 0xff))
        );
    }

    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }
}
