// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";
/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateHybridBtcMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateHybridBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x9998e05030Aee3Af9AD3df35A34F5C51e1628779; 
    address public managerAddress = 0x2A1512a030D6eb71A5864968d795e1b6D382735D;
    address public accountantAddress = 0x22b025037ff1F6206F41b7b28968726bDBB5E7D5;
    address public rawDataDecoderAndSanitizer = 0x7E200C8DE24b439Fab2B5ae295bF7eB86078c66b;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistLeafs();
    }

    function generateStrategistLeafs() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== UniswapV3 ==========================
        // WBTC, LBTC, EBTC, solvBTC (no solvbtc.bbn pairs) 
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "WBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "EBTC");
        token1[2] = getAddress(sourceChain, "solvBTC");

        _addUniswapV3Leafs(leafs, token0, token1, true);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](6);
        SwapKind[] memory kind = new SwapKind[](6);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "EBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "solvBTC");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "solvBTC.BBN");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "cbBTC");
        kind[5] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Standard Bridge ==========================
        
        ERC20[] memory localTokens = new ERC20[](2);  
        localTokens[0] = getERC20(sourceChain, "WBTC"); 
        localTokens[1] = getERC20(sourceChain, "LBTC"); 

        ERC20[] memory remoteTokens = new ERC20[](2);  
        remoteTokens[0] = getERC20(bob, "WBTC"); 
        remoteTokens[1] = getERC20(bob, "LBTC"); 

        _addStandardBridgeLeafs(
            leafs,
            bob,
            getAddress(bob, "crossDomainMessenger"),   
            getAddress(sourceChain, "bobResolvedDelegate"),
            getAddress(sourceChain, "bobStandardBridge"),
            getAddress(sourceChain, "bobPortal"),
            localTokens,
            remoteTokens 
        );  //?

        // ========================== CCIP ==========================
        // bridge xsolvBTC and solvBTC to BOB
        ERC20[] memory ccipBridgeAssets = new ERC20[](2);
        ccipBridgeAssets[0] = getERC20(sourceChain, "xsolvBTC");
        ccipBridgeAssets[1] = getERC20(sourceChain, "solvBTC");
        ERC20[] memory ccipBridgeFeeAssets = new ERC20[](2);
        ccipBridgeFeeAssets[0] = getERC20(sourceChain, "WETH");
        ccipBridgeFeeAssets[1] = getERC20(sourceChain, "LINK");
        _addCcipBridgeLeafs(leafs, ccipBobChainSelector, ccipBridgeAssets, ccipBridgeFeeAssets);

        // ========================== Pendle ==========================
        // ebtc
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_corn_market_3_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_zeBTC_market_03_26_25"), true); //zerolend ebtc
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_market_06_25_25"), true); 

        //lbtc
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_03_26_25"), true); 
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_06_25_25"), true); 

        // ========================== Verify & Generate ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/HybridBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
