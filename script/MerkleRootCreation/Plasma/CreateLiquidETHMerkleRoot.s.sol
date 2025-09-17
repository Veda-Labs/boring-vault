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
 *  source .env && forge script script/MerkleRootCreation/Plasma/CreatePlasmaUSDMerkleRoot.s.sol --rpc-url $PLASMA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreatePlasmaUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0xfe47B4A709Ca3a91C3B8B97c058A6d07Cd84417F;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public drone = 0x7c391d7856fcbC4Fd3a3C3CD8787c7eBF85934aF;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "USDE");
        supplyAssets[1] = getERC20(sourceChain, "SUSDE");
        supplyAssets[2] = getERC20(sourceChain, "WEETH");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDT0");
        borrowAssets[1] = getERC20(sourceChain, "WETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== LayerZero ========================== VERIFY OFTS!!!
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT0"), getAddress(sourceChain, "USDT0_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "SUSDE"), getAddress(sourceChain, "SUSDE"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDE"), getAddress(sourceChain, "USDE"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WETH"), getAddress(sourceChain, "WETH_OFT_STARGATE"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "USDE");
        token0[1] = getAddress(sourceChain, "SUSDE");
        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "USDT0");
        token1[1] = getAddress(sourceChain, "USDT0");
        _addUniswapV3Leafs(leafs, token0, token1, true, true);

        // ========================== Fluid ==========================
        // NEED INFO
        ERC20[] memory supplyTokens = new ERC20[](2);
        supplyTokens[0] = getERC20(sourceChain, "WEETH");
        supplyTokens[1] = getERC20(sourceChain, "WETH");

        ERC20[] memory borrowTokens = new ERC20[](2);
        borrowTokens[0] = getERC20(sourceChain, "WEETH");
        borrowTokens[1] = getERC20(sourceChain, "WETH");
        _addFluidDexLeafs(leafs, dex, dexType, supplyTokens, borrowTokens, false);

        // ========================== Native ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "wXPL"));

        // DRONE LEAFSSS
        // ========================== Drone Setup ===============================
        {
            ERC20[] memory localTokens = new ERC20[](5);   
            localTokens[0] = getERC20(sourceChain, "USDE"); 
            localTokens[1] = getERC20(sourceChain, "WEETH");
            localTokens[2] = getERC20(sourceChain, "SUSDE");
            localTokens[3] = getERC20(sourceChain, "USDT0");
            localTokens[4] = getERC20(sourceChain, "WETH");

            _addLeafsForDroneTransfers(leafs, drone, localTokens);
            _addLeafsForDrone(leafs);
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Plasma/PlasmaUSDMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs) internal {
        setAddress(true, mainnet, "boringVault", drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "USDE");
        supplyAssets[1] = getERC20(sourceChain, "SUSDE");
        supplyAssets[2] = getERC20(sourceChain, "WEETH");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDT0");
        borrowAssets[1] = getERC20(sourceChain, "WETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "USDE");
        token0[1] = getAddress(sourceChain, "SUSDE");
        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "USDT0");
        token1[1] = getAddress(sourceChain, "USDT0");
        _addUniswapV3Leafs(leafs, token0, token1, true, true);

        // ========================== Fluid ==========================
        // NEED INFO
        ERC20[] memory supplyTokens = new ERC20[](2);
        supplyTokens[0] = getERC20(sourceChain, "WEETH");
        supplyTokens[1] = getERC20(sourceChain, "WETH");

        ERC20[] memory borrowTokens = new ERC20[](2);
        borrowTokens[0] = getERC20(sourceChain, "WEETH");
        borrowTokens[1] = getERC20(sourceChain, "WETH");
        _addFluidDexLeafs(leafs, dex, dexType, supplyTokens, borrowTokens, false);

        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }
}
