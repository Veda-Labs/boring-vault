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
 *  source .env && forge script script/MerkleRootCreation/Plasma/CreateLiquidETHMerkleRoot.s.sol --rpc-url $PLASMA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateLiquidETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x6727a35867EDCdDE01B92F5104D09D4561A4C2D9;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public drone = 0x7c391d7856fcbC4Fd3a3C3CD8787c7eBF85934aF;

    address public fluidT1DecoderAndSanitizer = 0xa4561A172D998561b22b574f291bF4E2d5C60aA3;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(plasma);
        setAddress(false, plasma, "boringVault", boringVault);
        setAddress(false, plasma, "managerAddress", managerAddress);
        setAddress(false, plasma, "accountantAddress", accountantAddress);
        setAddress(false, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](5);
        supplyAssets[0] = getERC20(sourceChain, "USDE");
        supplyAssets[1] = getERC20(sourceChain, "SUSDE");
        supplyAssets[2] = getERC20(sourceChain, "WEETH");
        supplyAssets[3] = getERC20(sourceChain, "WETH");
        supplyAssets[4] = getERC20(sourceChain, "USDT0");
        ERC20[] memory borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "USDE");
        borrowAssets[1] = getERC20(sourceChain, "SUSDE");
        borrowAssets[2] = getERC20(sourceChain, "WEETH");
        borrowAssets[3] = getERC20(sourceChain, "WETH");
        borrowAssets[4] = getERC20(sourceChain, "USDT0");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT0"), getAddress(sourceChain, "USDT0_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "SUSDE"), getAddress(sourceChain, "SUSDE"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDE"), getAddress(sourceChain, "USDE"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WETH"), getAddress(sourceChain, "WETH_OFT_STARGATE"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "wstUSR"), getAddress(sourceChain, "wstUSR"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](4);
        token0[0] = getAddress(sourceChain, "USDE");
        token0[1] = getAddress(sourceChain, "SUSDE");
        token0[2] = getAddress(sourceChain, "wXPL");
        token0[3] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](4);
        token1[0] = getAddress(sourceChain, "USDT0");
        token1[1] = getAddress(sourceChain, "USDT0");
        token1[2] = getAddress(sourceChain, "USDT0");
        token1[3] = getAddress(sourceChain, "USDT0");
        _addUniswapV3Leafs(leafs, token0, token1, true, true);

        // ========================== Fluid ==========================
        {
            ERC20[] memory supplyTokens = new ERC20[](2);
            supplyTokens[0] = getERC20(sourceChain, "WEETH");
            supplyTokens[1] = getERC20(sourceChain, "WETH");

            ERC20[] memory borrowTokens = new ERC20[](2);
            borrowTokens[0] = getERC20(sourceChain, "WEETH");
            borrowTokens[1] = getERC20(sourceChain, "WETH");
            _addFluidDexLeafs(leafs, getAddress(sourceChain, "weETH_ETHDex_wETH"), 2000, supplyTokens, borrowTokens, false);
        }
        {
            // primary decoder does not have support for T1 fluid vaults so point leaves at a separate deployment
            setAddress(true, plasma, "rawDataDecoderAndSanitizer", fluidT1DecoderAndSanitizer);
            ERC20[] memory supplyTokens = new ERC20[](1);
            supplyTokens[0] = getERC20(sourceChain, "wstUSR");

            ERC20[] memory borrowTokens = new ERC20[](1);
            borrowTokens[0] = getERC20(sourceChain, "USDT0");
            _addFluidDexLeafs(leafs, getAddress(sourceChain, "Vaultt1_Wstusr_Usdt0"), 1000, supplyTokens, borrowTokens, false);
            setAddress(true, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Native ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "wXPL"));

        // ========================== Merkl ==========================
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address")
        );

        // DRONE LEAFS
        // ========================== Drone Setup ===============================
        {
            ERC20[] memory localTokens = new ERC20[](6);   
            localTokens[0] = getERC20(sourceChain, "USDE"); 
            localTokens[1] = getERC20(sourceChain, "WEETH");
            localTokens[2] = getERC20(sourceChain, "SUSDE");
            localTokens[3] = getERC20(sourceChain, "USDT0");
            localTokens[4] = getERC20(sourceChain, "WETH");
            localTokens[5] = getERC20(sourceChain, "wXPL");

            _addLeafsForDroneTransfers(leafs, drone, localTokens);
            _addLeafsForDrone(leafs);
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Plasma/LiquidETHMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs) internal {
        setAddress(true, plasma, "boringVault", drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](5);
        supplyAssets[0] = getERC20(sourceChain, "USDE");
        supplyAssets[1] = getERC20(sourceChain, "SUSDE");
        supplyAssets[2] = getERC20(sourceChain, "WEETH");
        supplyAssets[3] = getERC20(sourceChain, "WETH");
        supplyAssets[4] = getERC20(sourceChain, "USDT0");
        ERC20[] memory borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "USDE");
        borrowAssets[1] = getERC20(sourceChain, "SUSDE");
        borrowAssets[2] = getERC20(sourceChain, "WEETH");
        borrowAssets[3] = getERC20(sourceChain, "WETH");
        borrowAssets[4] = getERC20(sourceChain, "USDT0");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](4);
        token0[0] = getAddress(sourceChain, "USDE");
        token0[1] = getAddress(sourceChain, "SUSDE");
        token0[2] = getAddress(sourceChain, "wXPL");
        token0[3] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](4);
        token1[0] = getAddress(sourceChain, "USDT0");
        token1[1] = getAddress(sourceChain, "USDT0");
        token1[2] = getAddress(sourceChain, "USDT0");
        token1[3] = getAddress(sourceChain, "USDT0");
        _addUniswapV3Leafs(leafs, token0, token1, true, true);

        // ========================== Fluid ==========================
        ERC20[] memory supplyTokens = new ERC20[](2);
        supplyTokens[0] = getERC20(sourceChain, "WEETH");
        supplyTokens[1] = getERC20(sourceChain, "WETH");

        ERC20[] memory borrowTokens = new ERC20[](2);
        borrowTokens[0] = getERC20(sourceChain, "WEETH");
        borrowTokens[1] = getERC20(sourceChain, "WETH");
        _addFluidDexLeafs(leafs, getAddress(sourceChain, "weETH_ETHDex_wETH"), 2000, supplyTokens, borrowTokens, false);

        // ========================== Merkl ==========================
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address")
        );

        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, plasma, "boringVault", boringVault);
    }
}
