// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol"; 
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {UniswapV3Adapter} from "src/base/Periphery/adapters/UniswapV3Adapter.sol"; 
import {CowswapAdapter} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {Test, console} from "@forge-std/Test.sol";

contract SwapperDecoder is BaseDecoderAndSanitizer {

    function swap(DecoderCustomTypes.SwapConfig memory swapConfig) external pure returns (bytes memory addressesFound) {
        return abi.encodePacked(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut, address(swapConfig.receiver));
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


contract BoringSwapperIntegration is BaseTestIntegration {

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    MockRateProvider usdRate;
    MockRateProvider ethRate;

    function setUp() public override {
        super.setUp(); 
        _setupChain("mainnet", 24592183); 
            
        address swapperDecoder = address(new SwapperDecoder()); 

        _overrideDecoder(swapperDecoder); 

        registry = new AdapterRegistry(); 

        //do additional setup here
        swapper = new BoringSwapper(registry); 

        address uniswapV3AdapterVersion0_1 = address(new UniswapV3Adapter(getAddress(sourceChain, "uniV3Router"))); 
        address cowswapAdapterVersion0_1 = address(new CowswapAdapter()); 

        swapper.addApprovedRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), 50); 
        swapper.addApprovedProtocol(0); //UNI_V3
        swapper.addApprovedProtocol(3); //COWSWAP
        swapper.addApprovedVersion(0, 1); 
        swapper.addApprovedVersion(3, 1); 

        registry.put(0, uniswapV3AdapterVersion0_1);
        registry.put(3, cowswapAdapterVersion0_1);

        //oracle setup
        usdRate = new MockRateProvider(1e18);
        ethRate = new MockRateProvider(2000e18);

        address usdQuoteAsset = getAddress(sourceChain, "USDC");
        swapper.addApprovedOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, address(usdRate));
        swapper.addApprovedOracle(getERC20(sourceChain, "WETH"), usdQuoteAsset, address(ethRate));

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
    
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 

        tx_.manageLeafs[0] = leafs[0]; //approve token
        tx_.manageLeafs[1] = leafs[3]; //swap WETH -> USDC
        
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

    function testCowswap() external {
        //create tokens array
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18); 

        address[] memory tokens = new address[](2);  
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");
    
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens); 
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2); 


    }
  // CoW Protocol constants                                                                                                          
  address constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
                                                                                                                                     
  bytes32 constant GPV2_ORDER_TYPE_HASH = keccak256(
      "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,bytes32 kind,bool partiallyFillable,bytes32 sellTokenBalance,bytes32 buyTokenBalance)");

  bytes32 constant KIND_SELL = keccak256("sell");
  bytes32 constant BALANCE_ERC20 = keccak256("erc20");

  function _cowDomainSeparator() internal view returns (bytes32) {
      return keccak256(abi.encode(
          keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
          keccak256("Gnosis Protocol"),
          keccak256("v2"),
          block.chainid,
          COW_SETTLEMENT
      ));
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
        address weth = getAddress(sourceChain, "WETH");
        address usdc = getAddress(sourceChain, "USDC");

        (bytes32 orderDigest, bytes memory encodedOrder) = _buildCowOrderDigest(
            weth,                              // sellToken
            usdc,                              // buyToken
            address(swapper),                  // receiver
            1e18,                              // sellAmount (1 WETH)
            2000e6,                            // buyAmount (2000 USDC)
            uint32(block.timestamp + 3600)     // validTo
        );

        // Pack a SwapConfig into the signature bytes
        uint8 COWSWAP = 3;
        bytes memory signature = abi.encode(
            BoringSwapper.SwapConfig({
                tokenRoute: BoringSwapper.TokenRoute(
                    getERC20(sourceChain, "WETH"),
                    getERC20(sourceChain, "USDC")
                ),
                protocolId: COWSWAP,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: encodedOrder,
                slippageBps: 50,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        // Simulate CoW settlement contract calling isValidSignature
        vm.prank(COW_SETTLEMENT);
        bytes4 result = swapper.isValidSignature(orderDigest, signature);
        assertEq(result, bytes4(0x1626ba7e), "should return ERC-1271 magic value");
  }

  function testCowswapRejectsBadSlippage() external {
        address weth = getAddress(sourceChain, "WETH");
        address usdc = getAddress(sourceChain, "USDC");

        // Order selling 1 WETH for only 1000 USDC (50% below market)
        (bytes32 orderDigest, bytes memory encodedOrder) = _buildCowOrderDigest(
            weth,
            usdc,
            address(swapper),
            1e18,
            1000e6,          // way below oracle price
            uint32(block.timestamp + 3600)
        );

        bytes memory signature = abi.encode(
            BoringSwapper.SwapConfig({
                tokenRoute: BoringSwapper.TokenRoute(
                    getERC20(sourceChain, "WETH"),
                    getERC20(sourceChain, "USDC")
                ),
                protocolId: uint8(3),
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: encodedOrder,
                slippageBps: 50,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        vm.prank(COW_SETTLEMENT);
        vm.expectRevert("exceeds max slippage for route");
        swapper.isValidSignature(orderDigest, signature);
  }
}
