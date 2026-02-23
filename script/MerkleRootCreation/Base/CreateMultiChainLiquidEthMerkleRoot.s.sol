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
 *  source .env && forge script script/MerkleRootCreation/Base/CreateMultiChainLiquidEthMerkleRoot.s.sol:CreateMultiChainLiquidEthMerkleRootScript --rpc-url $BASE_RPC_URL
 */
contract CreateMultiChainLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x5Fb5455dDa970adc53Ab6949FD318ff8aecf461e; 
    address public managerAddress = 0x227975088C28DBBb4b421c6d96781a53578f19a8;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;

    //one offs
    address public aerodromeDecoderAndSanitizer = 0xbBC56C19282BB3C115fE3B909edeA3dF5Cc296d5;

    address public odosOwnedDecoderAndSanitizer = 0x6149c711434C54A48D757078EfbE0E2B2FE2cF6a;
    address public oneInchOwnedDecoderAndSanitizer = 0x42842201E199E6328ADBB98e7C2CbE77561FAC88;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMultiChainLiquidEthStrategistMerkleRoot();
    }

    function generateMultiChainLiquidEthStrategistMerkleRoot() public {
        setSourceChainName(base);
        setAddress(false, base, "boringVault", boringVault);
        setAddress(false, base, "managerAddress", managerAddress);
        setAddress(false, base, "accountantAddress", accountantAddress);
        setAddress(false, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WEETH");
        supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        supplyAssets[3] = getERC20(sourceChain, "CBETH");
        ERC20[] memory borrowAssets = new ERC20[](4);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WEETH");
        borrowAssets[2] = getERC20(sourceChain, "WSTETH");
        borrowAssets[3] = getERC20(sourceChain, "CBETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== MorphoBlue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "weETH_wETH_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "wstETH_wETH_945"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "cbETH_wETH_965"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "cbETH_wETH_945"));

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "CBETH");

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== 1inch/Odos ==========================
        {
            address[] memory assets = new address[](11);
            SwapKind[] memory kind = new SwapKind[](11);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WEETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "WSTETH");
            kind[2] = SwapKind.BuyAndSell;
            assets[3] = getAddress(sourceChain, "CBETH");
            kind[3] = SwapKind.BuyAndSell;
            assets[4] = getAddress(sourceChain, "CRV");
            kind[4] = SwapKind.Sell;
            assets[5] = getAddress(sourceChain, "AURA");
            kind[5] = SwapKind.Sell;
            assets[6] = getAddress(sourceChain, "BAL");
            kind[6] = SwapKind.Sell;
            assets[7] = getAddress(sourceChain, "RETH");
            kind[7] = SwapKind.BuyAndSell;
            assets[8] = getAddress(sourceChain, "BSDETH");
            kind[8] = SwapKind.BuyAndSell;
            assets[9] = getAddress(sourceChain, "AERO");
            kind[9] = SwapKind.Sell;
            assets[10] = getAddress(sourceChain, "SFRXETH");
            kind[10] = SwapKind.BuyAndSell;
            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", oneInchOwnedDecoderAndSanitizer);
            _addLeafsFor1InchOwnedGeneralSwapping(leafs, assets, kind);

            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", odosOwnedDecoderAndSanitizer);
            _addOdosOwnedSwapLeafs(leafs, assets, kind);

            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Compound V3 ==========================
        ERC20[] memory collateralAssets = new ERC20[](1);
        collateralAssets[0] = getERC20(sourceChain, "CBETH");
        _addCompoundV3Leafs(
            leafs, collateralAssets, getAddress(sourceChain, "cWETHV3"), getAddress(sourceChain, "cometRewards")
        );

        // ========================== Fluid Dex ==========================
        {
            uint256 dexType = 2000; 
            ERC20[] memory supplyTokens = new ERC20[](2);    
            supplyTokens[0] = getERC20(sourceChain, "ETH"); 
            supplyTokens[1] = getERC20(sourceChain, "WEETH"); 

            ERC20[] memory borrowTokens = new ERC20[](1);    
            borrowTokens[0] = getERC20(sourceChain, "WSTETH"); 
            _addFluidDexLeafs(
                leafs,
                getAddress(sourceChain, "weETH_ETHDex_wstETH"),
                dexType,
                supplyTokens,
                borrowTokens,
                true //add native ETH leaves
            ); 
        }

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WEETH"));

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](2);
        localTokens[0] = getERC20(sourceChain, "RETH");
        localTokens[1] = getERC20(sourceChain, "CBETH");
        ERC20[] memory remoteTokens = new ERC20[](2);
        remoteTokens[0] = getERC20(mainnet, "RETH");
        remoteTokens[1] = getERC20(mainnet, "CBETH");
        _addStandardBridgeLeafs(
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0),
            localTokens,
            remoteTokens
        );

        // ========================== Merkl ==========================
        _addMerklLeafs(
            leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address")
        );

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroOptimismEndpointId, getBytes32(sourceChain, "boringVault")
        );

        // ========================== Lido Standard Bridge ==========================
        _addLidoStandardBridgeLeafs(
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "l2ERC20TokenBridge"),
            address(0)
        );


        // ========================== Aerodrome ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", aerodromeDecoderAndSanitizer);
        token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "WSTETH");
        token1[1] = getAddress(sourceChain, "CBETH");
        token1[2] = getAddress(sourceChain, "BSDETH");
        address[] memory gauges = new address[](3);
        gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v3_1_gauge");
        gauges[1] = getAddress(sourceChain, "aerodrome_Cbeth_Weth_v3_1_gauge");
        gauges[2] = getAddress(sourceChain, "aerodrome_Weth_Bsdeth_v3_1_gauge");
        _addVelodromeV3Leafs(
            leafs, token0, token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
        );

        token0 = new address[](4);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WEETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token0[3] = getAddress(sourceChain, "SFRXETH");
        token1 = new address[](4);
        token1[0] = getAddress(sourceChain, "WSTETH");
        token1[1] = getAddress(sourceChain, "WETH");
        token1[2] = getAddress(sourceChain, "RETH");
        token1[3] = getAddress(sourceChain, "WSTETH");
        gauges = new address[](4);
        gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v2_30_gauge");
        gauges[1] = getAddress(sourceChain, "aerodrome_Weth_Weeth_v2_30_gauge");
        gauges[2] = getAddress(sourceChain, "aerodrome_Weth_Reth_v2_05_gauge");
        gauges[3] = getAddress(sourceChain, "aerodrome_Sfrxeth_Wsteth_v2_30_gauge");
        _addVelodromeV2Leafs(leafs, token0, token1, getAddress(sourceChain, "aerodromeRouter"), gauges);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/BaseMultiChainLiquidEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
