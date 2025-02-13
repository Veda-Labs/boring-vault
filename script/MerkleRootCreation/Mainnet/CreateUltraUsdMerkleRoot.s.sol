// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateUltraUsdMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateUltraUsdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
    address public boringVault = 0xbc0f3B23930fff9f4894914bD745ABAbA9588265;
    address public rawDataDecoderAndSanitizer = 0x4Cb75353D930C212Bbb800eE9e52B28A16684931;
    address public managerAddress = 0x4f81c27e750A453d6206C2d10548d6566F60886C;
    address public accountantAddress = 0x95fE19b324bE69250138FE8EE50356e9f6d17Cfe;
    address public drone = 0x20A0d13C4643AB962C6804BC6ba6Eea0505F11De;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateUltraUsdStrategistMerkleRoot();
    }

    function generateUltraUsdStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](2048);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "USDE");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== Aave V3 ==========================
        ERC20[] memory aaveSupplyAssets = new ERC20[](6);
        aaveSupplyAssets[0] = getERC20(sourceChain, "USDC");
        aaveSupplyAssets[1] = getERC20(sourceChain, "USDT");
        aaveSupplyAssets[2] = getERC20(sourceChain, "DAI");
        aaveSupplyAssets[3] = getERC20(sourceChain, "WEETH");
        aaveSupplyAssets[4] = getERC20(sourceChain, "WSTETH");
        aaveSupplyAssets[5] = getERC20(sourceChain, "USDS");
        ERC20[] memory aaveBorrowAssets = new ERC20[](6);
        aaveBorrowAssets[0] = getERC20(sourceChain, "USDC");
        aaveBorrowAssets[1] = getERC20(sourceChain, "USDT");
        aaveBorrowAssets[2] = getERC20(sourceChain, "DAI");
        aaveBorrowAssets[3] = getERC20(sourceChain, "WETH");
        aaveBorrowAssets[4] = getERC20(sourceChain, "WSTETH");
        aaveBorrowAssets[5] = getERC20(sourceChain, "GHO");
        _addAaveV3Leafs(leafs, aaveSupplyAssets, aaveBorrowAssets);

        // ========================== SparkLend ==========================
        ERC20[] memory sparkLendSupplyAssets = new ERC20[](7);
        sparkLendSupplyAssets[0] = getERC20(sourceChain, "USDC");
        sparkLendSupplyAssets[1] = getERC20(sourceChain, "USDT");
        sparkLendSupplyAssets[2] = getERC20(sourceChain, "DAI");
        sparkLendSupplyAssets[3] = getERC20(sourceChain, "sUSDs");
        sparkLendSupplyAssets[4] = getERC20(sourceChain, "WETH");
        sparkLendSupplyAssets[5] = getERC20(sourceChain, "WSTETH");
        sparkLendSupplyAssets[6] = getERC20(sourceChain, "WEETH");
        ERC20[] memory sparkLendBorrowAssets = new ERC20[](5);
        sparkLendBorrowAssets[0] = getERC20(sourceChain, "USDC");
        sparkLendBorrowAssets[1] = getERC20(sourceChain, "USDT");
        sparkLendBorrowAssets[2] = getERC20(sourceChain, "DAI");
        sparkLendBorrowAssets[3] = getERC20(sourceChain, "WETH");
        sparkLendBorrowAssets[4] = getERC20(sourceChain, "WSTETH");

        _addSparkLendLeafs(leafs, sparkLendSupplyAssets, sparkLendBorrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));
        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));

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

        // ========================== 1inch ==========================
        /*
         *
         */
        address[] memory oneInchAssets = new address[](21);
        SwapKind[] memory oneInchKind = new SwapKind[](21);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchKind[0] = SwapKind.BuyAndSell;
        oneInchAssets[1] = getAddress(sourceChain, "USDT");
        oneInchKind[1] = SwapKind.BuyAndSell;
        oneInchAssets[2] = getAddress(sourceChain, "DAI");
        oneInchKind[2] = SwapKind.BuyAndSell;
        oneInchAssets[3] = getAddress(sourceChain, "USDS");
        oneInchKind[3] = SwapKind.BuyAndSell;
        oneInchAssets[4] = getAddress(sourceChain, "PENDLE");
        oneInchKind[4] = SwapKind.Sell;
        oneInchAssets[5] = getAddress(sourceChain, "deUSD");
        oneInchKind[5] = SwapKind.BuyAndSell;
        oneInchAssets[6] = getAddress(sourceChain, "sdeUSD");
        oneInchKind[6] = SwapKind.BuyAndSell;
        oneInchAssets[7] = getAddress(sourceChain, "USDS");
        oneInchKind[7] = SwapKind.BuyAndSell;
        oneInchAssets[8] = getAddress(sourceChain, "sUSDs");
        oneInchKind[8] = SwapKind.BuyAndSell;
        oneInchAssets[9] = getAddress(sourceChain, "USD0");
        oneInchKind[9] = SwapKind.BuyAndSell;
        oneInchAssets[10] = getAddress(sourceChain, "USD0_plus");
        oneInchKind[10] = SwapKind.BuyAndSell;
        oneInchAssets[11] = getAddress(sourceChain, "WETH");
        oneInchKind[11] = SwapKind.BuyAndSell;
        oneInchAssets[12] = getAddress(sourceChain, "WEETH");
        oneInchKind[12] = SwapKind.BuyAndSell;
        oneInchAssets[13] = getAddress(sourceChain, "USDE");
        oneInchKind[13] = SwapKind.BuyAndSell;
        oneInchAssets[14] = getAddress(sourceChain, "SUSDE");
        oneInchKind[14] = SwapKind.BuyAndSell;
        oneInchAssets[15] = getAddress(sourceChain, "WSTETH");
        oneInchKind[15] = SwapKind.BuyAndSell;
        oneInchAssets[16] = getAddress(sourceChain, "MORPHO");
        oneInchKind[16] = SwapKind.Sell;
        oneInchAssets[17] = getAddress(sourceChain, "USUAL");
        oneInchKind[17] = SwapKind.Sell;
        oneInchAssets[18] = getAddress(sourceChain, "ETHFI");
        oneInchKind[18] = SwapKind.Sell;
        oneInchAssets[19] = getAddress(sourceChain, "USR");
        oneInchKind[19] = SwapKind.BuyAndSell;
        oneInchAssets[20] = getAddress(sourceChain, "GHO");
        oneInchKind[20] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, oneInchKind);

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

        // ========================== UniswapV3 ==========================
        address[] memory uniswapV3Token0 = new address[](78);
        uniswapV3Token0[0] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[1] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[2] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[3] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[4] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[5] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[6] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[7] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[8] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[9] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[10] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[11] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[12] = getAddress(sourceChain, "USDC");
        uniswapV3Token0[13] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[14] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[15] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[16] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[17] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[18] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[19] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[20] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[21] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[22] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[23] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[24] = getAddress(sourceChain, "DAI");
        uniswapV3Token0[25] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[26] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[27] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[28] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[29] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[30] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[31] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[32] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[33] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[34] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[35] = getAddress(sourceChain, "USDT");
        uniswapV3Token0[36] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[37] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[38] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[39] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[40] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[41] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[42] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[43] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[44] = getAddress(sourceChain, "USDS");
        uniswapV3Token0[45] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token0[46] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token0[47] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token0[48] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token0[49] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token0[50] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token0[51] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token0[52] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token0[53] = getAddress(sourceChain, "USD0");
        uniswapV3Token0[54] = getAddress(sourceChain, "USD0");
        uniswapV3Token0[55] = getAddress(sourceChain, "USD0");
        uniswapV3Token0[56] = getAddress(sourceChain, "USD0");
        uniswapV3Token0[57] = getAddress(sourceChain, "USD0");
        uniswapV3Token0[58] = getAddress(sourceChain, "USD0");
        uniswapV3Token0[59] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token0[60] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token0[61] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token0[62] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token0[63] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token0[64] = getAddress(sourceChain, "deUSD");
        uniswapV3Token0[65] = getAddress(sourceChain, "deUSD");
        uniswapV3Token0[66] = getAddress(sourceChain, "deUSD");
        uniswapV3Token0[67] = getAddress(sourceChain, "deUSD");
        uniswapV3Token0[68] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token0[69] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token0[70] = getAddress(sourceChain, "WETH");
        uniswapV3Token0[71] = getAddress(sourceChain, "WETH");
        uniswapV3Token0[72] = getAddress(sourceChain, "USDE");
        uniswapV3Token0[73] = getAddress(sourceChain, "SUSDE");
        uniswapV3Token0[74] = getAddress(sourceChain, "WSTETH");
        uniswapV3Token0[75] = getAddress(sourceChain, "WSTETH");
        uniswapV3Token0[76] = getAddress(sourceChain, "WSTETH");
        uniswapV3Token0[77] = getAddress(sourceChain, "WSTETH");

        address[] memory uniswapV3Token1 = new address[](78);
        uniswapV3Token1[0] = getAddress(sourceChain, "DAI");
        uniswapV3Token1[1] = getAddress(sourceChain, "USDT");
        uniswapV3Token1[2] = getAddress(sourceChain, "USDS");
        uniswapV3Token1[3] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token1[4] = getAddress(sourceChain, "USD0");
        uniswapV3Token1[5] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token1[6] = getAddress(sourceChain, "deUSD");
        uniswapV3Token1[7] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token1[8] = getAddress(sourceChain, "WETH");
        uniswapV3Token1[9] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[10] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[11] = getAddress(sourceChain, "SUSDE");
        uniswapV3Token1[12] = getAddress(sourceChain, "WSTETH");
        uniswapV3Token1[13] = getAddress(sourceChain, "USDT");
        uniswapV3Token1[14] = getAddress(sourceChain, "USDS");
        uniswapV3Token1[15] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token1[16] = getAddress(sourceChain, "USD0");
        uniswapV3Token1[17] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token1[18] = getAddress(sourceChain, "deUSD");
        uniswapV3Token1[19] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token1[20] = getAddress(sourceChain, "WETH");
        uniswapV3Token1[21] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[22] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[23] = getAddress(sourceChain, "SUSDE");
        uniswapV3Token1[24] = getAddress(sourceChain, "WSTETH");
        uniswapV3Token1[25] = getAddress(sourceChain, "USDS");
        uniswapV3Token1[26] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token1[27] = getAddress(sourceChain, "USD0");
        uniswapV3Token1[28] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token1[29] = getAddress(sourceChain, "deUSD");
        uniswapV3Token1[30] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token1[31] = getAddress(sourceChain, "WETH");
        uniswapV3Token1[32] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[33] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[34] = getAddress(sourceChain, "SUSDE");
        uniswapV3Token1[35] = getAddress(sourceChain, "WSTETH");
        uniswapV3Token1[36] = getAddress(sourceChain, "sUSDs");
        uniswapV3Token1[37] = getAddress(sourceChain, "USD0");
        uniswapV3Token1[38] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token1[39] = getAddress(sourceChain, "deUSD");
        uniswapV3Token1[40] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token1[41] = getAddress(sourceChain, "WETH");
        uniswapV3Token1[42] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[43] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[44] = getAddress(sourceChain, "SUSDE");
        uniswapV3Token1[45] = getAddress(sourceChain, "USD0");
        uniswapV3Token1[46] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token1[47] = getAddress(sourceChain, "deUSD");
        uniswapV3Token1[48] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token1[49] = getAddress(sourceChain, "WETH");
        uniswapV3Token1[50] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[51] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[52] = getAddress(sourceChain, "SUSDE");
        uniswapV3Token1[53] = getAddress(sourceChain, "USD0_plus");
        uniswapV3Token1[54] = getAddress(sourceChain, "deUSD");
        uniswapV3Token1[55] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token1[56] = getAddress(sourceChain, "WETH");
        uniswapV3Token1[57] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[58] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[59] = getAddress(sourceChain, "deUSD");
        uniswapV3Token1[60] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token1[61] = getAddress(sourceChain, "WETH");
        uniswapV3Token1[62] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[63] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[64] = getAddress(sourceChain, "sdeUSD");
        uniswapV3Token1[65] = getAddress(sourceChain, "WETH");
        uniswapV3Token1[66] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[67] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[68] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[69] = getAddress(sourceChain, "USDE");
        uniswapV3Token1[70] = getAddress(sourceChain, "WEETH");
        uniswapV3Token1[71] = getAddress(sourceChain, "USDC");
        uniswapV3Token1[72] = getAddress(sourceChain, "USDC");
        uniswapV3Token1[73] = getAddress(sourceChain, "USDC");
        uniswapV3Token1[74] = getAddress(sourceChain, "USDC");
        uniswapV3Token1[75] = getAddress(sourceChain, "DAI");
        uniswapV3Token1[76] = getAddress(sourceChain, "USDT");
        uniswapV3Token1[77] = getAddress(sourceChain, "WETH");

        _addUniswapV3Leafs(leafs, uniswapV3Token0, uniswapV3Token1, true);

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== Drone Transfers ==========================
        ERC20[] memory localTokens = new ERC20[](14);
        localTokens[0] = getERC20("mainnet", "USDC");
        localTokens[1] = getERC20("mainnet", "USDT");
        localTokens[2] = getERC20("mainnet", "DAI");
        localTokens[3] = getERC20("mainnet", "WETH");
        localTokens[4] = getERC20("mainnet", "WEETH");
        localTokens[5] = getERC20("mainnet", "USD0");
        localTokens[6] = getERC20("mainnet", "USD0_plus");
        localTokens[7] = getERC20("mainnet", "deUSD");
        localTokens[8] = getERC20("mainnet", "sdeUSD");
        localTokens[9] = getERC20("mainnet", "USDE");
        localTokens[10] = getERC20("mainnet", "SUSDE");
        localTokens[11] = getERC20("mainnet", "USDS");
        localTokens[12] = getERC20("mainnet", "sUSDs");
        localTokens[13] = getERC20("mainnet", "sDAI");

        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        // ========================== Drone Leafs ==========================

        uint256 startIndex = leafIndex + 1;
        setAddress(true, sourceChain, "boringVault", drone);

        // ========================== Aave V3 ==========================
        _addAaveV3Leafs(leafs, aaveSupplyAssets, aaveBorrowAssets);

        // ========================== SparkLend ==========================
        _addSparkLendLeafs(leafs, sparkLendSupplyAssets, sparkLendBorrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDePT03_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USD0_plusPT03_USDC_915"));

        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));

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

        // ========================== 1inch ==========================
        /*
         *
         */
        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, oneInchKind);

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

        // ========================== UniswapV3 ==========================
        _addUniswapV3Leafs(leafs, uniswapV3Token0, uniswapV3Token1, true);

        // ========================== MakerDAO ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== Drone Transfers ==========================
        localTokens = new ERC20[](14);
        localTokens[0] = getERC20("mainnet", "USDC");
        localTokens[1] = getERC20("mainnet", "USDT");
        localTokens[2] = getERC20("mainnet", "DAI");
        localTokens[3] = getERC20("mainnet", "WETH");
        localTokens[4] = getERC20("mainnet", "WEETH");
        localTokens[5] = getERC20("mainnet", "USD0");
        localTokens[6] = getERC20("mainnet", "USD0_plus");
        localTokens[7] = getERC20("mainnet", "deUSD");
        localTokens[8] = getERC20("mainnet", "sdeUSD");
        localTokens[9] = getERC20("mainnet", "USDE");
        localTokens[10] = getERC20("mainnet", "SUSDE");
        localTokens[11] = getERC20("mainnet", "USDS");
        localTokens[12] = getERC20("mainnet", "sUSDs");
        localTokens[13] = getERC20("mainnet", "sDAI");

        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        // ========================== Drone Functions ==========================
        _createDroneLeafs(leafs, drone, startIndex, leafIndex + 1);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/UltraUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
