// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/HyperEVM/CreateKHypeMerkleRoot.s.sol --rpc-url $HYPER_EVM_RPC_URL
 */
contract CreateKHypeMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x9BA2EDc44E0A4632EB4723E81d4142353e1bB160;
    address public rawDataDecoderAndSanitizer = 0x8beBEcEad5206DF4fCa68b96af08dB7215B1F39e;
    address public managerAddress = 0x7f8CcAA760E0F621c7245d47DC46d40A400d3639;
    address public accountantAddress = 0x74392Fa56405081d5C7D93882856c245387Cece2;

    function setUp() external {} /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(hyperEVM);
        setAddress(false, hyperEVM, "boringVault", boringVault);
        setAddress(false, hyperEVM, "managerAddress", managerAddress);
        setAddress(false, hyperEVM, "accountantAddress", accountantAddress);
        setAddress(false, hyperEVM, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Ooga Booga ==========================
        address[] memory assets = new address[](5);
        SwapKind[] memory kind = new SwapKind[](5);
        assets[0] = getAddress(sourceChain, "KHYPE");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WHYPE");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "PENDLE");
        kind[2] = SwapKind.Sell;
        assets[3] = getAddress(sourceChain, "USDT");
        kind[3] = SwapKind.Sell;
        assets[4] = getAddress(sourceChain, "USDC");
        kind[4] = SwapKind.Sell;

        _addOogaBoogaSwapLeafs(leafs, assets, kind);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "KHYPE");
        feeAssets[1] = getERC20(sourceChain, "WHYPE");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== AaveV3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "KHYPE");
        supplyAssets[1] = getERC20(sourceChain, "WHYPE");
        supplyAssets[2] = getERC20(sourceChain, "pendle_kHYPE_pt_11_13_25");
        supplyAssets[3] = getERC20(sourceChain, "pendle_kHYPE_pt_3_19_26");
        ERC20[] memory borrowAssets = new ERC20[](4);
        borrowAssets[0] = getERC20(sourceChain, "KHYPE");
        borrowAssets[1] = getERC20(sourceChain, "WHYPE");
        borrowAssets[2] = getERC20(sourceChain, "pendle_kHYPE_pt_11_13_25");
        borrowAssets[3] = getERC20(sourceChain, "pendle_kHYPE_pt_3_19_26");
        _addHyperLendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== Morpho Blue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "KHYPE_WHYPE_915")); 

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "KHYPE_WHYPE_915")); 

        // ========================== MetaMorhpo ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "feHYPE")));  

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "KHYPE_WHYPE_Curve_Pool"),
            2,
            address(0) //no gauge
        );

        // ========================== KHYPE ==========================
        _addKHypeLeafs(leafs); 

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "kHypePendle"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_kHYPE_market_3_19_26"), true);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WHYPE"));

        // ========================== Valantis ==========================
        _addValantisLSTLeafs(leafs, getAddress(sourceChain, "KHYPE_WHYPE_sovereign_pool"), false); 

        // ========================== UniswapV3/Project X ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "KHYPE");
        token0[1] = getAddress(sourceChain, "USDT");
        token0[2] = getAddress(sourceChain, "USDC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "WHYPE");
        token1[1] = getAddress(sourceChain, "WHYPE");
        token1[2] = getAddress(sourceChain, "WHYPE");
        
        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== Layer Zero / Stargate ==========================
        // Bridge PENDLE to Mainnet
        _addLayerZeroLeafs({
            leafs: leafs,
            asset: getERC20(sourceChain, "PENDLE"),
            oftAdapter: getAddress(sourceChain, "PENDLE"),
            endpoint: layerZeroMainnetEndpointId,
            to: getBytes32(sourceChain, "boringVault") //@todo Assumes the same boring vault for both chains
        });

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/HyperEVM/KHypeStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
