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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateMultiChainLiquidEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 100000000000000000
 */
contract CreateMultiChainLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x8fB043d30BAf4Eba2C8f7158aCBc07ec9A53Fe85;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public pancakeSwapDataDecoderAndSanitizer = 0xfdC73Fc6B60e4959b71969165876213918A443Cd;
    address public scrollBridgeDecoderAndSanitizer = 0xA66a6B289FB5559b7e4ebf598B8e0A97C776c200;
    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    address public itbAaveDecoderAndSanitizer = 0x7fA5dbDB1A76d2990Ea0f3c74e520E3fcE94748B;
    address public itbReserveProtocolPositionManager = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;
    address public itbAaveLidoPositionManager = 0xC4F5Ee078a1C4DA280330546C29840d45ab32753;
    address public itbAaveLidoPositionManager2 = 0x572F323Aa330B467C356c5a30Bf9A20480F4fD52;
    address public hyperlaneDecoderAndSanitizer = 0xfC823909C7D2Cb8701FE7d6EE74508C57Df1D6dE;
    address public termFinanceDecoderAndSanitizer = 0xF8e9517e7e98D7134E306aD3747A50AC8dC1dbc9;
    address public kingClaimingDecoderAndSanitizer = 0xd4067b594C6D48990BE42a559C8CfDddad4e8D6F;

    address public itbCorkDecoderAndSanitizer = 0x457Cce6Ec3fEb282952a7e50a1Bc727Ca235Eb0a;

    address public drone = 0x0a42b2F3a0D54157Dbd7CC346335A4F1909fc02c;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidEthStrategistMerkleRoot();
    }

    function generateLiquidEthStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](4096);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WEETH");
        supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory borrowAssets = new ERC20[](3);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WEETH");
        borrowAssets[2] = getERC20(sourceChain, "WSTETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SparkLend ==========================
        borrowAssets = new ERC20[](3);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WSTETH");
        borrowAssets[2] = getERC20(sourceChain, "RETH");
        _addSparkLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== Aave V3 Lido ==========================
        supplyAssets = new ERC20[](2);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WSTETH");
        borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        _addAaveV3LidoLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWETHV3")), getAddress(sourceChain, "sdWETHV3"));

        // ========================== MorphoBlue ==========================
        /**
         * weETH/wETH  86.00 LLTV market 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115
         */
        _addMorphoBlueSupplyLeafs(leafs, 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115);
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WEETH_WETH_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WEETH_WETH_915"));

        // ========================== Meta Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWETHPrime")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWETHCore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "mevCapitalwWeth")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "Re7WETH")));

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarket"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarket"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketDecember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakWeETHMarketSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarketAugust"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketJuly"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_weETHs_market_08_28_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHkSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_weETHs_market_12_25_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakWeETHMarketDecember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHkDecember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_liquid_bera_eth_04_09_25"), true);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](9);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token0[3] = getAddress(sourceChain, "WEETH");
        token0[4] = getAddress(sourceChain, "WEETH");
        token0[5] = getAddress(sourceChain, "WSTETH");
        token0[6] = getAddress(sourceChain, "WETH");
        token0[7] = getAddress(sourceChain, "WETH");
        token0[8] = getAddress(sourceChain, "WETH");

        address[] memory token1 = new address[](9);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "RETH");
        token1[3] = getAddress(sourceChain, "WSTETH");
        token1[4] = getAddress(sourceChain, "RETH");
        token1[5] = getAddress(sourceChain, "RETH");
        token1[6] = getAddress(sourceChain, "SFRXETH");
        token1[7] = getAddress(sourceChain, "CBETH");
        token1[8] = getAddress(sourceChain, "RSETH");

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        {
            ERC20[] memory feeAssets = new ERC20[](3);
            feeAssets[0] = getERC20(sourceChain, "WETH");
            feeAssets[1] = getERC20(sourceChain, "WEETH");
            feeAssets[2] = getERC20(sourceChain, "EETH");
            _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

            // ========================== 1inch ==========================
            address[] memory assets = new address[](35);
            SwapKind[] memory kind = new SwapKind[](35);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WEETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "WSTETH");
            kind[2] = SwapKind.BuyAndSell;
            assets[3] = getAddress(sourceChain, "RETH");
            kind[3] = SwapKind.BuyAndSell;
            assets[4] = getAddress(sourceChain, "GEAR");
            kind[4] = SwapKind.Sell;
            assets[5] = getAddress(sourceChain, "CRV");
            kind[5] = SwapKind.Sell;
            assets[6] = getAddress(sourceChain, "CVX");
            kind[6] = SwapKind.Sell;
            assets[7] = getAddress(sourceChain, "AURA");
            kind[7] = SwapKind.Sell;
            assets[8] = getAddress(sourceChain, "BAL");
            kind[8] = SwapKind.Sell;
            assets[9] = getAddress(sourceChain, "PENDLE");
            kind[9] = SwapKind.Sell;
            assets[10] = getAddress(sourceChain, "SFRXETH");
            kind[10] = SwapKind.BuyAndSell;
            assets[11] = getAddress(sourceChain, "INST");
            kind[11] = SwapKind.Sell;
            assets[12] = getAddress(sourceChain, "RSR");
            kind[12] = SwapKind.Sell;
            assets[13] = getAddress(sourceChain, "CBETH");
            kind[13] = SwapKind.BuyAndSell;
            assets[14] = getAddress(sourceChain, "RSETH");
            kind[14] = SwapKind.BuyAndSell;
            assets[15] = getAddress(sourceChain, "CAKE");
            kind[15] = SwapKind.Sell;
            assets[16] = getAddress(sourceChain, "ETHX");
            kind[16] = SwapKind.BuyAndSell;
            assets[17] = getAddress(sourceChain, "FRXETH");
            kind[17] = SwapKind.BuyAndSell;
            assets[18] = getAddress(sourceChain, "UNI");
            kind[18] = SwapKind.Sell;
            assets[19] = getAddress(sourceChain, "USDT");
            kind[19] = SwapKind.BuyAndSell;
            assets[20] = getAddress(sourceChain, "EIGEN");
            kind[20] = SwapKind.Sell;
            assets[21] = getAddress(sourceChain, "ETHFI");
            kind[21] = SwapKind.Sell;
            assets[22] = getAddress(sourceChain, "SWELL");
            kind[22] = SwapKind.Sell;
            assets[23] = getAddress(sourceChain, "KING");
            kind[23] = SwapKind.Sell;
            assets[24] = getAddress(sourceChain, "EETH");
            kind[24] = SwapKind.BuyAndSell;
            assets[25] = getAddress(sourceChain, "EUL");
            kind[25] = SwapKind.Sell;
            assets[26] = getAddress(sourceChain, "rEUL");
            kind[26] = SwapKind.Sell;
            assets[27] = getAddress(sourceChain, "USDC");
            kind[27] = SwapKind.BuyAndSell;
            assets[28] = getAddress(sourceChain, "USDE");
            kind[28] = SwapKind.BuyAndSell;
            assets[29] = getAddress(sourceChain, "SUSDE");
            kind[29] = SwapKind.BuyAndSell;
            assets[30] = getAddress(sourceChain, "EIGEN"); // Address in ChainValues ++ checked
            kind[30] = SwapKind.Sell;
            assets[31] = getAddress(sourceChain, "ETHFI"); // Address in ChainValues ++ checked
            kind[31] = SwapKind.Sell;
            assets[32] = getAddress(sourceChain, "SWELL"); // Address in ChainValues ++ checked
            kind[32] = SwapKind.Sell;
            assets[33] = getAddress(sourceChain, "RLUSD");
            kind[33] = SwapKind.Sell;
            assets[34] = getAddress(sourceChain, "PYUSD");
            kind[34] = SwapKind.Sell;
            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

            _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_wETH_01"));
            _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "rETH_wETH_01"));
            _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "rETH_wETH_05"));
            _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_rETH_05"));
            _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "PENDLE_wETH_30"));
            _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_05"));
            _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "GEAR_wETH_100"));

            // ========================== Odos ==========================
            _addOdosSwapLeafs(leafs, assets, kind);

            // ========================== Curve Swapping ==========================
            _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "weETH_wETH_Pool"));
            _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "weETH_wETH_NG_Pool"));
            _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "tETH_wstETH_curve_pool"));
        }
        // ========================== Swell ==========================
        {
            _addSwellSimpleStakingLeafs(
                leafs, getAddress(sourceChain, "WEETH"), getAddress(sourceChain, "swellSimpleStaking")
            );
            _addSwellSimpleStakingLeafs(
                leafs, getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "swellSimpleStaking")
            );
            _addSwellSimpleStakingLeafs(
                leafs, getAddress(sourceChain, "SFRXETH"), getAddress(sourceChain, "swellSimpleStaking")
            );
            _addSwellSimpleStakingLeafs(
                leafs, getAddress(sourceChain, "pendleEethPt"), getAddress(sourceChain, "swellSimpleStaking")
            );
            _addSwellSimpleStakingLeafs(
                leafs, getAddress(sourceChain, "pendleEethPtDecember"), getAddress(sourceChain, "swellSimpleStaking")
            );
            _addSwellSimpleStakingLeafs(
                leafs, getAddress(sourceChain, "pendleEethPtSeptember"), getAddress(sourceChain, "swellSimpleStaking")
            );
            _addSwellSimpleStakingLeafs(
                leafs, getAddress(sourceChain, "pendleZircuitEethPt"), getAddress(sourceChain, "swellSimpleStaking")
            );
        }

        // ========================== Zircuit ==========================
        {
            _addZircuitLeafs(leafs, getAddress(sourceChain, "WEETH"), getAddress(sourceChain, "zircuitSimpleStaking"));
            _addZircuitLeafs(leafs, getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "zircuitSimpleStaking"));
        }
        // ========================== Balancer ==========================
        {
            _addBalancerLeafs(
                leafs, getBytes32(sourceChain, "rETH_weETH_id"), getAddress(sourceChain, "rETH_weETH_gauge")
            );
            _addBalancerLeafs(
                leafs, getBytes32(sourceChain, "rETH_wETH_id"), getAddress(sourceChain, "rETH_wETH_gauge")
            );
            _addBalancerLeafs(
                leafs, getBytes32(sourceChain, "wstETH_wETH_Id"), getAddress(sourceChain, "wstETH_wETH_Gauge")
            );
            _addBalancerLeafs(
                leafs, getBytes32(sourceChain, "rsETH_wETH_id"), getAddress(sourceChain, "rsETH_wETH_gauge")
            );
        }
        // ========================== Aura ==========================
        {
            _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weeth"));
            _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weth"));
            _addAuraLeafs(leafs, getAddress(sourceChain, "aura_wstETH_wETH"));
            _addAuraLeafs(leafs, getAddress(sourceChain, "aura_rsETH_wETH"));
        }
        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WEETH"));

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== FrxEth ==========================
        // sfrxETH operations
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SFRXETH")));
        // frxETH operations
        _addFraxLeafs(leafs);

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs, getAddress(sourceChain, "weETH_wETH_ng"), 2, getAddress(sourceChain, "weETH_wETH_ng_gauge")
        );

        // ========================== Convex ==========================
        _addConvexLeafs(
            leafs, getERC20(sourceChain, "weETH_wETH_NG_Pool"), getAddress(sourceChain, "weETH_wETH_NG_Convex_Reward")
        );

        // ========================== BoringVaults ==========================
        {
            ERC20[] memory tellerAssets = new ERC20[](11);
            tellerAssets[0] = getERC20(sourceChain, "WETH");
            tellerAssets[1] = getERC20(sourceChain, "EETH");
            tellerAssets[2] = getERC20(sourceChain, "WEETH");
            tellerAssets[3] = getERC20(sourceChain, "WSTETH");
            tellerAssets[4] = getERC20(sourceChain, "CBETH");
            tellerAssets[5] = getERC20(sourceChain, "WBETH");
            tellerAssets[6] = getERC20(sourceChain, "RETH");
            tellerAssets[7] = getERC20(sourceChain, "METH");
            tellerAssets[8] = getERC20(sourceChain, "SWETH");
            tellerAssets[9] = getERC20(sourceChain, "SFRXETH");
            tellerAssets[10] = getERC20(sourceChain, "ETHX");
            address superSymbioticTeller = 0x99dE9e5a3eC2750a6983C8732E6e795A35e7B861;
            _addTellerLeafs(leafs, superSymbioticTeller, tellerAssets, false, true);

            tellerAssets = new ERC20[](13);
            tellerAssets[0] = getERC20(sourceChain, "WETH");
            tellerAssets[1] = getERC20(sourceChain, "EETH");
            tellerAssets[2] = getERC20(sourceChain, "WEETH");
            tellerAssets[3] = getERC20(sourceChain, "WSTETH");
            tellerAssets[4] = getERC20(sourceChain, "CBETH");
            tellerAssets[5] = getERC20(sourceChain, "WBETH");
            tellerAssets[6] = getERC20(sourceChain, "RETH");
            tellerAssets[7] = getERC20(sourceChain, "METH");
            tellerAssets[8] = getERC20(sourceChain, "SWETH");
            tellerAssets[9] = getERC20(sourceChain, "SFRXETH");
            tellerAssets[10] = getERC20(sourceChain, "ETHX");
            tellerAssets[11] = getERC20(sourceChain, "RSWETH");
            tellerAssets[12] = getERC20(sourceChain, "RSETH");
            address kingKarakTeller = 0x929B44db23740E65dF3A81eA4aAB716af1b88474;
            _addTellerLeafs(leafs, kingKarakTeller, tellerAssets, false, true);

            tellerAssets = new ERC20[](5);
            tellerAssets[0] = getERC20(sourceChain, "STETH");
            tellerAssets[1] = getERC20(sourceChain, "WSTETH");
            tellerAssets[2] = getERC20(sourceChain, "WETH");
            tellerAssets[3] = getERC20(sourceChain, "WEETH");
            tellerAssets[4] = getERC20(sourceChain, "EETH");
            address liquidKatanaETHTeller = 0x739A1efFaDDB0b07ef1284598819232df4FD8d16;
            _addTellerLeafs(leafs, liquidKatanaETHTeller, tellerAssets, true, true);

            address liquidKatanaWithdrawQueue = 0x52E523B849c584F86bF460A3cF2962b118Ce2506;
            address liquidKatana = 0x69d210d3b60E939BFA6E87cCcC4fAb7e8F44C16B;
            _addWithdrawQueueLeafs(leafs, liquidKatanaWithdrawQueue, liquidKatana, tellerAssets);
        }

        {
            ERC20[] memory tellerAssets = new ERC20[](5);
            tellerAssets[0] = getERC20(sourceChain, "WETH");
            tellerAssets[1] = getERC20(sourceChain, "EETH");
            tellerAssets[2] = getERC20(sourceChain, "WEETH");
            tellerAssets[3] = getERC20(sourceChain, "WSTETH");
            tellerAssets[4] = getERC20(sourceChain, "STETH");
            address liquidBeraETHTeller = 0xd445C65e4821dbD4ed0114eCDF6325c69faD7653;
            _addTellerLeafs(leafs, liquidBeraETHTeller, tellerAssets, true, true);
        }

        // ========================== Yearn ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "yKatanaPredepositWETH")));

        // ========================== Fluid Dex ==========================
        {
            ERC20[] memory supplyTokens = new ERC20[](2);
            supplyTokens[0] = getERC20(sourceChain, "WEETH");
            supplyTokens[1] = getERC20(sourceChain, "ETH");

            ERC20[] memory borrowTokens = new ERC20[](1);
            borrowTokens[0] = getERC20(sourceChain, "WSTETH");

            uint256 dexType = 2000;

            _addFluidDexLeafs(
                leafs, getAddress(sourceChain, "weETH_ETHDex_wstETH"), dexType, supplyTokens, borrowTokens, true
            );
        }

        // ========================== Euler ==========================
        {
            ERC4626[] memory depositVaults = new ERC4626[](1);
            depositVaults[0] = ERC4626(getAddress(sourceChain, "eulerPrimeWETH"));

            address[] memory subaccounts = new address[](1);
            subaccounts[0] = address(boringVault);

            _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        }

        // ========================== vbVault ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "vbETH")));

        // ========================== Agglayer ==========================
        _addAgglayerTokenLeafs(
            leafs, getAddress(sourceChain, "agglayerBridgeKatana"), getAddress(sourceChain, "vbETH"), 0, 20
        );
        _addAgglayerTokenLeafs(
            leafs, getAddress(sourceChain, "agglayerBridgeKatana"), getAddress(sourceChain, "WEETH"), 0, 20
        );

        // ========================== Term ==========================
        {
            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", termFinanceDecoderAndSanitizer);
            ERC20[] memory purchaseTokens = new ERC20[](4);
            purchaseTokens[0] = getERC20(sourceChain, "WETH");
            purchaseTokens[1] = getERC20(sourceChain, "WETH");
            purchaseTokens[2] = getERC20(sourceChain, "WETH");
            purchaseTokens[3] = getERC20(sourceChain, "WETH");
            address[] memory termAuctionOfferLockerAddresses = new address[](4);
            termAuctionOfferLockerAddresses[0] = 0x8b051F8Bc836EC4B01da563dB82df9CD22CA4884;
            termAuctionOfferLockerAddresses[1] = 0x8a98076a97dc3e905b6beEb47268a92658bCf9C1;
            termAuctionOfferLockerAddresses[2] = 0x87b1ac843B0d41EeeE8BD29ad448F8C249E27350;
            termAuctionOfferLockerAddresses[3] = 0x63bbB8925F5Dc5C4786fbE2B01a34Dd04672dB37;
            address[] memory termRepoLockers = new address[](4);
            termRepoLockers[0] = 0x330e701F0523b445958f0484E6Ea3656c55932A4;
            termRepoLockers[1] = 0x46044AccFa442cDd1f4958847CC05F01a59b9610;
            termRepoLockers[2] = 0xe78a151b155115e829423055Cc9f7B1b4c63C2a6;
            termRepoLockers[3] = 0x5ec96157b5c9296A6383E4Cd63B9aA61E0b2da01;
            address[] memory termRepoServicers = new address[](4);
            termRepoServicers[0] = 0x4895958D1F170Db5fD71bcf3B2cE0dA40A0e38FF;
            termRepoServicers[1] = 0x859B4aDc287E76fe7076F6Af9bfB56e3E9253c1c;
            termRepoServicers[2] = 0xC419779ffDc0DEf108Cc26935ec4DaAC89e7ed40;
            termRepoServicers[3] = 0xc9a1b71211455b25c93E6d7e8cC60E065F62C1a4;
            _addTermFinanceLockOfferLeafs(leafs, purchaseTokens, termAuctionOfferLockerAddresses, termRepoLockers);
            _addTermFinanceUnlockOfferLeafs(leafs, termAuctionOfferLockerAddresses);
            _addTermFinanceRevealOfferLeafs(leafs, termAuctionOfferLockerAddresses);
            _addTermFinanceRedeemTermRepoTokensLeafs(leafs, termRepoServicers);
        }
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== ITB Reserve ==========================
        {
            ERC20[] memory tokensUsed = new ERC20[](4);
            tokensUsed[0] = getERC20(sourceChain, "SFRXETH");
            tokensUsed[1] = getERC20(sourceChain, "WSTETH");
            tokensUsed[2] = getERC20(sourceChain, "RETH");
            tokensUsed[3] = getERC20(sourceChain, "ETHX");
            _addLeafsForItbReserve(
                leafs, itbReserveProtocolPositionManager, tokensUsed, "ETHPlus ITB Reserve Protocol Position Manager"
            );
        }
        // ========================== ITB Lido Aave V3 wETH ==========================
        {
            itbDecoderAndSanitizer = itbAaveDecoderAndSanitizer;
            supplyAssets = new ERC20[](1);
            supplyAssets[0] = getERC20(sourceChain, "WETH");
            _addLeafsForItbAaveV3(leafs, itbAaveLidoPositionManager, supplyAssets, "ITB Aave V3 WETH");
            _addLeafsForItbAaveV3(leafs, itbAaveLidoPositionManager2, supplyAssets, "ITB Aave V3 WETH 2");
        }
        // ========================== ITB Cork ==========================
        {
            itbDecoderAndSanitizer = itbCorkDecoderAndSanitizer;
            supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "WEETH");
            supplyAssets[1] = getERC20(sourceChain, "WSTETH");
            _addLeafsForItbCork(
                leafs,
                0x774A82AfAdb5A63d92B980D179D8B0f2E6d577A0,
                supplyAssets,
                "ITB Cork WEETH - WSTETH",
                0xD7CAc118c007E6427ABD693e193E90a6918ce404
            );

            supplyAssets[0] = getERC20(sourceChain, "WSTETH");
            supplyAssets[1] = getERC20(sourceChain, "WETH");
            _addLeafsForItbCork(
                leafs,
                0xB5204c5eE9549bA053cd482813B4FA167805DC93,
                supplyAssets,
                "ITB Cork WSTETH - WETH",
                0x479657445b35fc57736C4cA7D0410AE7190CF692
            );
        }
        // ========================== Native Bridge Leafs ==========================
        {
            ERC20[] memory bridgeAssets = new ERC20[](5);
            bridgeAssets[0] = getERC20(sourceChain, "WETH");
            bridgeAssets[1] = getERC20(sourceChain, "WEETH");
            bridgeAssets[2] = getERC20(sourceChain, "WSTETH");
            bridgeAssets[3] = getERC20(sourceChain, "RETH");
            bridgeAssets[4] = getERC20(sourceChain, "CBETH");
            _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);
        }
        // ========================== CCIP Bridge Leafs ==========================
        {
            ERC20[] memory ccipBridgeAssets = new ERC20[](1);
            ccipBridgeAssets[0] = getERC20(sourceChain, "WETH");
            ERC20[] memory ccipBridgeFeeAssets = new ERC20[](2);
            ccipBridgeFeeAssets[0] = getERC20(sourceChain, "WETH");
            ccipBridgeFeeAssets[1] = getERC20(sourceChain, "LINK");
            _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, ccipBridgeAssets, ccipBridgeFeeAssets);
        }

        // ========================== Standard Bridge ==========================
        {
            ERC20[] memory localTokens = new ERC20[](2);
            localTokens[0] = getERC20(sourceChain, "RETH");
            localTokens[1] = getERC20(sourceChain, "CBETH");
            ERC20[] memory remoteTokens = new ERC20[](2);
            remoteTokens[0] = getERC20(optimism, "RETH");
            remoteTokens[1] = getERC20(optimism, "CBETH");
            _addStandardBridgeLeafs(
                leafs,
                optimism,
                getAddress(optimism, "crossDomainMessenger"),
                getAddress(sourceChain, "optimismResolvedDelegate"),
                getAddress(sourceChain, "optimismStandardBridge"),
                getAddress(sourceChain, "optimismPortal"),
                localTokens,
                remoteTokens
            );

            remoteTokens[0] = getERC20(base, "RETH");
            remoteTokens[1] = getERC20(base, "CBETH");

            _addStandardBridgeLeafs(
                leafs,
                base,
                getAddress(base, "crossDomainMessenger"),
                getAddress(sourceChain, "baseResolvedDelegate"),
                getAddress(sourceChain, "baseStandardBridge"),
                getAddress(sourceChain, "basePortal"),
                localTokens,
                remoteTokens
            );

            ERC20[] memory swellLocalTokens = new ERC20[](0);
            ERC20[] memory swellRemoteTokens = new ERC20[](0);

            _addStandardBridgeLeafs(
                leafs,
                swell,
                getAddress(swell, "crossDomainMessenger"),
                getAddress(sourceChain, "swellResolvedDelegate"),
                getAddress(sourceChain, "swellStandardBridge"),
                getAddress(sourceChain, "swellPortal"),
                swellLocalTokens,
                swellRemoteTokens
            );

            ERC20[] memory unichainLocalTokens = new ERC20[](1);
            ERC20[] memory unichainRemoteTokens = new ERC20[](1);
            unichainLocalTokens[0] = getERC20(sourceChain, "WETH");
            unichainRemoteTokens[0] = getERC20(unichain, "WETH");

            _addStandardBridgeLeafs(
                leafs,
                unichain,
                getAddress(unichain, "crossDomainMessenger"),
                getAddress(sourceChain, "unichainResolvedDelegate"),
                getAddress(sourceChain, "unichainStandardBridge"),
                getAddress(sourceChain, "unichainPortal"),
                unichainLocalTokens,
                unichainRemoteTokens
            );
        }

        {
            ERC20[] memory inkLocalTokens = new ERC20[](0);
            ERC20[] memory inkRemoteTokens = new ERC20[](0);

            _addStandardBridgeLeafs(
                leafs,
                ink,
                getAddress(ink, "crossDomainMessenger"),
                getAddress(sourceChain, "inkResolvedDelegate"),
                getAddress(sourceChain, "inkStandardBridge"),
                getAddress(sourceChain, "inkPortal"),
                inkLocalTokens,
                inkRemoteTokens
            );
        }

        // ========================== LayerZero ==========================
        {
            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "EtherFiOFTAdapter"),
                layerZeroOptimismEndpointId,
                getBytes32(sourceChain, "boringVault")
            );

            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "EtherFiOFTAdapter"),
                layerZeroBaseEndpointId,
                getBytes32(sourceChain, "boringVault")
            );

            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "EtherFiOFTAdapter"),
                layerZeroSwellEndpointId,
                getBytes32(sourceChain, "boringVault")
            );

            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "EtherFiOFTAdapter"),
                layerZeroUnichainEndpointId,
                getBytes32(sourceChain, "boringVault")
            );

            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "EtherFiOFTAdapter"),
                layerZeroScrollEndpointId,
                getBytes32(sourceChain, "boringVault")
            );

            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "EtherFiOFTAdapter"),
                layerZeroInkEndpointId,
                getBytes32(sourceChain, "boringVault")
            );

            _addLayerZeroLeafNative(
                leafs,
                getAddress(sourceChain, "stargateNative"),
                layerZeroScrollEndpointId,
                getBytes32(sourceChain, "boringVault")
            );
        }
        // ========================== Scroll Bridge ==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", scrollBridgeDecoderAndSanitizer);
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = getERC20(sourceChain, "WETH");
        address[] memory scrollGateways = new address[](1);
        scrollGateways[0] = getAddress(scroll, "scrollWETHGateway");
        _addScrollNativeBridgeLeafs(leafs, "scroll", tokens, scrollGateways);

        // ========================== Merkl ==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        {
            _addMerklLeafs(
                leafs,
                getAddress(sourceChain, "merklDistributor"),
                getAddress(sourceChain, "dev1Address")
            );
        }

        // ========================== Karak ==========================
        _addKarakLeafs(leafs, getAddress(sourceChain, "vaultSupervisor"), getAddress(sourceChain, "kweETH"));

        // ========================== Treehouse ==========================
        {
            ERC20[] memory routerTokensIn = new ERC20[](1);
            routerTokensIn[0] = getERC20(sourceChain, "WSTETH");
            _addTreehouseLeafs(
                leafs,
                routerTokensIn,
                getAddress(sourceChain, "TreehouseRouter"),
                getAddress(sourceChain, "TreehouseRedemption"),
                getERC20(sourceChain, "tETH"),
                getAddress(sourceChain, "tETH_wstETH_curve_pool"),
                2,
                address(0)
            );
        }

        // ========================== KING Claiming ==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", kingClaimingDecoderAndSanitizer);
        _addKingRewardsClaimingLeafs(leafs, new address[](0), getAddress(sourceChain, "boringVault"));

        // ========================== Reward Token Unwrapping ==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", getAddress(sourceChain, "rewardTokenUnwrappingDecoder"));
        _addrEULWrappingLeafs(leafs); //unwrap rEUL for EUL

        // ========================== PancakeSwapV3 ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", pancakeSwapDataDecoderAndSanitizer);

        token0 = new address[](8);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token0[3] = getAddress(sourceChain, "WEETH");
        token0[4] = getAddress(sourceChain, "WEETH");
        token0[5] = getAddress(sourceChain, "WSTETH");
        token0[6] = getAddress(sourceChain, "WETH");
        token0[7] = getAddress(sourceChain, "WETH");

        token1 = new address[](8);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "RETH");
        token1[3] = getAddress(sourceChain, "WSTETH");
        token1[4] = getAddress(sourceChain, "RETH");
        token1[5] = getAddress(sourceChain, "RETH");
        token1[6] = getAddress(sourceChain, "SFRXETH");
        token1[7] = getAddress(sourceChain, "CBETH");

        _addPancakeSwapV3Leafs(leafs, token0, token1);

        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        {
        // ========================== sUSDe ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));

        // ========================== RWA Vault ==========================
        // ERC20[] memory rwaVaultAssets = new ERC20[](2);
        // rwaVaultAssets[0] = getERC20(sourceChain, "USDT");
        // rwaVaultAssets[1] = getERC20(sourceChain, "USDE");

        // address ethenaRWATeller = 0xDEa662f24389eB7CaFA9b3B10021884FCe7314f0;
        // _addTellerLeafs(leafs, ethenaRWATeller, rwaVaultAssets, true, true);
        }

        // ========================== Plasma Bridging ==========================
        // Needs info
        // USDT
        {
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT"),
            getAddress(sourceChain, "usdt0OFTAdapter"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ETH
        _addLayerZeroLeafNative(
            leafs,
            getAddress(sourceChain, "stargateNative"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // SUSDE
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "SUSDE"),
            getAddress(sourceChain, "SUSDEOFTAdapter"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // USDE
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDE"),
            getAddress(sourceChain, "USDEOFTAdapter"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        
        // WEETH
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WEETH"),
            getAddress(sourceChain, "EtherFiOFTAdapter"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        }

        // ========================== Reclamation ==========================
        {
            address reclamationDecoder = 0xd7335170816912F9D06e23d23479589ed63b3c33;
            address target = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
            target = 0xC4F5Ee078a1C4DA280330546C29840d45ab32753;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
            target = 0x572F323Aa330B467C356c5a30Bf9A20480F4fD52;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
        }

        // ========================== Hyperlane ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", hyperlaneDecoderAndSanitizer);

            uint32 destinationDomain = 1408864445;
            bytes32 recipient = 0x87559103e75eab777571ffabebe0f4f48e729b2a621877aab97084cad3303cbf;
            ERC20 asset = ERC20(0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88);
            address hyperlaneWeETHsRouter = 0xef899e92DA472E014bE795Ecce948308958E25A2;
            _addLeafsForHyperlane(leafs, destinationDomain, recipient, asset, hyperlaneWeETHsRouter);
        }

        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        // ========================== ITB Position Manager ==========================
        /**
         * acceptOwnership() of ITB position manager
         * transfer ETH tokens to ITB position manager
         * withdraw ETH tokens from ITB position manager
         * withdrawAll ETH tokens from ITB position manager
         */
        address itbPositionManager = 0x7F37350F463525c2670b10234FB014BC406F851c;
        ERC20[] memory itbTokensUsed = new ERC20[](3);
        itbTokensUsed[0] = getERC20(sourceChain, "WETH");
        itbTokensUsed[1] = getERC20(sourceChain, "WEETH");
        itbTokensUsed[2] = getERC20(sourceChain, "EETH");
        _addLeafsForITBPositionManager(leafs, itbPositionManager, itbTokensUsed, "ITB Position Manager");

        address itbPositionManager2 = 0xA40aFb15275A94F64aF37C0cEaAaA45Cb568A361;
        address itbPositionManager3 = 0x2A601FC6C0Cb854fDA82715E49Ab04C5340A0396;
        ERC20[] memory itbTokensUsed2 = new ERC20[](1);
        itbTokensUsed2[0] = getERC20(sourceChain, "WEETH");
        // Aave weETH -> RLUSD -> RLUSD Aave Horizon 
        _addLeafsForITBPositionManager(leafs, itbPositionManager2, itbTokensUsed2, "ITB Position Manager 2");
        //Spark weETH → PYUSD → PYUSD Euler
        _addLeafsForITBPositionManager(leafs, itbPositionManager3, itbTokensUsed2, "ITB Position Manager 3");

        // ========================== Drone Setup ===============================
        {
            ERC20[] memory localTokens = new ERC20[](3);   
            localTokens[0] = getERC20(sourceChain, "USDC"); 
            localTokens[1] = getERC20(sourceChain, "WEETH");
            localTokens[2] = getERC20(sourceChain, "USDE");

            _addLeafsForDroneTransfers(leafs, drone, localTokens);
            _addLeafsForDrone(leafs);
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/MainnetMultiChainLiquidEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManager(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        // acceptOwnership
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ", itbContractName, " contract"),
            itbDecoderAndSanitizer
        );

        // removeExecutor
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "removeExecutor(address)",
            new address[](0),
            string.concat("Remove executor from the ", itbContractName, " contract"),
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
            leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdraw(address,uint256)",
                new address[](0),
                string.concat("Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdrawAll(address)",
                new address[](0),
                string.concat("Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
        }
    }

    function _addLeafsForItbAaveV3(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);
        for (uint256 i; i < tokensUsed.length; ++i) {
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "deposit(address,uint256)",
                new address[](1),
                string.concat("Deposit ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            // Withdraw Supply
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdrawSupply(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", tokensUsed[i].symbol(), " supply from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
        }

        // Approve Lido v3 Pool to spend tokensUsed.
        for (uint256 i; i < tokensUsed.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(tokensUsed[i]),
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                string.concat(itbContractName, ": Approve ", tokensUsed[i].symbol(), " to be spent by the Lido v3 Pool"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "v3LidoPool");
        }
    }

    function _addLeafsForItbReserve(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);

        // mint
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "mint(uint256)",
            new address[](0),
            string.concat("Mint ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeem
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeem(uint256,uint256[])",
            new address[](0),
            string.concat("Redeem ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeemCustom
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeemCustom(uint256,uint48[],uint192[],address[],uint256[])",
            new address[](tokensUsed.length),
            string.concat("Redeem custom ", itbContractName),
            itbDecoderAndSanitizer
        );
        for (uint256 i; i < tokensUsed.length; ++i) {
            leafs[leafIndex].argumentAddresses[i] = address(tokensUsed[i]);
        }

        // assemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "assemble(uint256,uint256)",
            new address[](0),
            string.concat("Assemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // disassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "disassemble(uint256,uint256[])",
            new address[](0),
            string.concat("Disassemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // fullDisassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "fullDisassemble(uint256[])",
            new address[](0),
            string.concat("Full disassemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // approveToken
        for (uint256 i; i < tokensUsed.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                string.concat(itbContractName, ": Approve ", tokensUsed[i].symbol(), " to be spend by ITB Reserve"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "ETHPlus");
        }
    }

    function _addLeafsForItbCork(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName,
        address coverToken
    ) internal {
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);

        // //update position config
        // leafIndex++;
        // leafs[leafIndex] = ManageLeaf(
        //     itbPositionManager,
        //     false,
        //     "updatePositionConfig(address,bytes32,uint256)",
        //     new address[](1),
        //     string.concat("Update position config of ", itbContractName),
        //     itbCorkDecoderAndSanitizer
        // );
        // leafs[leafIndex].argumentAddresses[0] = vault; // TODO find which one

        // Implemented on decoder but not on position manager
        // //update vault supervisor
        // leafIndex++;
        // leafs[leafIndex] = ManageLeaf(
        //     itbPositionManager,
        //     false,
        //     "updateVaultSupervisor(address)",
        //     new address[](1),
        //     string.concat("Update vault supervisor of ", itbContractName),
        //     itbCorkDecoderAndSanitizer
        // );
        // leafs[leafIndex].argumentAddresses[0] = vaultSupervisor; // TODO find which one

        // // update 1Inch router
        // leafIndex++;
        // leafs[leafIndex] = ManageLeaf(
        //     itbPositionManager,
        //     false,
        //     "update1InchRouter(address)",
        //     new address[](1),
        //     string.concat("Update 1Inch router of ", itbContractName),
        //     itbCorkDecoderAndSanitizer
        // );
        // leafs[leafIndex].argumentAddresses[0] = 1InchRouter;

        // deposit Lv (Liquidity Vault)
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "depositLv(uint256,uint256)",
            new address[](0),
            string.concat("Deposit Lv (Liquidity Vault) using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // swap Pa (Pegged Asset) to Ra (Redemption Asset)
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "swapPaToRa(bytes,uint256)",
            new address[](0),
            string.concat("Swap Pa (Pegged Asset) to Ra (Redemption Asset) using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // swap CtDs (Cover Token and Depeg Swap) to Ra (Redemption Asset)
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "swapCtDsToRa(uint256,uint256)",
            new address[](0),
            string.concat("Swap CtDs (Cover Token Depeg Swap) to Ra (Redemption Asset) using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // swap DsPa  (Depeg Swap and Pegged Asset) to Ra (Redemption Asset)
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "swapDsPaToRa(uint256,uint256)",
            new address[](0),
            string.concat("Swap DsPa (Depeg Swap and Pegged Asset) to Ra (Redemption Asset) using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeem expired Ct (Cover Token)
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeemExpiredCt(address,uint256,uint256)",
            new address[](1),
            string.concat("Redeem expired Ct (Cover Token) using ", itbContractName),
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = coverToken; // TODO find which one

        // start withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "startWithdrawal(uint256,uint256)",
            new address[](0),
            string.concat("Start withdrawal using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // claim withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "claimWithdrawal(bytes32)",
            new address[](0),
            string.concat("Claim withdrawal using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // complete withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "completeWithdrawal(uint256,uint256)",
            new address[](0),
            string.concat("Complete withdrawal using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // complete next withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "completeNextWithdrawal(uint256)",
            new address[](0),
            string.concat("Complete next withdrawal using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // complete next withdrawals
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "completeNextWithdrawals(uint256)",
            new address[](0),
            string.concat("Complete next withdrawals using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // override withdrawal indexes
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "overrideWithdrawalIndexes(uint256,uint256)",
            new address[](0),
            string.concat("Override withdrawal indexes using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // assemble (different params)
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "assemble(uint256)",
            new address[](0),
            string.concat("Assemble using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // disassemble (different params)
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "disassemble(uint256,uint256)",
            new address[](0),
            string.concat("Disassemble using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // full disassemble (different params)
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "fullDisassemble(uint256)",
            new address[](0),
            string.concat("Full disassemble using ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeem expired Ct (Cover Token) by config
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeemExpiredCtByConfig(uint256,uint256)",
            new address[](0),
            string.concat("Redeem expired Ct (Cover Token) by config using ", itbContractName),
            itbDecoderAndSanitizer
        );
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs) internal {
        setAddress(true, mainnet, "boringVault", drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== Aave V3 ===============================
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "WEETH");
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Pendle ===============================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_market_09_25_25"), true);

        // ========================== 1Inch ===============================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "USDE");
        kind[2] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ===============================
        _addOdosSwapLeafs(leafs, assets, kind);

        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }
}
