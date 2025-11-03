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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidBtcMerkleRoot.s.sol:CreateLiquidBtcMerkleRoot --rpc-url $MAINNET_RPC_URL --gas-limit 100000000000000000
 */
contract CreateLiquidBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726;
    address public managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address public accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address public rawDataDecoderAndSanitizer = 0x74522D571f80FF8024b176d710cD963002aC4278;
    address public scrollBridgeDecoderAndSanitizer = 0xA66a6B289FB5559b7e4ebf598B8e0A97C776c200;
    address public itbPositionManager = 0x7AAf9539B7359470Def1920ca41b5AAA05C13726;
    address public itbPositionManager2 = 0x11Fd9E49c41738b7500748f7B94B4DBb0E8c13d2; // Spark LBTC (PYUSD) + Aave Core Euler PYUSD Supervised Loan
    address public itbDecoderAndSanitizer = 0xb75bfC8B0Cc8588C510DcAE75c67A9DC9cF508d5; 

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
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

        ManageLeaf[] memory leafs = new ManageLeaf[](4096);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "WBTC");
        feeAssets[1] = getERC20(sourceChain, "LBTC");
        feeAssets[2] = getERC20(sourceChain, "cbBTC");
        _addLeafsForFeeClaiming(
            leafs,
            getAddress(sourceChain, "accountantAddress"),
            feeAssets,
            false
        );

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](22);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "LBTC");

        token0[3] = getAddress(sourceChain, "USDC");
        token0[4] = getAddress(sourceChain, "USDT");

        token0[5] = getAddress(sourceChain, "WBTC");
        token0[6] = getAddress(sourceChain, "cbBTC");
        token0[7] = getAddress(sourceChain, "LBTC");

        token0[8] = getAddress(sourceChain, "WBTC");
        token0[9] = getAddress(sourceChain, "cbBTC");
        token0[10] = getAddress(sourceChain, "LBTC");

        token0[11] = getAddress(sourceChain, "USD0");
        token0[12] = getAddress(sourceChain, "SUSDE");
        token0[13] = getAddress(sourceChain, "USDE");

        token0[14] = getAddress(sourceChain, "WBTC");

        token0[15] = getAddress(sourceChain, "WETH");

        token0[16] = getAddress(sourceChain, "USDC");
        token0[17] = getAddress(sourceChain, "USDC");

        token0[18] = getAddress(sourceChain, "EBTC");
        token0[19] = getAddress(sourceChain, "EBTC");
        token0[20] = getAddress(sourceChain, "EBTC");
        token0[21] = getAddress(sourceChain, "EBTC");

        address[] memory token1 = new address[](22);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "cbBTC");
        token1[2] = getAddress(sourceChain, "cbBTC");

        token1[3] = getAddress(sourceChain, "USDT");
        token1[4] = getAddress(sourceChain, "USD0_plus");

        token1[5] = getAddress(sourceChain, "USDC");
        token1[6] = getAddress(sourceChain, "USDC");
        token1[7] = getAddress(sourceChain, "USDC");

        token1[8] = getAddress(sourceChain, "USDT");
        token1[9] = getAddress(sourceChain, "USDT");
        token1[10] = getAddress(sourceChain, "USDT");

        token1[11] = getAddress(sourceChain, "USDT");
        token1[12] = getAddress(sourceChain, "USDT");
        token1[13] = getAddress(sourceChain, "USDT");

        token1[14] = getAddress(sourceChain, "eBTC");

        token1[15] = getAddress(sourceChain, "beraSTONE");

        token1[16] = getAddress(sourceChain, "USR");
        token1[17] = getAddress(sourceChain, "rUSD");

        token1[18] = getAddress(sourceChain, "LBTC");
        token1[19] = getAddress(sourceChain, "WBTC");
        token1[20] = getAddress(sourceChain, "cbBTC");
        token1[21] = getAddress(sourceChain, "LBTC");
        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](36);
        SwapKind[] memory kind = new SwapKind[](36);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "cbBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "USDC");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "USDT");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "USD0");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "USD0_plus");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "SUSDE");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "USDE");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "eBTC");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "PENDLE");
        kind[10] = SwapKind.Sell;
        assets[11] = getAddress(sourceChain, "USUAL");
        kind[11] = SwapKind.Sell;
        assets[12] = getAddress(sourceChain, "MORPHO");
        kind[12] = SwapKind.Sell;
        assets[13] = getAddress(sourceChain, "ETHFI");
        kind[13] = SwapKind.Sell;
        assets[14] = getAddress(sourceChain, "USR");
        kind[14] = SwapKind.BuyAndSell;
        assets[15] = getAddress(sourceChain, "beraSTONE");
        kind[15] = SwapKind.BuyAndSell;
        assets[16] = getAddress(sourceChain, "WETH");
        kind[16] = SwapKind.BuyAndSell;
        assets[17] = getAddress(sourceChain, "PXETH");
        kind[17] = SwapKind.BuyAndSell;
        assets[18] = getAddress(sourceChain, "STETH");
        kind[18] = SwapKind.BuyAndSell;
        assets[19] = getAddress(sourceChain, "FXUSD");
        kind[19] = SwapKind.BuyAndSell;
        assets[20] = getAddress(sourceChain, "FXN");
        kind[20] = SwapKind.Sell;
        assets[21] = getAddress(sourceChain, "CRV");
        kind[21] = SwapKind.Sell;
        assets[22] = getAddress(sourceChain, "WSTETH");
        kind[22] = SwapKind.Sell;
        assets[23] = getAddress(sourceChain, "CVX");
        kind[23] = SwapKind.Sell;
        assets[24] = getAddress(sourceChain, "GHO");
        kind[24] = SwapKind.BuyAndSell;
        assets[25] = getAddress(sourceChain, "TBTC");
        kind[25] = SwapKind.BuyAndSell;
        assets[26] = getAddress(sourceChain, "FRAX");
        kind[26] = SwapKind.BuyAndSell;
        assets[27] = getAddress(sourceChain, "FRXUSD");
        kind[27] = SwapKind.BuyAndSell;
        assets[28] = getAddress(sourceChain, "syrupUSDC");
        kind[28] = SwapKind.BuyAndSell;
        assets[29] = getAddress(sourceChain, "EUSDE");
        kind[29] = SwapKind.BuyAndSell;
        assets[30] = getAddress(sourceChain, "USDS");
        kind[30] = SwapKind.BuyAndSell;
        assets[31] = getAddress(sourceChain, "rUSD");
        kind[31] = SwapKind.BuyAndSell;
        assets[32] = getAddress(sourceChain, "srUSD");
        kind[32] = SwapKind.BuyAndSell;
        assets[33] = getAddress(sourceChain, "solvBTC");
        kind[33] = SwapKind.BuyAndSell;
        assets[34] = getAddress(sourceChain, "deUSD");
        kind[34] = SwapKind.BuyAndSell;
        assets[35] = getAddress(sourceChain, "sdeUSD");
        kind[35] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind);  

        // ========================== Euler ==========================
        {
        ERC4626[] memory depositVaults = new ERC4626[](1);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "eulerCBTC"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        }

         _addBTCNLeafs(leafs, getERC20(sourceChain, "cbBTC"), getERC20(sourceChain, "BTCN"), getAddress(sourceChain, "cornSwapFacilitycbBTC"));
        _addBTCNLeafs(leafs, getERC20(sourceChain, "WBTC"), getERC20(sourceChain, "BTCN"), getAddress(sourceChain, "cornSwapFacilityWBTC"));

        // ========================== Aave ==========================
        ERC20[] memory supplyAssets = new ERC20[](6);
        supplyAssets[0] = getERC20(sourceChain, "WBTC");
        supplyAssets[1] = getERC20(sourceChain, "LBTC");
        supplyAssets[2] = getERC20(sourceChain, "cbBTC");
        supplyAssets[3] = getERC20(sourceChain, "USDC");
        supplyAssets[4] = getERC20(sourceChain, "USDT");
        supplyAssets[5] = getERC20(sourceChain, "EBTC");

        ERC20[] memory borrowAssets = new ERC20[](4);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "WBTC");
        borrowAssets[3] = getERC20(sourceChain, "WETH");

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "PendleWBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "MCwBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "MCcbBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "MCUSR")));

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WBTC_USDC_86"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WBTC_USDT_86"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "Corn_eBTC_PT03_LBTC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "LBTC_PT03_LBTC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "LBTC_PT03_WBTC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "LBTC_PT03_WBTC_86"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "EBTC_USDC_86"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "EBTC_USR_86"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "Corn_eBTC_PT03_2025_WETH_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WBTC_USR_86"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "Corn_eBTC_PT03_2025_WBTC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "eUSDe_PT05_2025_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "MCUSR_USD0_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "MCUSR_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "EBTC_PT06_26_25_LBTC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sdeUSD_USDC_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WBTC_USDC_86"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WBTC_USDT_86"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "Corn_eBTC_PT03_LBTC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "LBTC_PT03_LBTC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "LBTC_PT03_WBTC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "LBTC_PT03_WBTC_86"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "EBTC_USDC_86"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "wstUSR_PT03_USR_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WBTC_USR_86"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "EBTC_USR_86"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "Corn_eBTC_PT03_2025_WETH_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WBTC_USR_86"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "Corn_eBTC_PT03_2025_WBTC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "eUSDe_PT05_2025_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "MCUSR_USD0_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "MCUSR_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "EBTC_PT06_26_25_LBTC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sdeUSD_USDC_915"));

        // ========================== MorphoRewards ==========================
        _addMorphoRewardWrapperLeafs(leafs);
        _addMorphoRewardMerkleClaimerLeafs(leafs, 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0++_market_01_29_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0++_market_06_25_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_corn_market_3_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_market_12_26_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_corn_market_02_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_liquidBeraBTC_04_09_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_market_06_25_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_wstUSR_market_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_tETH_03_28_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_beraSTONE_04_09_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_syrupUSDC_04_23_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eUSDe_05_28_2025"), true);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WETH"));

        // ========================== Teller ==========================
        {
            ERC20[] memory eBTCTellerAssets = new ERC20[](3);
            eBTCTellerAssets[0] = getERC20(sourceChain, "WBTC");
            eBTCTellerAssets[1] = getERC20(sourceChain, "LBTC");
            eBTCTellerAssets[2] = getERC20(sourceChain, "cbBTC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), eBTCTellerAssets, false, true);

            address[] memory eBTCTellerAssets2 = new address[](3);
            eBTCTellerAssets2[0] = getAddress(sourceChain, "WBTC");
            eBTCTellerAssets2[1] = getAddress(sourceChain, "LBTC");
            eBTCTellerAssets2[2] = getAddress(sourceChain, "cbBTC");
            address[] memory feeAssets1 = new address[](1);
            feeAssets1[0] = getAddress(sourceChain, "ETH"); 
            _addCrossChainTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), eBTCTellerAssets2, feeAssets1, abi.encode(layerZeroBerachainEndpointId));

        
            address newLiquidBeraBTCTeller = 0xe238e253b67f42ee3aF194BaF7Aba5E2eaddA1B8;  
            ERC20[] memory liquidBeraBTCTellerAssets = new ERC20[](4);
            liquidBeraBTCTellerAssets[0] = getERC20(sourceChain, "WBTC");
            liquidBeraBTCTellerAssets[1] = getERC20(sourceChain, "LBTC");
            liquidBeraBTCTellerAssets[2] = getERC20(sourceChain, "cbBTC");
            liquidBeraBTCTellerAssets[3] = getERC20(sourceChain, "eBTC");
            _addTellerLeafs(leafs, newLiquidBeraBTCTeller, liquidBeraBTCTellerAssets, false, true);

            ERC20[] memory tacBTCAssets = new ERC20[](1);
            tacBTCAssets[0] = getERC20(sourceChain, "cbBTC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "TurtleTACBTCTeller"), tacBTCAssets, false, false);
            _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "TurtleTACBTCQueue"), getAddress(sourceChain, "TurtleTACBTC"), tacBTCAssets);

            ERC20[] memory tacLBTCvAssets = new ERC20[](2);
            tacLBTCvAssets[0] = getERC20(sourceChain, "LBTC");
            tacLBTCvAssets[1] = getERC20(sourceChain, "cbBTC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "TACLBTCvTeller"), tacLBTCvAssets, false, false);
            _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "TACLBTCvQueue"), getAddress(sourceChain, "TACLBTCv"), tacLBTCvAssets);

        }

        // ========================== Resolv ==========================
        _addAllResolvLeafs(leafs);  

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, getAddress(sourceChain, "fxUSD_USDC_Curve_Pool"), 2, getAddress(sourceChain, "fxUSD_USDC_Curve_Gauge"));   
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "fxUSD_USDC_Curve_Pool")); 

        _addCurveLeafs(leafs, getAddress(sourceChain, "WETH_PXETH_Curve_Pool"), 2, getAddress(sourceChain, "WETH_PXETH_Curve_Gauge"));   
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "WETH_PXETH_Curve_Pool"));   

        _addCurveLeafs(leafs, getAddress(sourceChain, "STETH_PXETH_Curve_Pool"), 2, getAddress(sourceChain, "STETH_PXETH_Curve_Gauge"));   
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "STETH_PXETH_Curve_Pool"));   

        _addCurveLeafs(leafs, getAddress(sourceChain, "FXUSD_GHO_Curve_Pool"), 2, getAddress(sourceChain, "FXUSD_GHO_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "FXUSD_GHO_Curve_Pool"));   
        
        //tBTC/eBTC
        _addCurveLeafs(leafs, getAddress(sourceChain, "TBTC_EBTC_Curve_Pool"), 2, getAddress(sourceChain, "TBTC_EBTC_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "TBTC_EBTC_Curve_Pool"));   
        
        //tBTC/cbBTC
        _addCurveLeafs(leafs, getAddress(sourceChain, "TBTC_CBBTC_Curve_Pool"), 2, getAddress(sourceChain, "TBTC_CBBTC_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "TBTC_CBBTC_Curve_Pool"));   

        //frxUSD/FRAX
        _addCurveLeafs(leafs, getAddress(sourceChain, "frxUSD_FRAX_Curve_Pool"), 2, address(0)); //no gauge currently
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "frxUSD_FRAX_Curve_Pool"));   

        //frxUSD/SUSDS
        _addCurveLeafs(leafs, getAddress(sourceChain, "frxUSD_SUSDS_Curve_Pool"), 2, getAddress(sourceChain, "frxUSD_SUSDS_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "frxUSD_SUSDS_Curve_Pool"));   

        //frxUSD/USDE
        _addCurveLeafs(leafs, getAddress(sourceChain, "frxUSD_USDE_Curve_Pool"), 2, getAddress(sourceChain, "frxUSD_USDE_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "frxUSD_USDE_Curve_Pool"));   
        
        //triBTCFi
        _addCurveLeafs(leafs, getAddress(sourceChain, "triBTCFi_Curve_Pool"), 3, getAddress(sourceChain, "triBTCFi_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "triBTCFi_Curve_Pool"));   
       
        // ========================== Convex ==========================
        // F(x) booster
        //step 1)
        _addConvexFXBoosterLeafs(
            leafs, 
            getAddress(sourceChain, "convexFX_gauge_USDC_fxUSD"),
            getAddress(sourceChain, "convexFX_lp_USDC_fxUSD")
        );
        //step 2) (after vault creation)
        address expectedVaultAddress = 0x7bA41E927caed25bD8D25f5e6c82813Bb1d51310; 
        _addConvexFXVaultLeafs(leafs, expectedVaultAddress); 

        _addConvexFXBoosterLeafs(
            leafs, 
            getAddress(sourceChain, "convexFX_gauge_fxUSD_GHO"),
            getAddress(sourceChain, "convexFX_lp_fxUSD_GHO")
        ); 
        //step 2) (after vault creation)
        //address expectedVaultAddress2 = 0x123...; 
        //_addConvexFXVaultLeafs(leafs, expectedVaultAddress2); 

        
        //leafs, lpToken, rewardsContract
        _addConvexLeafs(leafs, getERC20(sourceChain, "WETH_PXETH_Curve_Pool"), getAddress(sourceChain, "WETH_PXETH_Convex_Rewards"));  
        _addConvexLeafs(leafs, getERC20(sourceChain, "STETH_PXETH_Curve_Pool"), getAddress(sourceChain, "STETH_PXETH_Convex_Rewards"));  
        _addConvexLeafs(leafs, getERC20(sourceChain, "FXUSD_GHO_Curve_Pool"), getAddress(sourceChain, "FXUSD_GHO_Convex_Rewards")); 
        _addConvexLeafs(leafs, getERC20(sourceChain, "TBTC_EBTC_Curve_Pool"), getAddress(sourceChain, "TBTC_EBTC_Convex_Rewards")); 
        _addConvexLeafs(leafs, getERC20(sourceChain, "TBTC_CBBTC_Curve_Pool"), getAddress(sourceChain, "TBTC_CBBTC_Convex_Rewards")); 
        _addConvexLeafs(leafs, getERC20(sourceChain, "frxUSD_SUSDS_Curve_Pool"), getAddress(sourceChain, "frxUSD_SUSDS_Convex_Rewards")); 
        _addConvexLeafs(leafs, getERC20(sourceChain, "frxUSD_USDE_Curve_Pool"), getAddress(sourceChain, "frxUSD_USDE_Convex_Rewards")); 


        // ========================== Fluid Dex ==========================
        {
            uint256 dexType = 4000; 
            ERC20[] memory supplyTokens = new ERC20[](2);    
            supplyTokens[0] = getERC20(sourceChain, "WBTC"); 
            supplyTokens[1] = getERC20(sourceChain, "cbBTC"); 

            ERC20[] memory borrowTokens = new ERC20[](2);    
            borrowTokens[0] = getERC20(sourceChain, "WBTC"); 
            borrowTokens[1] = getERC20(sourceChain, "cbBTC"); 
            _addFluidDexLeafs(
                leafs,
                getAddress(sourceChain, "wBTC_cbBTCDex_wBTC_cbBTC"),
                dexType,
                supplyTokens,
                borrowTokens,
                false
            ); 
        }

        // ========================== Syrup ==========================
        _addAllSyrupLeafs(leafs);   


        // ========================== Sky Money ==========================
        _addAllSkyMoneyLeafs(leafs); //for better swaps between stables (USDC/SUSDS) 


        // ========================== Spectra ==========================
        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_stkGHO_Pool_04_28_25"),
            getAddress(sourceChain, "spectra_stkGHO_PT_04_28_25"),
            getAddress(sourceChain, "spectra_stkGHO_YT_04_28_25"),
            getAddress(sourceChain, "spectra_stkGHO_IBT_04_28_25") //IBT or swToken 
        );  

        // ========================== EUSDE ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "EUSDE"))); 

        // ========================== SUSDS ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDS")));

        // ========================== LayerZero/Stargate ==========================
        // Berachain
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WBTC"), getAddress(sourceChain, "WBTCOFTAdapter"), layerZeroBerachainEndpointId, bytes32(uint256(uint160(address(boringVault)))));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "solvBTC"), getAddress(sourceChain, "stargateSolvBTC"), layerZeroBerachainEndpointId, bytes32(uint256(uint160(address(boringVault)))));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "srUSD"), getAddress(sourceChain, "stargatesrUSD"), layerZeroBerachainEndpointId, bytes32(uint256(uint160(address(boringVault)))));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "stargateUSDC"), layerZeroBerachainEndpointId, bytes32(uint256(uint160(address(boringVault)))));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTCOFTAdapter"), layerZeroCornEndpointId, bytes32(uint256(uint160(address(boringVault)))));   
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "BTCN"), getAddress(sourceChain, "BTCN"), layerZeroCornEndpointId, bytes32(uint256(uint160(address(boringVault))))); 

        //Scroll
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WBTC"), getAddress(sourceChain, "WBTCOFTAdapter"), layerZeroScrollEndpointId, bytes32(uint256(uint160(address(boringVault)))));   

        // ========================== Scroll Native Bridge==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", scrollBridgeDecoderAndSanitizer);
        ERC20[] memory tokens = new ERC20[](1); 
        tokens[0] = getERC20(sourceChain, "WBTC"); 
        address[] memory scrollGateways = new address[](1);
        scrollGateways[0] = getAddress(scroll, "scrollWBTCGateway");
        _addScrollNativeBridgeLeafs(leafs, "scroll", tokens, scrollGateways);  

        // ========================== Elixir ==========================
        /**
         * deposit, withdraw
         */
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));

        // ========================== ITB Position Manager ==========================
        {
            /**
            * acceptOwnership() of ITB position manager
            * transfer BTC tokens to ITB position manager
            * withdraw BTC tokens from ITB position manager
            * withdrawAll BTC tokens from ITB position manager
            */
            ERC20[] memory itbTokensUsed = new ERC20[](4);
            itbTokensUsed[0] = getERC20(sourceChain, "WBTC");
            itbTokensUsed[1] = getERC20(sourceChain, "LBTC");
            itbTokensUsed[2] = getERC20(sourceChain, "cbBTC");
            itbTokensUsed[3] = getERC20(sourceChain, "eBTC");
            _addLeafsForITBPositionManager(leafs, itbPositionManager, itbTokensUsed, "ITB Position Manager");

            ERC20[] memory itbTokensUsed2 = new ERC20[](1);
            itbTokensUsed2[0] = getERC20(sourceChain, "LBTC");
            _addLeafsForITBPositionManager(leafs, itbPositionManager2, itbTokensUsed2, "ITB Position Manager 2");
        }

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManager(
        ManageLeaf[] memory leafs,
        address positionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        // acceptOwnership
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ", itbContractName, " contract"),
            itbDecoderAndSanitizer
        );
        for (uint256 i; i < tokensUsed.length; ++i) {
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(tokensUsed[i]),
                false,
                "transfer(address,uint256)",
                new address[](1),
                string.concat("Transfer ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = positionManager;
        }
                    // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                positionManager,
                false,
                "withdraw(address,uint256)",
                new address[](0),
                string.concat("Withdraw from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                positionManager,
                false,
                "withdrawAll(address)",
                new address[](0),
                string.concat("Withdraw all from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
    }
}
