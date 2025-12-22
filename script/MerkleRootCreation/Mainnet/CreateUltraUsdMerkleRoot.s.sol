// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateUltraUsdMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 18446744073709551615 --memory-limit 671100000
 */
/// @dev NOTE: This script contains drone leaves. If adding new functionality, be sure to include it in drones as well.
contract CreateUltraUsdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    struct LocalVars {
        address boringVault;
        address rawDataDecoderAndSanitizer;
        address managerAddress;
        address accountantAddress;
        address drone;
        ERC20[] feeAssets;
        ERC20[] aaveSupplyAssets;
        ERC20[] aaveBorrowAssets;
        ERC20[] sparkLendSupplyAssets;
        ERC20[] sparkLendBorrowAssets;
        address[] oneInchAssets;
        SwapKind[] oneInchKind;
        ERC20[] tellerAssets;
        ERC4626[] depositVaults;
        address[] subaccounts;
        ERC4626[] borrowVaults;
        ERC20[] localTokens;
    }

    LocalVars public vars = LocalVars({
        boringVault: 0xbc0f3B23930fff9f4894914bD745ABAbA9588265,
        rawDataDecoderAndSanitizer: 0xd4067b594C6D48990BE42a559C8CfDddad4e8D6F,
        managerAddress: 0x4f81c27e750A453d6206C2d10548d6566F60886C,
        accountantAddress: 0x95fE19b324bE69250138FE8EE50356e9f6d17Cfe,
        drone: 0x20A0d13C4643AB962C6804BC6ba6Eea0505F11De,
        feeAssets: new ERC20[](4),
        aaveSupplyAssets: new ERC20[](6),
        aaveBorrowAssets: new ERC20[](6),
        sparkLendSupplyAssets: new ERC20[](7),
        sparkLendBorrowAssets: new ERC20[](5),
        oneInchAssets: new address[](32),
        oneInchKind: new SwapKind[](32),
        tellerAssets: new ERC20[](4),
        depositVaults: new ERC4626[](1),
        subaccounts: new address[](1),
        borrowVaults: new ERC4626[](1),
        localTokens: new ERC20[](44)
    });

    // address public boringVault = 0xbc0f3B23930fff9f4894914bD745ABAbA9588265;
    // address public rawDataDecoderAndSanitizer = 0xcc547695869e20F69832Bd9A4De9AF65274C2e77;
    // address public managerAddress = 0x4f81c27e750A453d6206C2d10548d6566F60886C;
    // address public accountantAddress = 0x95fE19b324bE69250138FE8EE50356e9f6d17Cfe;
    // address public drone = 0x20A0d13C4643AB962C6804BC6ba6Eea0505F11De;

    function setUp() external { }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateUltraUsdStrategistMerkleRoot();
    }

    function generateUltraUsdStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", vars.boringVault);
        setAddress(false, mainnet, "managerAddress", vars.managerAddress);
        setAddress(false, mainnet, "accountantAddress", vars.accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", vars.rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8192);

        // ========================== Fee Claiming ==========================
        //ERC20[] memory feeAssets = new ERC20[](4);
        vars.feeAssets[0] = getERC20(sourceChain, "USDC");
        vars.feeAssets[1] = getERC20(sourceChain, "DAI");
        vars.feeAssets[2] = getERC20(sourceChain, "USDT");
        vars.feeAssets[3] = getERC20(sourceChain, "USDE");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), vars.feeAssets, false);

        // ========================== Aave V3 ==========================
        //ERC20[] memory aaveSupplyAssets = new ERC20[](6);
        vars.aaveSupplyAssets[0] = getERC20(sourceChain, "USDC");
        vars.aaveSupplyAssets[1] = getERC20(sourceChain, "USDT");
        vars.aaveSupplyAssets[2] = getERC20(sourceChain, "DAI");
        vars.aaveSupplyAssets[3] = getERC20(sourceChain, "WEETH");
        vars.aaveSupplyAssets[4] = getERC20(sourceChain, "WSTETH");
        vars.aaveSupplyAssets[5] = getERC20(sourceChain, "USDS");
        //ERC20[] memory aaveBorrowAssets = new ERC20[](6);
        vars.aaveBorrowAssets[0] = getERC20(sourceChain, "USDC");
        vars.aaveBorrowAssets[1] = getERC20(sourceChain, "USDT");
        vars.aaveBorrowAssets[2] = getERC20(sourceChain, "DAI");
        vars.aaveBorrowAssets[3] = getERC20(sourceChain, "WETH");
        vars.aaveBorrowAssets[4] = getERC20(sourceChain, "WSTETH");
        vars.aaveBorrowAssets[5] = getERC20(sourceChain, "GHO");
        _addAaveV3Leafs(leafs, vars.aaveSupplyAssets, vars.aaveBorrowAssets);

        // ========================== SparkLend ==========================
        //ERC20[] memory sparkLendSupplyAssets = new ERC20[](7);
        vars.sparkLendSupplyAssets[0] = getERC20(sourceChain, "USDC");
        vars.sparkLendSupplyAssets[1] = getERC20(sourceChain, "USDT");
        vars.sparkLendSupplyAssets[2] = getERC20(sourceChain, "DAI");
        vars.sparkLendSupplyAssets[3] = getERC20(sourceChain, "sUSDs");
        vars.sparkLendSupplyAssets[4] = getERC20(sourceChain, "WETH");
        vars.sparkLendSupplyAssets[5] = getERC20(sourceChain, "WSTETH");
        vars.sparkLendSupplyAssets[6] = getERC20(sourceChain, "WEETH");
        //ERC20[] memory sparkLendBorrowAssets = new ERC20[](5);
        vars.sparkLendBorrowAssets[0] = getERC20(sourceChain, "USDC");
        vars.sparkLendBorrowAssets[1] = getERC20(sourceChain, "USDT");
        vars.sparkLendBorrowAssets[2] = getERC20(sourceChain, "DAI");
        vars.sparkLendBorrowAssets[3] = getERC20(sourceChain, "WETH");
        vars.sparkLendBorrowAssets[4] = getERC20(sourceChain, "WSTETH");

        _addSparkLendLeafs(leafs, vars.sparkLendSupplyAssets, vars.sparkLendBorrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCfrontier")));

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        // ========================== Morpho Rewards ==========================
        _addMorphoRewardMerkleClaimerLeafs(leafs, getAddress(sourceChain, "universalRewardsDistributor"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));
        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));
        _addELXClaimingLeafs(leafs);

        // ========================== Elixir Withdraws ==========================
        _addElixirSdeUSDWithdrawLeafs(leafs);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_01_29_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_02_26_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_03_26_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_04_23_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_06_25_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_wstUSR_market_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_lvlUSD_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_slvlUSD_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_syrupUSDC_04_23_25"), true);

        // ========================== 1inch ==========================
        /*
         *
         */
        //address[] memory oneInchAssets = new address[](30);
        //SwapKind[] memory oneInchKind = new SwapKind[](30);
        vars.oneInchAssets[0] = getAddress(sourceChain, "USDC");
        vars.oneInchKind[0] = SwapKind.BuyAndSell;
        vars.oneInchAssets[1] = getAddress(sourceChain, "USDT");
        vars.oneInchKind[1] = SwapKind.BuyAndSell;
        vars.oneInchAssets[2] = getAddress(sourceChain, "DAI");
        vars.oneInchKind[2] = SwapKind.BuyAndSell;
        vars.oneInchAssets[3] = getAddress(sourceChain, "USDS");
        vars.oneInchKind[3] = SwapKind.BuyAndSell;
        vars.oneInchAssets[4] = getAddress(sourceChain, "PENDLE");
        vars.oneInchKind[4] = SwapKind.Sell;
        vars.oneInchAssets[5] = getAddress(sourceChain, "deUSD");
        vars.oneInchKind[5] = SwapKind.BuyAndSell;
        vars.oneInchAssets[6] = getAddress(sourceChain, "sdeUSD");
        vars.oneInchKind[6] = SwapKind.BuyAndSell;
        vars.oneInchAssets[7] = getAddress(sourceChain, "USDS");
        vars.oneInchKind[7] = SwapKind.BuyAndSell;
        vars.oneInchAssets[8] = getAddress(sourceChain, "sUSDs");
        vars.oneInchKind[8] = SwapKind.BuyAndSell;
        vars.oneInchAssets[9] = getAddress(sourceChain, "USD0");
        vars.oneInchKind[9] = SwapKind.BuyAndSell;
        vars.oneInchAssets[10] = getAddress(sourceChain, "USD0_plus");
        vars.oneInchKind[10] = SwapKind.BuyAndSell;
        vars.oneInchAssets[11] = getAddress(sourceChain, "WETH");
        vars.oneInchKind[11] = SwapKind.BuyAndSell;
        vars.oneInchAssets[12] = getAddress(sourceChain, "WEETH");
        vars.oneInchKind[12] = SwapKind.BuyAndSell;
        vars.oneInchAssets[13] = getAddress(sourceChain, "USDE");
        vars.oneInchKind[13] = SwapKind.BuyAndSell;
        vars.oneInchAssets[14] = getAddress(sourceChain, "SUSDE");
        vars.oneInchKind[14] = SwapKind.BuyAndSell;
        vars.oneInchAssets[15] = getAddress(sourceChain, "WSTETH");
        vars.oneInchKind[15] = SwapKind.BuyAndSell;
        vars.oneInchAssets[16] = getAddress(sourceChain, "MORPHO");
        vars.oneInchKind[16] = SwapKind.Sell;
        vars.oneInchAssets[17] = getAddress(sourceChain, "USUAL");
        vars.oneInchKind[17] = SwapKind.Sell;
        vars.oneInchAssets[18] = getAddress(sourceChain, "ETHFI");
        vars.oneInchKind[18] = SwapKind.Sell;
        vars.oneInchAssets[19] = getAddress(sourceChain, "USR");
        vars.oneInchKind[19] = SwapKind.BuyAndSell;
        vars.oneInchAssets[20] = getAddress(sourceChain, "GHO");
        vars.oneInchKind[20] = SwapKind.BuyAndSell;
        vars.oneInchAssets[21] = getAddress(sourceChain, "lvlUSD");
        vars.oneInchKind[21] = SwapKind.BuyAndSell;
        vars.oneInchAssets[22] = getAddress(sourceChain, "slvlUSD");
        vars.oneInchKind[22] = SwapKind.BuyAndSell;
        vars.oneInchAssets[23] = getAddress(sourceChain, "EIGEN");
        vars.oneInchKind[23] = SwapKind.Sell;
        vars.oneInchAssets[24] = getAddress(sourceChain, "KING");
        vars.oneInchKind[24] = SwapKind.Sell;
        vars.oneInchAssets[25] = getAddress(sourceChain, "ELX");
        vars.oneInchKind[25] = SwapKind.Sell;
        vars.oneInchAssets[26] = getAddress(sourceChain, "syrupUSDC");
        vars.oneInchKind[26] = SwapKind.BuyAndSell;
        vars.oneInchAssets[27] = getAddress(sourceChain, "syrupUSDT");
        vars.oneInchKind[27] = SwapKind.BuyAndSell;
        vars.oneInchAssets[28] = getAddress(sourceChain, "WSTUSR");
        vars.oneInchKind[28] = SwapKind.BuyAndSell;
        vars.oneInchAssets[29] = getAddress(sourceChain, "EUL");
        vars.oneInchKind[29] = SwapKind.Sell;
        vars.oneInchAssets[30] = getAddress(sourceChain, "AURA");
        vars.oneInchKind[30] = SwapKind.Sell;
        vars.oneInchAssets[31] = getAddress(sourceChain, "BAL");
        vars.oneInchKind[31] = SwapKind.Sell;

        _addLeafsFor1InchGeneralSwapping(leafs, vars.oneInchAssets, vars.oneInchKind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, vars.oneInchAssets, vars.oneInchKind);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);
        // Additional decoder for claiming needs to be made

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "USD0_USD0++_CurvePool"),
            2,
            getAddress(sourceChain, "USD0_USD0++_CurveGauge")
        );
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "USD0_USD0++_CurvePool"));

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== lvlUSD ==========================
        _addLevelLeafs(leafs);

        // ========================== Spectra ==========================
        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_lvlUSD_Pool"),
            getAddress(sourceChain, "spectra_lvlUSD_PT"),
            getAddress(sourceChain, "spectra_lvlUSD_YT"),
            getAddress(sourceChain, "spectra_lvlUSD_IBT")
        );

        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_sdeUSD_Pool"),
            getAddress(sourceChain, "spectra_sdeUSD_PT"),
            getAddress(sourceChain, "spectra_sdeUSD_YT"),
            getAddress(sourceChain, "spectra_sdeUSD_IBT")
        );

        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_wstUSR_Pool"),
            getAddress(sourceChain, "spectra_wstUSR_PT"),
            getAddress(sourceChain, "spectra_wstUSR_YT"),
            getAddress(sourceChain, "spectra_wstUSR_IBT")
        );

        // ========================== Resolv ==========================
        _addAllResolvLeafs(leafs);

        // ========================== Teller ==========================
        //ERC20[] memory tellerAssets = new ERC20[](4);
        vars.tellerAssets[0] = getERC20(sourceChain, "USDT");
        vars.tellerAssets[1] = getERC20(sourceChain, "USDC");
        vars.tellerAssets[2] = getERC20(sourceChain, "DAI");
        vars.tellerAssets[3] = getERC20(sourceChain, "USDS");
        _addTellerLeafs(leafs, getAddress(sourceChain, "TACTeller"), vars.tellerAssets, false, false); // No bulkWithdraw
        _addWithdrawQueueLeafs(
            leafs,
            getAddress(sourceChain, "TACOnChainQueue"),
            getAddress(sourceChain, "TurtleTACUSD"),
            vars.tellerAssets
        );

        // ========================== BalancerV3 ==========================
        _addBalancerV3Leafs(
            leafs,
            getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"),
            true,
            getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge")
        );

        // ========================== Aura ==========================
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_USDC_GHO_USDT_gauge"));

        // ========================== Syrup ==========================
        _addAllSyrupLeafs(leafs);

        // ========================== Euler ==========================
        //ERC4626[] memory depositVaults = new ERC4626[](1);
        vars.depositVaults[0] = ERC4626(getAddress(sourceChain, "evkeUSDC-22"));

        //address[] memory subaccounts = new address[](1);
        vars.subaccounts[0] = address(vars.boringVault);

        //ERC4626[] memory borrowVaults = new ERC4626[](1);
        vars.borrowVaults[0] = ERC4626(getAddress(sourceChain, "evkeUSDC-22"));

        _addEulerDepositLeafs(leafs, vars.depositVaults, vars.subaccounts);
        _addEulerBorrowLeafs(leafs, vars.borrowVaults, vars.subaccounts);
        // Add reward claiming
        ERC20[] memory tokensToClaim = new ERC20[](1);
        tokensToClaim[0] = getERC20(sourceChain, "rEUL");

        // ========================== Merkl Rewards for Euler ==========================
        _addMerklLeafs(
            leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"), tokensToClaim
        );

        // ========================== Fluid Dex ==========================
        {
            ERC20[] memory supplyTokens = new ERC20[](1);
            supplyTokens[0] = getERC20(sourceChain, "SUSDE");

            ERC20[] memory borrowTokens = new ERC20[](2);
            borrowTokens[0] = getERC20(sourceChain, "USDT");
            borrowTokens[1] = getERC20(sourceChain, "USDC");

            uint256 dexType = 3000;

            _addFluidDexLeafs(
                leafs,
                getAddress(sourceChain, "sUSDe_DEX-USDC-USDT"),
                dexType,
                supplyTokens,
                borrowTokens,
                false //no native ETH leaves
            );
        }

        // ========================== King ==========================
        _addKingRewardsClaimingLeafs(leafs, new address[](0), vars.boringVault);

        // ========================== Drone Transfers ==========================
        //ERC20[] memory localTokens = new ERC20[](42);
        vars.localTokens[0] = getERC20("mainnet", "USDC");
        vars.localTokens[1] = getERC20("mainnet", "USDT");
        vars.localTokens[2] = getERC20("mainnet", "DAI");
        vars.localTokens[3] = getERC20("mainnet", "WETH");
        vars.localTokens[4] = getERC20("mainnet", "WEETH");
        vars.localTokens[5] = getERC20("mainnet", "USD0");
        vars.localTokens[6] = getERC20("mainnet", "USD0_plus");
        vars.localTokens[7] = getERC20("mainnet", "deUSD");
        vars.localTokens[8] = getERC20("mainnet", "sdeUSD");
        vars.localTokens[9] = getERC20("mainnet", "USDE");
        vars.localTokens[10] = getERC20("mainnet", "SUSDE");
        vars.localTokens[11] = getERC20("mainnet", "USDS");
        vars.localTokens[12] = getERC20("mainnet", "sUSDs");
        vars.localTokens[13] = getERC20("mainnet", "sDAI");
        vars.localTokens[14] = getERC20("mainnet", "lvlUSD");
        vars.localTokens[15] = getERC20("mainnet", "slvlUSD");
        vars.localTokens[16] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_sy");
        vars.localTokens[17] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_pt");
        vars.localTokens[18] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_yt");
        vars.localTokens[19] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_sy");
        vars.localTokens[20] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_pt");
        vars.localTokens[21] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_yt");
        vars.localTokens[22] = getERC20("mainnet", "syrupUSDC");
        vars.localTokens[23] = getERC20("mainnet", "syrupUSDT");
        vars.localTokens[24] = getERC20("mainnet", "wstUSR");
        vars.localTokens[25] = getERC20("mainnet", "ETHFI");
        vars.localTokens[26] = getERC20("mainnet", "USR");
        vars.localTokens[27] = getERC20("mainnet", "GHO");
        vars.localTokens[28] = getERC20("mainnet", "ELX");
        vars.localTokens[29] = getERC20("mainnet", "KING");
        vars.localTokens[30] = getERC20("mainnet", "EIGEN");
        vars.localTokens[31] = getERC20("mainnet", "pendle_sUSDe_03_26_25_sy");
        vars.localTokens[32] = getERC20("mainnet", "pendle_sUSDe_03_26_25_pt");
        vars.localTokens[33] = getERC20("mainnet", "pendle_sUSDe_03_26_25_yt");
        vars.localTokens[34] = getERC20("mainnet", "pendle_sUSDe_05_28_25_sy");
        vars.localTokens[35] = getERC20("mainnet", "pendle_sUSDe_05_28_25_pt");
        vars.localTokens[36] = getERC20("mainnet", "pendle_sUSDe_05_28_25_yt");
        vars.localTokens[37] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_sy");
        vars.localTokens[38] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_pt");
        vars.localTokens[39] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_yt");
        vars.localTokens[40] = getERC20("mainnet", "EUL");
        vars.localTokens[41] = getERC20("mainnet", "rEUL");
        vars.localTokens[42] = getERC20("mainnet", "AURA");
        vars.localTokens[43] = getERC20("mainnet", "BAL");

        _addLeafsForDroneTransfers(leafs, vars.drone, vars.localTokens);

        // ====================================================
        //
        //                  Begin Drone Leaves
        //
        // ====================================================

        uint256 startIndex = leafIndex + 1;
        setAddress(true, sourceChain, "boringVault", vars.drone);

        // ========================== Aave V3 ==========================
        _addAaveV3Leafs(leafs, vars.aaveSupplyAssets, vars.aaveBorrowAssets);

        // ========================== SparkLend ==========================
        _addSparkLendLeafs(leafs, vars.sparkLendSupplyAssets, vars.sparkLendBorrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCfrontier")));

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        // ========================== Morpho Rewards ==========================
        _addMorphoRewardMerkleClaimerLeafs(leafs, getAddress(sourceChain, "universalRewardsDistributor"));

        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));
        _addELXClaimingLeafs(leafs);

        // ========================== Elixir Withdraws ==========================
        _addElixirSdeUSDWithdrawLeafs(leafs);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_01_29_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_02_26_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_03_26_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_04_23_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0Plus_market_06_25_2025"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_wstUSR_market_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USDe_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_lvlUSD_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_slvlUSD_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_05_28_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_syrupUSDC_04_23_25"), true);

        // ========================== 1inch ==========================
        /*
         *
         */
        _addLeafsFor1InchGeneralSwapping(leafs, vars.oneInchAssets, vars.oneInchKind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, vars.oneInchAssets, vars.oneInchKind);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);
        // Additional decoder for claiming needs to be made

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Ethena ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "USD0_USD0++_CurvePool"),
            2,
            getAddress(sourceChain, "USD0_USD0++_CurveGauge")
        );
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "USD0_USD0++_CurvePool"));

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== lvlUSD ==========================
        _addLevelLeafs(leafs);

        // ========================== Spectra ==========================
        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_lvlUSD_Pool"),
            getAddress(sourceChain, "spectra_lvlUSD_PT"),
            getAddress(sourceChain, "spectra_lvlUSD_YT"),
            getAddress(sourceChain, "spectra_lvlUSD_IBT")
        );

        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_sdeUSD_Pool"),
            getAddress(sourceChain, "spectra_sdeUSD_PT"),
            getAddress(sourceChain, "spectra_sdeUSD_YT"),
            getAddress(sourceChain, "spectra_sdeUSD_IBT")
        );

        _addSpectraLeafs(
            leafs,
            getAddress(sourceChain, "spectra_wstUSR_Pool"),
            getAddress(sourceChain, "spectra_wstUSR_PT"),
            getAddress(sourceChain, "spectra_wstUSR_YT"),
            getAddress(sourceChain, "spectra_wstUSR_IBT")
        );

        // ========================== Resolv ==========================
        _addAllResolvLeafs(leafs);

        // ========================== Teller ==========================
        _addTellerLeafs(leafs, getAddress(sourceChain, "TACTeller"), vars.tellerAssets, false, false); // No bulkWithdraw
        _addWithdrawQueueLeafs(
            leafs,
            getAddress(sourceChain, "TACOnChainQueue"),
            getAddress(sourceChain, "TurtleTACUSD"),
            vars.tellerAssets
        );

        // ========================== BalancerV3 ==========================
        _addBalancerV3Leafs(
            leafs,
            getAddress(sourceChain, "balancerV3_USDC_GHO_USDT"),
            true,
            getAddress(sourceChain, "balancerV3_USDC_GHO_USDT_gauge")
        );

        // ========================== Aura ==========================
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_USDC_GHO_USDT_gauge"));

        // ========================== Syrup ==========================
        _addAllSyrupLeafs(leafs);

        // ========================== Euler ==========================
        vars.subaccounts[0] = address(vars.drone);
        _addEulerDepositLeafs(leafs, vars.depositVaults, vars.subaccounts);
        _addEulerBorrowLeafs(leafs, vars.borrowVaults, vars.subaccounts);

        // ========================== Merkl Rewards for Euler ==========================
        _addMerklLeafs(
            leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"), tokensToClaim
        );

        // ========================== Fluid Dex ==========================
        {
            ERC20[] memory supplyTokens = new ERC20[](1);
            supplyTokens[0] = getERC20(sourceChain, "SUSDE");

            ERC20[] memory borrowTokens = new ERC20[](2);
            borrowTokens[0] = getERC20(sourceChain, "USDT");
            borrowTokens[1] = getERC20(sourceChain, "USDC");

            uint256 dexType = 3000;

            _addFluidDexLeafs(
                leafs,
                getAddress(sourceChain, "sUSDe_DEX-USDC-USDT"),
                dexType,
                supplyTokens,
                borrowTokens,
                false //no native ETH leaves
            );
        }

        // ========================== King ==========================
        _addKingRewardsClaimingLeafs(leafs, new address[](0), vars.drone);

        // ========================== Drone Transfers ==========================
        vars.localTokens = new ERC20[](44);
        vars.localTokens[0] = getERC20("mainnet", "USDC");
        vars.localTokens[1] = getERC20("mainnet", "USDT");
        vars.localTokens[2] = getERC20("mainnet", "DAI");
        vars.localTokens[3] = getERC20("mainnet", "WETH");
        vars.localTokens[4] = getERC20("mainnet", "WEETH");
        vars.localTokens[5] = getERC20("mainnet", "USD0");
        vars.localTokens[6] = getERC20("mainnet", "USD0_plus");
        vars.localTokens[7] = getERC20("mainnet", "deUSD");
        vars.localTokens[8] = getERC20("mainnet", "sdeUSD");
        vars.localTokens[9] = getERC20("mainnet", "USDE");
        vars.localTokens[10] = getERC20("mainnet", "SUSDE");
        vars.localTokens[11] = getERC20("mainnet", "USDS");
        vars.localTokens[12] = getERC20("mainnet", "sUSDs");
        vars.localTokens[13] = getERC20("mainnet", "sDAI");
        vars.localTokens[14] = getERC20("mainnet", "lvlUSD");
        vars.localTokens[15] = getERC20("mainnet", "slvlUSD");
        vars.localTokens[16] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_sy");
        vars.localTokens[17] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_pt");
        vars.localTokens[18] = getERC20("mainnet", "pendle_lvlUSD_05_28_25_yt");
        vars.localTokens[19] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_sy");
        vars.localTokens[20] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_pt");
        vars.localTokens[21] = getERC20("mainnet", "pendle_slvlUSD_05_28_25_yt");
        vars.localTokens[22] = getERC20("mainnet", "syrupUSDC");
        vars.localTokens[23] = getERC20("mainnet", "syrupUSDT");
        vars.localTokens[24] = getERC20("mainnet", "wstUSR");
        vars.localTokens[25] = getERC20("mainnet", "ETHFI");
        vars.localTokens[26] = getERC20("mainnet", "USR");
        vars.localTokens[27] = getERC20("mainnet", "GHO");
        vars.localTokens[28] = getERC20("mainnet", "ELX");
        vars.localTokens[29] = getERC20("mainnet", "KING");
        vars.localTokens[30] = getERC20("mainnet", "EIGEN");
        vars.localTokens[31] = getERC20("mainnet", "pendle_sUSDe_03_26_25_sy");
        vars.localTokens[32] = getERC20("mainnet", "pendle_sUSDe_03_26_25_pt");
        vars.localTokens[33] = getERC20("mainnet", "pendle_sUSDe_03_26_25_yt");
        vars.localTokens[34] = getERC20("mainnet", "pendle_sUSDe_05_28_25_sy");
        vars.localTokens[35] = getERC20("mainnet", "pendle_sUSDe_05_28_25_pt");
        vars.localTokens[36] = getERC20("mainnet", "pendle_sUSDe_05_28_25_yt");
        vars.localTokens[37] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_sy");
        vars.localTokens[38] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_pt");
        vars.localTokens[39] = getERC20("mainnet", "pendle_syrupUSDC_04_23_25_yt");
        vars.localTokens[40] = getERC20("mainnet", "EUL");
        vars.localTokens[41] = getERC20("mainnet", "rEUL");
        vars.localTokens[42] = getERC20("mainnet", "AURA");
        vars.localTokens[43] = getERC20("mainnet", "BAL");

        _addLeafsForDroneTransfers(leafs, vars.drone, vars.localTokens);

        // ========================== Drone Functions ==========================
        _createDroneLeafs(leafs, vars.drone, startIndex, leafIndex + 1);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/UltraUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
