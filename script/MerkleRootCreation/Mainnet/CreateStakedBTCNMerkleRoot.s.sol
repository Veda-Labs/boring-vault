// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateStakedBTCNMerkleRoot.s.sol:CreateStakedBTCNMerkleRoot --rpc-url $MAINNET_RPC_URL 
*/
contract CreateStakedBTCNMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address boringVault = 0x5E272ca4bD94e57Ec5C51D26703621Ccac1A7089;
    address managerAddress = 0x5239158272D1f626aF9ef3353489D3Cb68439D66;
    address accountantAddress = 0x9A22F5dC4Ec86184D4771E620eb75D52E7b9E043; 
    address rawDataDecoderAndSanitizer = 0x1f81B7DdFBcefFA558A1d8287E94520AF7C3f584; 


    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "cbBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "cbBTC");
        token1[1] = getAddress(sourceChain, "LBTC");
        token1[2] = getAddress(sourceChain, "LBTC");

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "cbBTC");
        kind[2] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind); 

        // ========================== Corn BTCN ==========================
        _addBTCNLeafs(leafs, getERC20(sourceChain, "WBTC"), getERC20(sourceChain, "BTCN"), getAddress(sourceChain, "cornSwapFacilityWBTC")); 
        _addBTCNLeafs(leafs, getERC20(sourceChain, "cbBTC"), getERC20(sourceChain, "BTCN"), getAddress(sourceChain, "cornSwapFacilitycbBTC")); 

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "BTCN"), getAddress(sourceChain, "BTCN"), layerZeroCornEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTCOFTAdapter"), layerZeroCornEndpointId
        ); 

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_corn_concrete_market_05_21_25"), true); 

        // ========================== Tellers ==========================
        
        ERC20[] memory vaultAssets = new ERC20[](3);  
        vaultAssets[0] = getERC20(sourceChain, "WBTC"); 
        vaultAssets[1] = getERC20(sourceChain, "cbBTC"); 
        vaultAssets[2] = getERC20(sourceChain, "LBTC"); 
        address eBTCTeller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268; 
        _addTellerLeafs(leafs, eBTCTeller, vaultAssets, false, false);  
        
        // ========================== Withdraw Queues ==========================
         
        _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "eBTCOnChainQueueFast"), getAddress(sourceChain, "EBTC"), vaultAssets); 

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/sBTCNStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
             
    }

}
