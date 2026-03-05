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
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {Test, console} from "@forge-std/Test.sol";

contract SwapperDecoder is BaseDecoderAndSanitizer {

    function swap(DecoderCustomTypes.SwapConfig memory swapConfig) external pure returns (bytes memory addressesFound) {
        return abi.encodePacked(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut, address(swapConfig.receiver));
    }
}


contract BoringSwapperIntegration is BaseTestIntegration {
    
    AdapterRegistry registry; 
    BoringSwapper swapper; 

    function setUp() public override {
        super.setUp(); 
        _setupChain("mainnet", 24592183); 
            
        address swapperDecoder = address(new SwapperDecoder()); 

        _overrideDecoder(swapperDecoder); 

        registry = new AdapterRegistry(); 

        //do additional setup here
        swapper = new BoringSwapper(registry); 

        address uniswapV3AdapterVersion0_1 = address(new UniswapV3Adapter(getAddress(sourceChain, "uniV3Router"))); 

        swapper.addApprovedRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), 100_000); 
        swapper.addApprovedProtocol(0); //UNI_V3
        swapper.addApprovedVersion(0, 1); 

        registry.put(0, uniswapV3AdapterVersion0_1);
        
    }

    function testUniV3Swap() external {
        console.log("Test is working"); 
        console.log("swapper", address(swapper)); 
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
                quoteAsset: BoringSwapper.QuoteAsset.USD,
                swapData: uniswapSwapData,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_); 
    }
}
