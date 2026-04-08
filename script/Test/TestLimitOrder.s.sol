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

    //VAULT ECOSYSTEM CONSTANTS
    address _boringVault = 0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA;
    address _manager = 0x1AE3346BC6d3267b860De524D5E38E19679A1DB0;
    address _accountant = 0xD1135B891143d3c5DfE158C6b4961937a27b8AE4;
    address swapper = 0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC;
    address _decoder = 0xd9Bb301D37BEB60EbeD71093Cd9c63eFd20C72f4;

    // Adapter addresses (from DeployBoringSwapper output)
    address uniswapV3Adapter = 0x0B368fc268d2BbF641b4DD29bFE01FBF19f609d1;
    address cowswapAdapter   = 0x90BA671D3062fEd8B169933Ce61AC443191196a6;
    address oneInchAdapter   = 0x48EE2f75E67dE1Cc686b02F81EB3dFe95341DFC1;

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
        _submitCowswapOrder();
        //_submitOneInchOrder();
        //_submitOneInchRegularSwap();
    }

    function _submitCowswapOrder() internal {
        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(vm.addr(privateKey), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve WETH
        tx_.manageLeafs[1] = leafs[6]; //submitOrder WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        bytes memory cowswapData = abi.encode(DecoderCustomTypes.GPv2OrderData({
          sellToken: getAddress(sourceChain, "WETH"),
          buyToken: getAddress(sourceChain, "USDC"),
          receiver: getAddress(sourceChain, "boringVault"),
          sellAmount: 1000000000000000,
          buyAmount: 2200000,
          validTo: uint32(1775677819),
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
            slippageBps: 500,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.submitOrder.selector,
            cowSwapConfig
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function _submitOneInchOrder() internal {
        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(vm.addr(privateKey), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve WETH
        tx_.manageLeafs[1] = leafs[6]; //submitOrder WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // Params from SDK generate step (includes fee extension)
        uint256 salt = 853972053136738638502496320891852715998876232850725707488828929160422407870;
        uint256 makerTraits = 33471150795161712739625987854538030748435788278679472690775088094832354131968;
        address feeTaker = 0xc0DFdB9E7a392c3dBBE7c6FBe8FBC1789C9FE05e;

        bytes memory extension = hex"00000142000000ae000000ae000000ae000000ae000000570000000000000000c0dfdb9e7a392c3dbbe7c6fbe8fbc1789c9fe05e000000012c6406b09498030ae3416b66dc74db31d09524fa87b1f76ea9a11ae13b29f5c555d18bd45f0b94f54a968fc90ed87a54c23dc480b395770895ad27ad6b0d95c0dfdb9e7a392c3dbbe7c6fbe8fbc1789c9fe05e000000012c6406b09498030ae3416b66dc74db31d09524fa87b1f76ea9a11ae13b29f5c555d18bd45f0b94f54a968fc90ed87a54c23dc480b395770895ad27ad6b0d95c0dfdb9e7a392c3dbbe7c6fbe8fbc1789c9fe05e01000000000000000000000000000000000000000090cbe4bdd538d6e9b379bff5fe72c3d67a521de50fc760eebefbf5fe3b452a9a52325c4376feadfa000000012c6406b09498030ae3416b66dc74db31d09524fa87b1f76ea9a11ae13b29f5c555d18bd45f0b94f54a968fc90ed87a54c23dc480b395770895ad27ad6b0d95";

        bytes memory oneInchData = abi.encode(DecoderCustomTypes.OneInchLimitOrder({
            salt: salt,
            maker: address(swapper),
            receiver: feeTaker,
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            makingAmount: 1e15,
            takingAmount: 2.2e6,
            makerTraits: makerTraits
        }), extension);

        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        BoringSwapper.SwapConfig memory oneInchConfig = BoringSwapper.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: oneInchAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: oneInchData,
            slippageBps: 500,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.submitOrder.selector,
            oneInchConfig
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Log order hash for comparison with JS
        bytes32 ONEINCH_ORDER_TYPE_HASH = keccak256(
            "Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"
        );
        bytes memory orderData = abi.encode(salt, address(swapper), feeTaker, getAddress(sourceChain, "WETH"), getAddress(sourceChain, "USDC"), uint256(1e15), uint256(2.2e6), makerTraits);
        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, orderData));
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("1inch Aggregation Router"),
            keccak256("6"),
            block.chainid,
            0x111111125421cA6dc452d289314280a0f8842A65
        ));
        bytes32 orderHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        console.log("Order hash (Solidity):");
        console.logBytes32(orderHash);

        _submitManagerCall(manageProofs, tx_);

    }

    function _submitOneInchRegularSwap() internal {
        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(vm.addr(privateKey), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve WETH
        tx_.manageLeafs[1] = leafs[5]; //swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // TODO: replace with fresh swap calldata from the 1inch API
        bytes memory oneInchSwapData = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000002185e308000000000000003b6d0340397ff1542f962076d0bfe58ea045ffa2d347aca0f583bc2f";

        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );

        BoringSwapper.SwapConfig memory regularSwapConfig = BoringSwapper.SwapConfig({
            tokenRoute: tokenRoute,
            adapter: oneInchAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: oneInchSwapData,
            slippageBps: 50,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });

        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            regularSwapConfig
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

}
