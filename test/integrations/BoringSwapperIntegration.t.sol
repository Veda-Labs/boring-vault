// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {UniswapV3Adapter} from "src/base/Periphery/adapters/UniswapV3Adapter.sol"; 
import {CowswapAdapter, IDomainSeparator} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {OneInchAdapter} from "src/base/Periphery/adapters/OneInchAdapter.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";
import {Test, console} from "@forge-std/Test.sol";


contract BoringSwapperIntegration is BaseTestIntegration {

    // CoW Protocol constants BEGIN //
    address constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;

    address uniswapV3Adapter;
    address cowswapAdapter;
    address oneInchAdapter;

    bytes32 constant GPV2_ORDER_TYPE_HASH = keccak256(
        "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,string kind,bool partiallyFillable,string sellTokenBalance,string buyTokenBalance)");

    bytes32 constant KIND_SELL = keccak256("sell");
    bytes32 constant BALANCE_ERC20 = keccak256("erc20");

    // CoW Protocol constants END //

    // 1inch constants BEGIN //
    address constant ONEINCH_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;
    address constant ONEINCH_FEE_TAKER = address(0);
    address constant ONEINCH_EXECUTOR = 0x990636ecB3FF04d33D92e970d3d588bF5cD8d086;

    bytes32 constant ONEINCH_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"
    );
    // 1inch constants END //

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    uint8 constant SWAPPER_VAULT_ROLE = 10;

    MockRateProvider usdRate;
    MockRateProvider ethRate;

    function setUp() public override {
        super.setUp(); 
        _setupChain("mainnet", 24592183); 
            
        address swapperDecoder = address(new BoringSwapperDecoder()); 

        _overrideDecoder(swapperDecoder); 

        registry = new AdapterRegistry(); 

        //do additional setup here
        swapper = new BoringSwapper(address(this), registry, IFeeRegistry(address(0)));

        // auth: vault can call swap functions; address(this) (owner) can call directly in tests
        swapper.setAuthority(rolesAuthority);
        rolesAuthority.setUserRole(getAddress(sourceChain, "boringVault"), SWAPPER_VAULT_ROLE, true);
        rolesAuthority.setUserRole(address(this), SWAPPER_VAULT_ROLE, true);
        rolesAuthority.setRoleCapability(SWAPPER_VAULT_ROLE, address(swapper), BoringSwapper.swap.selector, true);
        rolesAuthority.setRoleCapability(SWAPPER_VAULT_ROLE, address(swapper), BoringSwapper.submitOrder.selector, true);
        rolesAuthority.setRoleCapability(SWAPPER_VAULT_ROLE, address(swapper), BoringSwapper.cancelOrder.selector, true);
        rolesAuthority.setRoleCapability(SWAPPER_VAULT_ROLE, address(swapper), BoringSwapper.replaceOrder.selector, true);
        rolesAuthority.setRoleCapability(SWAPPER_VAULT_ROLE, address(swapper), BoringSwapper.setFeeRegistry.selector, true);

        uniswapV3Adapter = address(new UniswapV3Adapter(getAddress(sourceChain, "uniV3Router")));
        cowswapAdapter = address(new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER));
        oneInchAdapter = address(new OneInchAdapter(ONEINCH_ROUTER, ONEINCH_FEE_TAKER, ONEINCH_EXECUTOR));

        swapper.setApprovedRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), true, 50, 0, 0);
        swapper.setApprovedAdapter(uniswapV3Adapter, true);
        swapper.setApprovedAdapter(cowswapAdapter, true);
        swapper.setApprovedAdapter(oneInchAdapter, true);

        registry.put(uniswapV3Adapter, "UNISWAP_V3");
        registry.put(cowswapAdapter, "COWSWAP");
        registry.put(oneInchAdapter, "ONEINCH");

        //oracle setup
        usdRate = new MockRateProvider(1e18);
        ethRate = new MockRateProvider(2000e18);
        address usdQuoteAsset = getAddress(sourceChain, "USDC");

        swapper.setTokenOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, _makeOracleConfig(address(usdRate), address(0), false));
        swapper.setTokenOracle(getERC20(sourceChain, "WETH"), usdQuoteAsset, _makeOracleConfig(address(ethRate), address(0), false));

        //price validator setup
        validator = new PriceValidator();
        swapper.setPriceValidator(IPriceValidator(validator));

    }

    function testUniV3Swap() external {
        //create tokens array
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

        bytes memory uniswapSwapData = abi.encodeWithSignature(
            "exactInput((bytes,address,uint256,uint256,uint256))",
            DecoderCustomTypes.ExactInputParams({
                path: abi.encodePacked(getAddress(sourceChain, "WETH"), uint24(500), getAddress(sourceChain, "USDC")),
                recipient: address(swapper),
                deadline: block.timestamp,
                amountIn: 1e18,
                amountOutMinimum: 0
            })
        );
            
        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            BoringSwapper.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: uniswapV3Adapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: uniswapSwapData,
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

        console.log("WETH before:", wethBefore);
        console.log("WETH after:", wethAfter);
        console.log("WETH spent:", wethBefore - wethAfter);
        console.log("USDC before:", usdcBefore);
        console.log("USDC after:", usdcAfter);
        console.log("USDC received:", usdcAfter - usdcBefore);

        // Expected USDC: 1 ETH * $2000 = 2000 USDC (2000e6)
        uint256 expectedUsdc = 2000e6;
        uint256 actualUsdc = usdcAfter - usdcBefore;
        console.log("Expected USDC:", expectedUsdc);
        if (actualUsdc >= expectedUsdc) {
            uint256 bonusBps = (actualUsdc - expectedUsdc) * 10_000 / expectedUsdc;
            console.log("Positive slippage (bps):", bonusBps);
        } else {
            uint256 slippageBps = (expectedUsdc - actualUsdc) * 10_000 / expectedUsdc;
            console.log("Negative slippage (bps):", slippageBps);
        }
    }

    function testUniV3Swap_FeeDeducted() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        // Set up fee registry: WETH (group 2) → USDC (group 1) = 30 bps
        address feeRecipient = address(0xFEE);
        FeeRegistry feeReg = new FeeRegistry(address(this));
        feeReg.setTokenGroup(getAddress(sourceChain, "WETH"), 2);
        feeReg.setTokenGroup(getAddress(sourceChain, "USDC"), 1);
        feeReg.setGroupPairFee(1, 2, 30, feeRecipient);
        swapper.setFeeRegistry(IFeeRegistry(address(feeReg)));

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0];
        tx_.manageLeafs[1] = leafs[5];
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(swapper);
        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", address(swapper), type(uint256).max);

        bytes memory uniswapSwapData = abi.encodeWithSignature(
            "exactInput((bytes,address,uint256,uint256,uint256))",
            DecoderCustomTypes.ExactInputParams({
                path: abi.encodePacked(getAddress(sourceChain, "WETH"), uint24(500), getAddress(sourceChain, "USDC")),
                recipient: address(swapper),
                deadline: block.timestamp,
                amountIn: 1e18,
                amountOutMinimum: 0
            })
        );

        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            BoringSwapper.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: uniswapV3Adapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: uniswapSwapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        address vault = getAddress(sourceChain, "boringVault");
        uint256 vaultUsdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);
        uint256 feeRecipientUsdcBefore = getERC20(sourceChain, "USDC").balanceOf(feeRecipient);

        _submitManagerCall(manageProofs, tx_);

        uint256 vaultUsdcAfter = getERC20(sourceChain, "USDC").balanceOf(vault);
        uint256 feeRecipientUsdcAfter = getERC20(sourceChain, "USDC").balanceOf(feeRecipient);

        uint256 vaultReceived = vaultUsdcAfter - vaultUsdcBefore;
        uint256 feeReceived = feeRecipientUsdcAfter - feeRecipientUsdcBefore;
        uint256 totalOutput = vaultReceived + feeReceived;

        // fee should be ~30 bps of total output
        uint256 expectedFee = totalOutput * 30 / 10_000;
        assertApproxEqAbs(feeReceived, expectedFee, 1); // allow 1 wei rounding
        assertTrue(vaultReceived > 0);
        assertTrue(feeReceived > 0);
    }

    function testUniV3Swap__Reverts() external {
        //create tokens array
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

        //swapData is malformed on purpose (USDT instead of USDC) -> attempt to bypass the swapper whitelisting
        bytes memory uniswapSwapData = abi.encodeWithSignature(
            "exactInput((bytes,address,uint256,uint256,uint256))",
            DecoderCustomTypes.ExactInputParams({
                path: abi.encodePacked(getAddress(sourceChain, "WETH"), uint24(500), getAddress(sourceChain, "USDT")),
                recipient: address(swapper),
                deadline: block.timestamp,
                amountIn: 1e18,
                amountOutMinimum: 0
            })
        );
        
        //swap config path is correct here! 
        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            BoringSwapper.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: uniswapV3Adapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: uniswapSwapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        vm.expectRevert("path tokenOut mismatch");
        _submitManagerCall(manageProofs, tx_);
    }


    function _cowDomainSeparator() internal view returns (bytes32) {
        return IDomainSeparator(COW_SETTLEMENT).domainSeparator();
    }

    function _buildCowOrderDigest(
        address sellToken,
        address buyToken,
        address receiver,
        uint256 sellAmount,
        uint256 buyAmount,
        uint32 validTo
    ) internal view returns (bytes32 orderDigest, bytes memory encodedOrder) {
        bytes32 structHash = keccak256(abi.encode(
            GPV2_ORDER_TYPE_HASH,
            sellToken,
            buyToken,
            receiver,
            sellAmount,
            buyAmount,
            validTo,
            bytes32(0),        // appData
            uint256(0),        // feeAmount
            KIND_SELL,
            false,             // partiallyFillable
            BALANCE_ERC20,     // sellTokenBalance
            BALANCE_ERC20      // buyTokenBalance
        ));

        orderDigest = keccak256(abi.encodePacked("\x19\x01", _cowDomainSeparator(), structHash));

        encodedOrder = abi.encode(
            sellToken,
            buyToken,
            receiver,
            sellAmount,
            buyAmount,
            validTo,
            bytes32(0),
            uint256(0),
            KIND_SELL,
            false,
            BALANCE_ERC20,
            BALANCE_ERC20
        );
    }

    function testCowswapValidSignature() external {
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

        tx_.manageLeafs[0] = leafs[0]; //approve token (to swapper)
        tx_.manageLeafs[1] = leafs[6]; //submitOrder WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory cowswapData = abi.encode(DecoderCustomTypes.GPv2OrderData({
          sellToken: getAddress(sourceChain, "WETH"),
          buyToken: getAddress(sourceChain, "USDC"),
          receiver: getAddress(sourceChain, "boringVault"),  // vault receives buyToken                                            
          sellAmount: 1e18,
          buyAmount: 2000e6,
          validTo: uint32(block.timestamp + 3600),
          appData: bytes32(0),
          feeAmount: 0,
          kind: keccak256("sell"),
          partiallyFillable: false,
          sellTokenBalance: keccak256("erc20"),
          buyTokenBalance: keccak256("erc20")
      })); 
            
        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        BoringSwapper.SwapConfig memory cowSwapConfig = BoringSwapper.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: cowswapAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: cowswapData,
            slippageBps: 10,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.submitOrder.selector,
            cowSwapConfig
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        address vault = getAddress(sourceChain, "boringVault");
        uint256 wethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        _submitManagerCall(manageProofs, tx_);

        // Build the same EIP-712 digest the adapter would compute
        (bytes32 orderDigest, ) = _buildCowOrderDigest(
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "boringVault"),  // receiver matches order
            1e18,
            2000e6,
            uint32(block.timestamp + 3600)
        );

       // Simulate CoW settlement contract calling isValidSignature
       // _signature contains the full SwapConfig for re-validation at fill time
       vm.prank(COW_SETTLEMENT);
       bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(cowSwapConfig));
       assertEq(result, bytes4(0x1626ba7e), "should return ERC-1271 magic value");
    }

    function testCowswap__RevertBadSlippage() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve token (to swapper)
        tx_.manageLeafs[1] = leafs[6]; //submitOrder WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // Fat finger: selling 1 WETH for only 1000 USDC (50% below oracle price of 2000)
        bytes memory cowswapData = abi.encode(DecoderCustomTypes.GPv2OrderData({
          sellToken: getAddress(sourceChain, "WETH"),
          buyToken: getAddress(sourceChain, "USDC"),
          receiver: getAddress(sourceChain, "boringVault"),
          sellAmount: 1e18,
          buyAmount: 1000e6,  // way below market
          validTo: uint32(block.timestamp + 3600),
          appData: bytes32(0),
          feeAmount: 0,
          kind: keccak256("sell"),
          partiallyFillable: false,
          sellTokenBalance: keccak256("erc20"),
          buyTokenBalance: keccak256("erc20")
      }));

        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.submitOrder.selector,
            BoringSwapper.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: cowswapAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: cowswapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector));
        _submitManagerCall(manageProofs, tx_);
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
    ) internal view returns (BoringSwapper.SwapConfig memory, bytes32 orderDigest) {
        DecoderCustomTypes.OneInchLimitOrder memory order = DecoderCustomTypes.OneInchLimitOrder({
            salt: 1,
            maker: address(swapper),
            receiver: getAddress(sourceChain, "boringVault"),
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: 0
        });

        bytes memory orderData = abi.encode(order);
        bytes memory swapData = abi.encode(order, bytes(""));

        BoringSwapper.SwapConfig memory config = BoringSwapper.SwapConfig({
            tokenRoute: BoringSwapper.TokenRoute(
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
        returns (BoringSwapper.SwapConfig memory config, bytes32 orderDigest, uint256 orderId)
    {
        (config, orderDigest) = _buildOneInchSwapConfig(makingAmount, takingAmount);
        orderId = swapper.orders();
        swapper.submitOrder(config);
    }

    function _simulateOneInchFill(
        uint256 amountIn,
        uint256 amountOut,
        BoringSwapper.SwapConfig memory config,
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
    }

    //==================== 1inch Limit Order Tests ====================

    function testOneInchSubmitOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        //approve swapper to pull WETH from vault
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (BoringSwapper.SwapConfig memory config,, uint256 orderId) =
            _submitOneInchOrder(1e18, 2000e6);

        (ERC20 tokenIn, address approvalTarget, address cancelTarget, uint256 inputAmount, BoringVault receiver) =
            swapper.orderRecords(orderId);
        assertEq(address(tokenIn), getAddress(sourceChain, "WETH"));
        assertEq(inputAmount, 1e18);
        assertEq(address(receiver), getAddress(sourceChain, "boringVault"));

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 1e18);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 99e18);
        assertEq(swapper.orders(), orderId + 1);
    }

    function testOneInchSubmitOrder_RevertBadSlippage() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        //fat finger: 1 WETH for 1000 USDC (50% below oracle)
        (BoringSwapper.SwapConfig memory config,) = _buildOneInchSwapConfig(1e18, 1000e6);
        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector));
        swapper.submitOrder(config);
    }

    function testOneInchIsValidSignature() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest,) =
            _submitOneInchOrder(1e18, 2000e6);

        vm.prank(ONEINCH_ROUTER);
        bytes4 result = swapper.isValidSignature(orderDigest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e));
    }

    function testOneInchIsValidSignature_RevertHashMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (BoringSwapper.SwapConfig memory config,,) =
            _submitOneInchOrder(1e18, 2000e6);

        vm.prank(ONEINCH_ROUTER);
        vm.expectRevert();
        swapper.isValidSignature(bytes32(uint256(0x69420)), abi.encode(config));
    }

    function testOneInchCancelOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (BoringSwapper.SwapConfig memory config, , uint256 orderId) = _submitOneInchOrder(1e18, 2000e6);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 1e18);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 99e18);

        swapper.cancelOrder(orderId, config);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 0);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 100e18);

        (ERC20 tokenIn,,,,) = swapper.orderRecords(orderId);
        assertEq(address(tokenIn), address(0));
    }

    function testOneInchFullFillFlow() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOneInchOrder(1e18, 2000e6);

        address vault = getAddress(sourceChain, "boringVault");
        uint256 vaultWethBefore = getERC20(sourceChain, "WETH").balanceOf(vault);
        uint256 vaultUsdcBefore = getERC20(sourceChain, "USDC").balanceOf(vault);

        _simulateOneInchFill(1e18, 2000e6, config, orderDigest);

        assertEq(getERC20(sourceChain, "USDC").balanceOf(vault), vaultUsdcBefore + 2000e6);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 0);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(vault), vaultWethBefore);
    }

    function testOneInchPartialFillThenCancel() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest, uint256 orderId) =
            _submitOneInchOrder(10e18, 20000e6);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 10e18);

        _simulateOneInchFill(5e18, 10000e6, config, orderDigest);

        address vault = getAddress(sourceChain, "boringVault");
        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 5e18);
        assertEq(getERC20(sourceChain, "USDC").balanceOf(vault), 10000e6);

        swapper.cancelOrder(orderId, config);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 0);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(vault), 95e18);
    }

    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }
}

//TODO
contract MockRateProvider is IRateProvider {
  
    uint256 internal rate;

    constructor(uint256 _rate) {
        rate = _rate; 
    }

    function getRate() public view override returns (uint256) {
        return rate; 
    }
}

