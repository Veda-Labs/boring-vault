// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {OneInchAdapter} from "src/base/Periphery/adapters/OneInchAdapter.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";

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

    bytes32 constant ONEINCH_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"
    );

    uint8 constant ONEINCH = 4;

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    MockRateProvider usdRate;
    MockRateProvider ethRate;

    function setUp() public override {
        super.setUp();
        _setupChain("mainnet", 24592183);

        registry = new AdapterRegistry();

        swapper = new BoringSwapper(address(this), registry);

        address oneInchAdapterVersion0_1 = address(new OneInchAdapter(ONEINCH_ROUTER, ONEINCH_FEE_TAKER));

        swapper.setApprovedRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), true, 50, 0, 0);
        swapper.setApprovedProtocol(ONEINCH, true);
        swapper.addApprovedVersion(ONEINCH, 1);

        registry.put(ONEINCH, oneInchAdapterVersion0_1, "ONEINCH");

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

    //==================== 1inch Swap Tests ====================
    function testUnoswap() external {
        //set up manager swap
        //do the swap
        //swap happens 
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[4]; //swap WETH -> USDC
        
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); //approve 
        tx_.targets[1] = address(swapper);  

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory unoswapData = abi.encodeWithSignature(
        );
            
        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        uint8 UNISWAP_V3 = 0; 
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            BoringSwapper.SwapConfig({
                tokenRoute: tokenRoute,
                protocolId: UNISWAP_V3,
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




    }

    //==================== 1inch Limit Order Tests ====================

    function testOneInchSubmitOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);

        (BoringSwapper.SwapConfig memory config,, uint256 orderId) =
            _submitOneInchOrder(1e18, 2000e6);

        (ERC20 tokenIn,, , uint256 inputAmount, BoringVault receiver) =
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

        (BoringSwapper.SwapConfig memory config,, uint256 orderId) = _submitOneInchOrder(1e18, 2000e6);

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

        (BoringSwapper.SwapConfig memory config, bytes32 orderDigest,) =
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
            protocolId: ONEINCH,
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

    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }
}
