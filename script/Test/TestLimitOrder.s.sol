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
import {CowswapAdapter} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {OneInchAdapter} from "src/base/Periphery/adapters/OneInchAdapter.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {Test, console} from "@forge-std/Test.sol";


import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/Test/TestLimitOrder.s.sol:TestLimitOrderScript --broadcast 
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract TestLimitOrderScript is Script, MerkleTreeHelper, BaseTestIntegration {
    uint256 public privateKey;

    uint8 UNISWAP_V3 = 1;
    uint8 COWSWAP = 3;
    uint8 ONEINCH = 4;

    //VAULT ECOSYSTEM CONSTANTS
    address _boringVault = 0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA;
    address _manager = 0x1AE3346BC6d3267b860De524D5E38E19679A1DB0;
    address _accountant = 0xD1135B891143d3c5DfE158C6b4961937a27b8AE4;
    address swapper = 0x93645b8FeDC5A03b9D8FD8Ee98c387EEDD10c25b;
    address _decoder = 0xBA7f9851a507A463d9D95dD5d119b03a81671efb;

    function setUp() public override {
        privateKey = vm.envUint("BORING_DEVELOPER");
        setSourceChainName("mainnet");
        vm.createSelectFork("mainnet"); 

        _overrideBoringVault(_boringVault);
        _overrideManager(_manager);
        _overrideDecoder(_decoder);
        setAddress(false, sourceChain, "managerAddress", _manager);
        setAddress(false, sourceChain, "accountantAddress", _accountant);
    }


    function run() external {
        vm.startBroadcast(privateKey);
        
        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(vm.addr(privateKey), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve token (to swapper)
        tx_.manageLeafs[1] = leafs[5]; //submitOrder WETH -> USDC
        
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
          sellAmount: 1e15,
          buyAmount: 2205e3,
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
            protocolId: COWSWAP,
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

        console.log("block timestamp + 3600", block.timestamp + 3600);

        _submitManagerCall(manageProofs, tx_);


    }
}
