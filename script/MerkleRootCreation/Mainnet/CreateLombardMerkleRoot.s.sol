// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLombardMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateLombardMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address public rawDataDecoderAndSanitizer = 0x89236361206c830Db63752DE04Df5e98a5FeceFA;
    address public managerAddress = 0xcf38e37872748E3b66741A42560672A6cef75e9B;
    address public accountantAddress = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE;

    //one offs
    address public pancakeSwapDataDecoderAndSanitizer = 0xac226f3e2677d79c0688A9f6f05B9B4eBBeDdebD;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLombardStrategistMerkleRoot();
    }

    function generateLombardStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        leafIndex = type(uint256).max;

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "WBTC");
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WBTC");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SparkLend ==========================
        /**
         * lend USDC, USDT, DAI, sDAI
         * borrow wETH, wstETH
         */
        borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WBTC");
        _addSparkLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWBTCV3")), getAddress(sourceChain, "sdWBTCV3"));

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](6);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "WBTC");
        token0[3] = getAddress(sourceChain, "WBTC");
        token0[4] = getAddress(sourceChain, "eBTC");
        token0[5] = getAddress(sourceChain, "cbBTC");

        address[] memory token1 = new address[](6);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "cbBTC");
        token1[2] = getAddress(sourceChain, "eBTC");
        token1[3] = getAddress(sourceChain, "LBTC");
        token1[4] = getAddress(sourceChain, "LBTC");
        token1[5] = getAddress(sourceChain, "LBTC");

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "WBTC");
        feeAssets[1] = getERC20(sourceChain, "LBTC");
        feeAssets[2] = getERC20(sourceChain, "cbBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](14);
        SwapKind[] memory kind = new SwapKind[](14);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "GEAR");
        kind[2] = SwapKind.Sell;
        assets[3] = getAddress(sourceChain, "CRV");
        kind[3] = SwapKind.Sell;
        assets[4] = getAddress(sourceChain, "CVX");
        kind[4] = SwapKind.Sell;
        assets[5] = getAddress(sourceChain, "AURA");
        kind[5] = SwapKind.Sell;
        assets[6] = getAddress(sourceChain, "BAL");
        kind[6] = SwapKind.Sell;
        assets[7] = getAddress(sourceChain, "PENDLE");
        kind[7] = SwapKind.Sell;
        assets[8] = getAddress(sourceChain, "INST");
        kind[8] = SwapKind.Sell;
        assets[9] = getAddress(sourceChain, "RSR");
        kind[9] = SwapKind.Sell;
        assets[10] = getAddress(sourceChain, "cbBTC");
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = getAddress(sourceChain, "eBTC");
        kind[11] = SwapKind.BuyAndSell;
        assets[12] = getAddress(sourceChain, "MORPHO");
        kind[12] = SwapKind.Sell;
        assets[13] = getAddress(sourceChain, "WETH");
        kind[13] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind);  

        // ========================== Native ==========================
        _addNativeLeafs(leafs); 

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WBTC"));

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, getAddress(sourceChain, "lBTC_wBTC_Curve_Pool"), 2, address(0));
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "eBTC_LBTC_WBTC_Curve_Pool"),
            3,
            getAddress(sourceChain, "eBTC_LBTC_WBTC_Curve_Gauge")
        );
        _addLeafsForCurveSwapping3Pool(leafs, getAddress(sourceChain, "eBTC_LBTC_WBTC_Curve_Pool"));

        // ========================== Convex ==========================
        // _addConvexLeafs(leafs, getERC20(sourceChain, "lBTC_wBTC_Curve_Pool"), CONVEX_REWARDS_CONTRACT);

        // ========================== BoringVaults ==========================
        {
            ERC20[] memory tellerAssets = new ERC20[](3);
            tellerAssets[0] = getERC20(sourceChain, "WBTC");
            tellerAssets[1] = getERC20(sourceChain, "LBTC");
            tellerAssets[2] = getERC20(sourceChain, "cbBTC");
             address eBTCTeller = 0x458797A320e6313c980C2bC7D270466A6288A8bB;
            _addTellerLeafs(leafs, eBTCTeller, tellerAssets, false, true);

            address newEBTCTeller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;
            _addTellerLeafs(leafs, newEBTCTeller, tellerAssets, false, true);
            _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "eBTCOnChainQueueFast"), getAddress(sourceChain, "EBTC"), tellerAssets);  
        }

        {
            ERC20[] memory tellerAssets = new ERC20[](5);
            tellerAssets[0] = getERC20(sourceChain, "WBTC");
            tellerAssets[1] = getERC20(sourceChain, "LBTC");
            tellerAssets[2] = getERC20(sourceChain, "cbBTC");
            tellerAssets[3] = getERC20(sourceChain, "EBTC");
            tellerAssets[4] = getERC20(sourceChain, "BTCN");
            
            _addTellerLeafs(leafs, getAddress(sourceChain, "sBTCNTeller"), tellerAssets, false, true);
            _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "sBTCNWithdrawQueue"), getAddress(sourceChain, "sBTCN"), tellerAssets); 
        }

        {
            ERC20[] memory sonicBTCTellerAssets = new ERC20[](2);
            sonicBTCTellerAssets[0] = getERC20(sourceChain, "LBTC");
            sonicBTCTellerAssets[1] = getERC20(sourceChain, "EBTC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "sonicLBTCTeller"), sonicBTCTellerAssets, false, true);
            _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "sonicLBTCWithdrawQueue"), getAddress(sourceChain, "sonicLBTC"), sonicBTCTellerAssets); 
        }

        {
            ERC20[] memory tacLBTCvTellerAssets = new ERC20[](2);
            tacLBTCvTellerAssets[0] = getERC20(sourceChain, "LBTC");
            tacLBTCvTellerAssets[1] = getERC20(sourceChain, "cbBTC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "tacLBTCvTeller"), tacLBTCvTellerAssets, false, true); //no native leaves, yes bulk actions
            _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "tacLBTCvWithdrawQueue"), getAddress(sourceChain, "tacLBTCv"), tacLBTCvTellerAssets);  
        }

        {
            ERC20[] memory katanaLBTCvTellerAssets = new ERC20[](2);
            katanaLBTCvTellerAssets[0] = getERC20(sourceChain, "LBTC");
            katanaLBTCvTellerAssets[1] = getERC20(sourceChain, "EBTC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "katanaLBTCTeller"), katanaLBTCvTellerAssets, false, true); //no native leaves, yes bulk actions
            _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "katanaLBTCWithdrawQueue"), getAddress(sourceChain, "katanaLBTC"), katanaLBTCvTellerAssets);  
        }

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_market_12_26_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_corn_market_12_26_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_corn_market_3_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_corn_market_02_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_concrete_market_04_09_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_WBTC_concrete_market_04_09_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_liquidBeraBTC_04_09_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_06_25_25"), true); 
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_06_25_25"), true); 
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_market_06_25_25"), true); 
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_12_17_25"), true); 

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "LBTC_WBTC_945"));

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "Re7WBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWBTCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "MCwBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "Re7cbBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletCbBTCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "MCcbBTC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletLBTCcore")));

        // ========================== Morpho Rewards ==========================
        _addMorphoRewardWrapperLeafs(leafs);
        _addMorphoRewardMerkleClaimerLeafs(leafs, 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWBTCV3")), getAddress(sourceChain, "sdWBTCV3"));

        // ========================== LBTC CCIP Wrapper ==========================
        // To BnB
        _addLBTCBridgeLeafs(leafs, 0x0000000000000000000000000000000000000000000000000000000000000038); 
        // To Base
        _addLBTCBridgeLeafs(leafs, 0x0000000000000000000000000000000000000000000000000000000000002105); 

        // ========================== Fluid Dex ==========================
        { 

        ERC20[] memory supplyTokens = new ERC20[](2); 
        supplyTokens[0] = getERC20(sourceChain, "LBTC"); 
        supplyTokens[1] = getERC20(sourceChain, "cbBTC"); 
        ERC20[] memory borrowTokens = new ERC20[](1); 
        borrowTokens[0] = getERC20(sourceChain, "WBTC"); 
        
        _addFluidDexLeafs(
            leafs,  
            getAddress(sourceChain, "LBTC_cbBTCDex_WBTC"),
            2000, 
            supplyTokens,
            borrowTokens,
            false //no native leaves
        ); 

        }

        // ========================== Derive ==========================
        // LBTC basis vault 
        _addDeriveVaultLeafs(
            leafs, 
            getAddress(sourceChain, "derive_LBTC_basis_deposit"), //depositVault
            getAddress(sourceChain, "derive_LBTC_basis_deposit_connector"), //depositConnector
            getAddress(sourceChain, "derive_LBTC_basis_withdraw"), //withdrawVault
            getAddress(sourceChain, "derive_LBTC_basis_withdraw_connector"), //withdrawConnector
            getAddress(sourceChain, "derive_LBTC_connectorPlugOnDeriveChain"), //connectorPlugOnDeriveChain  //NOTE: this is stored in mainnet values to reduce errors
            getAddress(sourceChain, "derive_controller"), //controller on ETH mainnet 
            getAddress(sourceChain, "boringVault") //bv address on derive
        ); 

        // ========================== PancakeSwapV3 ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", pancakeSwapDataDecoderAndSanitizer);

        token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WBTC");

        token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "LBTC");

        _addPancakeSwapV3Leafs(leafs, token0, token1);

        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        // ========================== Corn BTCN ==========================
        _addBTCNLeafs(
            leafs,
            getERC20(sourceChain, "WBTC"),
            getERC20(sourceChain, "BTCN"),
            getAddress(sourceChain, "cornSwapFacilityWBTC")
        );
        _addBTCNLeafs(
            leafs,
            getERC20(sourceChain, "cbBTC"),
            getERC20(sourceChain, "BTCN"),
            getAddress(sourceChain, "cornSwapFacilitycbBTC")
        );

        // ========================== LayerZero ==========================
        _addLayerZeroLeafsOldDecoder(
            leafs, getERC20(sourceChain, "BTCN"), getAddress(sourceChain, "BTCN"), layerZeroCornEndpointId
        );
        _addLayerZeroLeafsOldDecoder(
            leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTCOFTAdapter"), layerZeroCornEndpointId
        );

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/LombardStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
