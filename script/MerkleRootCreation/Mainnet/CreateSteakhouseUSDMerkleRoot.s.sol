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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSteakhouseUSDMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateSteakhouseUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xd54F9ECdF8dF3035ADE1e3EbcDcEa0AB13591cCF;
    address public managerAddress = 0x4749914237b24717Bff1cBFa2Bf9d39D9BD8096b;
    address public accountantAddress = 0xF7b299aDD6A8E54b184d09A2807B4348b6be7079;
    address public rawDataDecoderAndSanitizer =  0xeFB48737A2E851F78C42901673d2614B8932670B;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateMetaVaultMainnetStrategistMerkleRoot();
    }

    function generateMetaVaultMainnetStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== 1inch ==========================
         address[] memory assets = new address[](7);
         SwapKind[] memory kind = new SwapKind[](7);
         assets[0] = getAddress(sourceChain, "USDC");
         kind[0] = SwapKind.BuyAndSell;
         assets[1] = getAddress(sourceChain, "USDT");
         kind[1] = SwapKind.BuyAndSell;
         assets[2] = getAddress(sourceChain, "USDE");
         kind[2] = SwapKind.BuyAndSell;
         assets[3] = getAddress(sourceChain, "SUSDE");
         kind[3] = SwapKind.BuyAndSell;
         assets[4] = getAddress(sourceChain, "DAI");
         kind[4] = SwapKind.BuyAndSell;
         assets[5] = getAddress(sourceChain, "USDtb");
         kind[5] = SwapKind.BuyAndSell;
         assets[6] = getAddress(sourceChain, "MF-ONE");
         kind[6] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);  
            
        // ========================== Odos ==========================
         _addOdosSwapLeafs(leafs, assets, kind);

        // ========================== Morpho Blue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDe_USDC_915")); 
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDe_USDT_915")); 
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "MF-ONE_USDC_915")); 
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USDe_PT09_25_25_USDtb_915")); 
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDe_PT09_25_25_USDtb_915")); 
    

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDe_USDC_915")); 
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDe_USDT_915")); 
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "MF-ONE_USDC_915")); 
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USDe_PT09_25_25_USDtb_915")); 
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDe_PT09_25_25_USDtb_915")); 

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "smokehouseUSDC"))); 
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "smokehouseUSDT"))); 

        // ========================== Pendle ==========================
        //USDe
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_market_07_31_25"), true); 
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_market_09_25_25"), true); 
        //sUSDe
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_market_07_31_25"), true); 
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_market_09_25_25"), true); 

        // ========================== Ethena Withdraws ==========================
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));

        // ========================== MF-One ==========================
        /**
         * depositInstant, depositRequest, redeemInstant, redeemRequest, redeemFiatRequest
         */
        _addMfOneLeafs(leafs);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/SteakhouseUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
