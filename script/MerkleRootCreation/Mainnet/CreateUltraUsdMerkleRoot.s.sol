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
    address public rawDataDecoderAndSanitizer = 0x5eB7B2394dce510AD9575C222E3eaCa9D79B643d;
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

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "USDE");
        _addLeafsForFeeClaiming(leafs, feeAssets);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](5);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "DAI");
        supplyAssets[3] = getERC20(sourceChain, "WEETH");
        supplyAssets[4] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "DAI");
        borrowAssets[3] = getERC20(sourceChain, "WETH");
        borrowAssets[4] = getERC20(sourceChain, "WSTETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SparkLend ==========================
        supplyAssets = new ERC20[](7);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "DAI");
        supplyAssets[3] = getERC20(sourceChain, "sUSDs");
        supplyAssets[4] = getERC20(sourceChain, "WETH");
        supplyAssets[5] = getERC20(sourceChain, "WSTETH");
        supplyAssets[6] = getERC20(sourceChain, "WEETH");
        borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "DAI");
        borrowAssets[3] = getERC20(sourceChain, "WETH");
        borrowAssets[4] = getERC20(sourceChain, "WSTETH");

        _addSparkLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));

        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));

        // ========================== Elixir Withdraws ==========================
        _addElixirSdeUSDWithdrawLeafs(leafs);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_03_26_25"), true);

        // ========================== 1inch ==========================
        /*
         *
         */
        address[] memory assets = new address[](15);
        SwapKind[] memory kind = new SwapKind[](15);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "DAI");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "USDS");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "PENDLE");
        kind[4] = SwapKind.Sell;
        assets[5] = getAddress(sourceChain, "deUSD");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "sdeUSD");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "USDS");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "sUSDs");
        kind[8] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "USD0");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "USD0_plus");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "WETH");
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = getAddress(sourceChain, "WEETH");
        kind[11] = SwapKind.BuyAndSell;
        assets[12] = getAddress(sourceChain, "USDE");
        kind[12] = SwapKind.BuyAndSell;
        assets[13] = getAddress(sourceChain, "SUSDE");
        kind[13] = SwapKind.BuyAndSell;
        assets[14] = getAddress(sourceChain, "WSTETH");
        kind[14] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

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
        _addCurveLeafs(leafs, getAddress(sourceChain, "USD0_USD0++_CurvePool"), 2, getAddress(sourceChain, "USD0_USD0++_CurveGauge"));    
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "USD0_USD0++_CurvePool")); 

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](78);
        token0[0] = getAddress(sourceChain, "USDC");
        token0[1] = getAddress(sourceChain, "USDC");
        token0[2] = getAddress(sourceChain, "USDC");
        token0[3] = getAddress(sourceChain, "USDC");
        token0[4] = getAddress(sourceChain, "USDC");
        token0[5] = getAddress(sourceChain, "USDC");
        token0[6] = getAddress(sourceChain, "USDC");
        token0[7] = getAddress(sourceChain, "USDC");
        token0[8] = getAddress(sourceChain, "USDC");
        token0[9] = getAddress(sourceChain, "USDC");
        token0[10] = getAddress(sourceChain, "USDC");
        token0[11] = getAddress(sourceChain, "USDC");
        token0[12] = getAddress(sourceChain, "USDC");
        token0[13] = getAddress(sourceChain, "DAI");
        token0[14] = getAddress(sourceChain, "DAI");
        token0[15] = getAddress(sourceChain, "DAI");
        token0[16] = getAddress(sourceChain, "DAI");
        token0[17] = getAddress(sourceChain, "DAI");
        token0[18] = getAddress(sourceChain, "DAI");
        token0[19] = getAddress(sourceChain, "DAI");
        token0[20] = getAddress(sourceChain, "DAI");
        token0[21] = getAddress(sourceChain, "DAI");
        token0[22] = getAddress(sourceChain, "DAI");
        token0[23] = getAddress(sourceChain, "DAI");
        token0[24] = getAddress(sourceChain, "DAI");
        token0[25] = getAddress(sourceChain, "USDT");
        token0[26] = getAddress(sourceChain, "USDT");
        token0[27] = getAddress(sourceChain, "USDT");
        token0[28] = getAddress(sourceChain, "USDT");
        token0[29] = getAddress(sourceChain, "USDT");
        token0[30] = getAddress(sourceChain, "USDT");
        token0[31] = getAddress(sourceChain, "USDT");
        token0[32] = getAddress(sourceChain, "USDT");
        token0[33] = getAddress(sourceChain, "USDT");
        token0[34] = getAddress(sourceChain, "USDT");
        token0[35] = getAddress(sourceChain, "USDT");
        token0[36] = getAddress(sourceChain, "USDS");
        token0[37] = getAddress(sourceChain, "USDS");
        token0[38] = getAddress(sourceChain, "USDS");
        token0[39] = getAddress(sourceChain, "USDS");
        token0[40] = getAddress(sourceChain, "USDS");
        token0[41] = getAddress(sourceChain, "USDS");
        token0[42] = getAddress(sourceChain, "USDS");
        token0[43] = getAddress(sourceChain, "USDS");
        token0[44] = getAddress(sourceChain, "USDS");
        token0[45] = getAddress(sourceChain, "sUSDs");
        token0[46] = getAddress(sourceChain, "sUSDs");
        token0[47] = getAddress(sourceChain, "sUSDs");
        token0[48] = getAddress(sourceChain, "sUSDs");
        token0[49] = getAddress(sourceChain, "sUSDs");
        token0[50] = getAddress(sourceChain, "sUSDs");
        token0[51] = getAddress(sourceChain, "sUSDs");
        token0[52] = getAddress(sourceChain, "sUSDs");
        token0[53] = getAddress(sourceChain, "USD0");
        token0[54] = getAddress(sourceChain, "USD0");
        token0[55] = getAddress(sourceChain, "USD0");
        token0[56] = getAddress(sourceChain, "USD0");
        token0[57] = getAddress(sourceChain, "USD0");
        token0[58] = getAddress(sourceChain, "USD0");
        token0[59] = getAddress(sourceChain, "USD0_plus");
        token0[60] = getAddress(sourceChain, "USD0_plus");
        token0[61] = getAddress(sourceChain, "USD0_plus");
        token0[62] = getAddress(sourceChain, "USD0_plus");
        token0[63] = getAddress(sourceChain, "USD0_plus");
        token0[64] = getAddress(sourceChain, "deUSD");
        token0[65] = getAddress(sourceChain, "deUSD");
        token0[66] = getAddress(sourceChain, "deUSD");
        token0[67] = getAddress(sourceChain, "deUSD");
        token0[68] = getAddress(sourceChain, "sdeUSD");
        token0[69] = getAddress(sourceChain, "sdeUSD");
        token0[70] = getAddress(sourceChain, "WETH");
        token0[71] = getAddress(sourceChain, "WETH");
        token0[72] = getAddress(sourceChain, "USDE");
        token0[73] = getAddress(sourceChain, "SUSDE");
        token0[74] = getAddress(sourceChain, "WSTETH");
        token0[75] = getAddress(sourceChain, "WSTETH");
        token0[76] = getAddress(sourceChain, "WSTETH");
        token0[77] = getAddress(sourceChain, "WSTETH");

        address[] memory token1 = new address[](78);
        token1[0] = getAddress(sourceChain, "DAI");
        token1[1] = getAddress(sourceChain, "USDT");
        token1[2] = getAddress(sourceChain, "USDS");
        token1[3] = getAddress(sourceChain, "sUSDs");
        token1[4] = getAddress(sourceChain, "USD0");
        token1[5] = getAddress(sourceChain, "USD0_plus");
        token1[6] = getAddress(sourceChain, "deUSD");
        token1[7] = getAddress(sourceChain, "sdeUSD");
        token1[8] = getAddress(sourceChain, "WETH");
        token1[9] = getAddress(sourceChain, "WEETH");
        token1[10] = getAddress(sourceChain, "USDE");
        token1[11] = getAddress(sourceChain, "SUSDE");
        token1[12] = getAddress(sourceChain, "WSTETH");
        token1[13] = getAddress(sourceChain, "USDT");
        token1[14] = getAddress(sourceChain, "USDS");
        token1[15] = getAddress(sourceChain, "sUSDs");
        token1[16] = getAddress(sourceChain, "USD0");
        token1[17] = getAddress(sourceChain, "USD0_plus");
        token1[18] = getAddress(sourceChain, "deUSD");
        token1[19] = getAddress(sourceChain, "sdeUSD");
        token1[20] = getAddress(sourceChain, "WETH");
        token1[21] = getAddress(sourceChain, "WEETH");
        token1[22] = getAddress(sourceChain, "USDE");
        token1[23] = getAddress(sourceChain, "SUSDE");
        token1[24] = getAddress(sourceChain, "WSTETH");
        token1[25] = getAddress(sourceChain, "USDS");
        token1[26] = getAddress(sourceChain, "sUSDs");
        token1[27] = getAddress(sourceChain, "USD0");
        token1[28] = getAddress(sourceChain, "USD0_plus");
        token1[29] = getAddress(sourceChain, "deUSD");
        token1[30] = getAddress(sourceChain, "sdeUSD");
        token1[31] = getAddress(sourceChain, "WETH");
        token1[32] = getAddress(sourceChain, "WEETH");
        token1[33] = getAddress(sourceChain, "USDE");
        token1[34] = getAddress(sourceChain, "SUSDE");
        token1[35] = getAddress(sourceChain, "WSTETH");
        token1[36] = getAddress(sourceChain, "sUSDs");
        token1[37] = getAddress(sourceChain, "USD0");
        token1[38] = getAddress(sourceChain, "USD0_plus");
        token1[39] = getAddress(sourceChain, "deUSD");
        token1[40] = getAddress(sourceChain, "sdeUSD");
        token1[41] = getAddress(sourceChain, "WETH");
        token1[42] = getAddress(sourceChain, "WEETH");
        token1[43] = getAddress(sourceChain, "USDE");
        token1[44] = getAddress(sourceChain, "SUSDE");
        token1[45] = getAddress(sourceChain, "USD0");
        token1[46] = getAddress(sourceChain, "USD0_plus");
        token1[47] = getAddress(sourceChain, "deUSD");
        token1[48] = getAddress(sourceChain, "sdeUSD");
        token1[49] = getAddress(sourceChain, "WETH");
        token1[50] = getAddress(sourceChain, "WEETH");
        token1[51] = getAddress(sourceChain, "USDE");
        token1[52] = getAddress(sourceChain, "SUSDE");
        token1[53] = getAddress(sourceChain, "USD0_plus");
        token1[54] = getAddress(sourceChain, "deUSD");
        token1[55] = getAddress(sourceChain, "sdeUSD");
        token1[56] = getAddress(sourceChain, "WETH");
        token1[57] = getAddress(sourceChain, "WEETH");
        token1[58] = getAddress(sourceChain, "USDE");
        token1[59] = getAddress(sourceChain, "deUSD");
        token1[60] = getAddress(sourceChain, "sdeUSD");
        token1[61] = getAddress(sourceChain, "WETH");
        token1[62] = getAddress(sourceChain, "WEETH");
        token1[63] = getAddress(sourceChain, "USDE");
        token1[64] = getAddress(sourceChain, "sdeUSD");
        token1[65] = getAddress(sourceChain, "WETH");
        token1[66] = getAddress(sourceChain, "WEETH");
        token1[67] = getAddress(sourceChain, "USDE");
        token1[68] = getAddress(sourceChain, "WEETH");
        token1[69] = getAddress(sourceChain, "USDE");
        token1[70] = getAddress(sourceChain, "WEETH");
        token1[71] = getAddress(sourceChain, "USDC");
        token1[72] = getAddress(sourceChain, "USDC");
        token1[73] = getAddress(sourceChain, "USDC");
        token1[74] = getAddress(sourceChain, "USDC");
        token1[75] = getAddress(sourceChain, "DAI");
        token1[76] = getAddress(sourceChain, "USDT");
        token1[77] = getAddress(sourceChain, "WETH");

        _addUniswapV3Leafs(leafs, token0, token1, true);

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

        // ========================== Aave V3 ==========================
        supplyAssets = new ERC20[](5);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "DAI");
        supplyAssets[3] = getERC20(sourceChain, "WEETH");
        supplyAssets[4] = getERC20(sourceChain, "WSTETH");
        borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "DAI");
        borrowAssets[3] = getERC20(sourceChain, "WETH");
        borrowAssets[4] = getERC20(sourceChain, "WSTETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SparkLend ==========================
        supplyAssets = new ERC20[](7);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "DAI");
        supplyAssets[3] = getERC20(sourceChain, "sUSDs");
        supplyAssets[4] = getERC20(sourceChain, "WETH");
        supplyAssets[5] = getERC20(sourceChain, "WSTETH");
        supplyAssets[6] = getERC20(sourceChain, "WEETH");
        borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        borrowAssets[2] = getERC20(sourceChain, "DAI");
        borrowAssets[3] = getERC20(sourceChain, "WETH");
        borrowAssets[4] = getERC20(sourceChain, "WSTETH");

        _addSparkLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));

        // ========================== Usual ==========================
        _addUsualMoneyLeafs(leafs);

        // ========================== Elixir ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sdeUSD")));

        // ========================== Elixir Withdraws ==========================
        _addElixirSdeUSDWithdrawLeafs(leafs);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_sUSDe_03_26_25"), true);

        // ========================== 1inch ==========================
        /*
         *
         */
        assets = new address[](15);
        kind = new SwapKind[](15);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "DAI");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "USDS");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "PENDLE");
        kind[4] = SwapKind.Sell;
        assets[5] = getAddress(sourceChain, "deUSD");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "sdeUSD");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "USDS");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "sUSDs");
        kind[8] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "USD0");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "USD0_plus");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "WETH");
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = getAddress(sourceChain, "WEETH");
        kind[11] = SwapKind.BuyAndSell;
        assets[12] = getAddress(sourceChain, "USDE");
        kind[12] = SwapKind.BuyAndSell;
        assets[13] = getAddress(sourceChain, "SUSDE");
        kind[13] = SwapKind.BuyAndSell;
        assets[14] = getAddress(sourceChain, "WSTETH");
        kind[14] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

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

        // ========================== UniswapV3 ==========================
        token0 = new address[](78);
        token0[0] = getAddress(sourceChain, "USDC");
        token0[1] = getAddress(sourceChain, "USDC");
        token0[2] = getAddress(sourceChain, "USDC");
        token0[3] = getAddress(sourceChain, "USDC");
        token0[4] = getAddress(sourceChain, "USDC");
        token0[5] = getAddress(sourceChain, "USDC");
        token0[6] = getAddress(sourceChain, "USDC");
        token0[7] = getAddress(sourceChain, "USDC");
        token0[8] = getAddress(sourceChain, "USDC");
        token0[9] = getAddress(sourceChain, "USDC");
        token0[10] = getAddress(sourceChain, "USDC");
        token0[11] = getAddress(sourceChain, "USDC");
        token0[12] = getAddress(sourceChain, "USDC");
        token0[13] = getAddress(sourceChain, "DAI");
        token0[14] = getAddress(sourceChain, "DAI");
        token0[15] = getAddress(sourceChain, "DAI");
        token0[16] = getAddress(sourceChain, "DAI");
        token0[17] = getAddress(sourceChain, "DAI");
        token0[18] = getAddress(sourceChain, "DAI");
        token0[19] = getAddress(sourceChain, "DAI");
        token0[20] = getAddress(sourceChain, "DAI");
        token0[21] = getAddress(sourceChain, "DAI");
        token0[22] = getAddress(sourceChain, "DAI");
        token0[23] = getAddress(sourceChain, "DAI");
        token0[24] = getAddress(sourceChain, "DAI");
        token0[25] = getAddress(sourceChain, "USDT");
        token0[26] = getAddress(sourceChain, "USDT");
        token0[27] = getAddress(sourceChain, "USDT");
        token0[28] = getAddress(sourceChain, "USDT");
        token0[29] = getAddress(sourceChain, "USDT");
        token0[30] = getAddress(sourceChain, "USDT");
        token0[31] = getAddress(sourceChain, "USDT");
        token0[32] = getAddress(sourceChain, "USDT");
        token0[33] = getAddress(sourceChain, "USDT");
        token0[34] = getAddress(sourceChain, "USDT");
        token0[35] = getAddress(sourceChain, "USDT");
        token0[36] = getAddress(sourceChain, "USDS");
        token0[37] = getAddress(sourceChain, "USDS");
        token0[38] = getAddress(sourceChain, "USDS");
        token0[39] = getAddress(sourceChain, "USDS");
        token0[40] = getAddress(sourceChain, "USDS");
        token0[41] = getAddress(sourceChain, "USDS");
        token0[42] = getAddress(sourceChain, "USDS");
        token0[43] = getAddress(sourceChain, "USDS");
        token0[44] = getAddress(sourceChain, "USDS");
        token0[45] = getAddress(sourceChain, "sUSDs");
        token0[46] = getAddress(sourceChain, "sUSDs");
        token0[47] = getAddress(sourceChain, "sUSDs");
        token0[48] = getAddress(sourceChain, "sUSDs");
        token0[49] = getAddress(sourceChain, "sUSDs");
        token0[50] = getAddress(sourceChain, "sUSDs");
        token0[51] = getAddress(sourceChain, "sUSDs");
        token0[52] = getAddress(sourceChain, "sUSDs");
        token0[53] = getAddress(sourceChain, "USD0");
        token0[54] = getAddress(sourceChain, "USD0");
        token0[55] = getAddress(sourceChain, "USD0");
        token0[56] = getAddress(sourceChain, "USD0");
        token0[57] = getAddress(sourceChain, "USD0");
        token0[58] = getAddress(sourceChain, "USD0");
        token0[59] = getAddress(sourceChain, "USD0_plus");
        token0[60] = getAddress(sourceChain, "USD0_plus");
        token0[61] = getAddress(sourceChain, "USD0_plus");
        token0[62] = getAddress(sourceChain, "USD0_plus");
        token0[63] = getAddress(sourceChain, "USD0_plus");
        token0[64] = getAddress(sourceChain, "deUSD");
        token0[65] = getAddress(sourceChain, "deUSD");
        token0[66] = getAddress(sourceChain, "deUSD");
        token0[67] = getAddress(sourceChain, "deUSD");
        token0[68] = getAddress(sourceChain, "sdeUSD");
        token0[69] = getAddress(sourceChain, "sdeUSD");
        token0[70] = getAddress(sourceChain, "WETH");
        token0[71] = getAddress(sourceChain, "WETH");
        token0[72] = getAddress(sourceChain, "USDE");
        token0[73] = getAddress(sourceChain, "SUSDE");
        token0[74] = getAddress(sourceChain, "WSTETH");
        token0[75] = getAddress(sourceChain, "WSTETH");
        token0[76] = getAddress(sourceChain, "WSTETH");
        token0[77] = getAddress(sourceChain, "WSTETH");

        token1 = new address[](78);
        token1[0] = getAddress(sourceChain, "DAI");
        token1[1] = getAddress(sourceChain, "USDT");
        token1[2] = getAddress(sourceChain, "USDS");
        token1[3] = getAddress(sourceChain, "sUSDs");
        token1[4] = getAddress(sourceChain, "USD0");
        token1[5] = getAddress(sourceChain, "USD0_plus");
        token1[6] = getAddress(sourceChain, "deUSD");
        token1[7] = getAddress(sourceChain, "sdeUSD");
        token1[8] = getAddress(sourceChain, "WETH");
        token1[9] = getAddress(sourceChain, "WEETH");
        token1[10] = getAddress(sourceChain, "USDE");
        token1[11] = getAddress(sourceChain, "SUSDE");
        token1[12] = getAddress(sourceChain, "WSTETH");
        token1[13] = getAddress(sourceChain, "USDT");
        token1[14] = getAddress(sourceChain, "USDS");
        token1[15] = getAddress(sourceChain, "sUSDs");
        token1[16] = getAddress(sourceChain, "USD0");
        token1[17] = getAddress(sourceChain, "USD0_plus");
        token1[18] = getAddress(sourceChain, "deUSD");
        token1[19] = getAddress(sourceChain, "sdeUSD");
        token1[20] = getAddress(sourceChain, "WETH");
        token1[21] = getAddress(sourceChain, "WEETH");
        token1[22] = getAddress(sourceChain, "USDE");
        token1[23] = getAddress(sourceChain, "SUSDE");
        token1[24] = getAddress(sourceChain, "WSTETH");
        token1[25] = getAddress(sourceChain, "USDS");
        token1[26] = getAddress(sourceChain, "sUSDs");
        token1[27] = getAddress(sourceChain, "USD0");
        token1[28] = getAddress(sourceChain, "USD0_plus");
        token1[29] = getAddress(sourceChain, "deUSD");
        token1[30] = getAddress(sourceChain, "sdeUSD");
        token1[31] = getAddress(sourceChain, "WETH");
        token1[32] = getAddress(sourceChain, "WEETH");
        token1[33] = getAddress(sourceChain, "USDE");
        token1[34] = getAddress(sourceChain, "SUSDE");
        token1[35] = getAddress(sourceChain, "WSTETH");
        token1[36] = getAddress(sourceChain, "sUSDs");
        token1[37] = getAddress(sourceChain, "USD0");
        token1[38] = getAddress(sourceChain, "USD0_plus");
        token1[39] = getAddress(sourceChain, "deUSD");
        token1[40] = getAddress(sourceChain, "sdeUSD");
        token1[41] = getAddress(sourceChain, "WETH");
        token1[42] = getAddress(sourceChain, "WEETH");
        token1[43] = getAddress(sourceChain, "USDE");
        token1[44] = getAddress(sourceChain, "SUSDE");
        token1[45] = getAddress(sourceChain, "USD0");
        token1[46] = getAddress(sourceChain, "USD0_plus");
        token1[47] = getAddress(sourceChain, "deUSD");
        token1[48] = getAddress(sourceChain, "sdeUSD");
        token1[49] = getAddress(sourceChain, "WETH");
        token1[50] = getAddress(sourceChain, "WEETH");
        token1[51] = getAddress(sourceChain, "USDE");
        token1[52] = getAddress(sourceChain, "SUSDE");
        token1[53] = getAddress(sourceChain, "USD0_plus");
        token1[54] = getAddress(sourceChain, "deUSD");
        token1[55] = getAddress(sourceChain, "sdeUSD");
        token1[56] = getAddress(sourceChain, "WETH");
        token1[57] = getAddress(sourceChain, "WEETH");
        token1[58] = getAddress(sourceChain, "USDE");
        token1[59] = getAddress(sourceChain, "deUSD");
        token1[60] = getAddress(sourceChain, "sdeUSD");
        token1[61] = getAddress(sourceChain, "WETH");
        token1[62] = getAddress(sourceChain, "WEETH");
        token1[63] = getAddress(sourceChain, "USDE");
        token1[64] = getAddress(sourceChain, "sdeUSD");
        token1[65] = getAddress(sourceChain, "WETH");
        token1[66] = getAddress(sourceChain, "WEETH");
        token1[67] = getAddress(sourceChain, "USDE");
        token1[68] = getAddress(sourceChain, "WEETH");
        token1[69] = getAddress(sourceChain, "USDE");
        token1[70] = getAddress(sourceChain, "WEETH");
        token1[71] = getAddress(sourceChain, "USDC");
        token1[72] = getAddress(sourceChain, "USDC");
        token1[73] = getAddress(sourceChain, "USDC");
        token1[74] = getAddress(sourceChain, "USDC");
        token1[75] = getAddress(sourceChain, "DAI");
        token1[76] = getAddress(sourceChain, "USDT");
        token1[77] = getAddress(sourceChain, "WETH");

        _addUniswapV3Leafs(leafs, token0, token1, true);

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
