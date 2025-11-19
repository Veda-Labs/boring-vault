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

contract CreateLiquidETHOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x6727a35867EDCdDE01B92F5104D09D4561A4C2D9;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public drone = 0x7c391d7856fcbC4Fd3a3C3CD8787c7eBF85934aF;

    function setUp() external {}

    function run() external {
        generateLiquidEthOperationalStrategistMerkleRoot();
    }

    function generateLiquidEthOperationalStrategistMerkleRoot() public {

        setSourceChainName(plasma);
        setAddress(false, plasma, "boringVault", boringVault);
        setAddress(false, plasma, "managerAddress", managerAddress);
        setAddress(false, plasma, "accountantAddress", accountantAddress);
        setAddress(false, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        leafIndex = 0;

        // ====================== UniswapV3/OKU ==========================
        {
            address[] memory token0 = new address[](2);
            token0[0] = getAddress(sourceChain, "wXPL");
            token0[1] = getAddress(sourceChain, "USDT0");
            address[] memory token1 = new address[](2);
            token1[0] = getAddress(sourceChain, "USDT0");
            token1[1] = getAddress(sourceChain, "WETH");

            bool swapRouter02 = true;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== LayerZero ==========================
        {
            _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT0"), getAddress(sourceChain, "USDT0_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
            _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
            _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WETH"), getAddress(sourceChain, "WETH_OFT_STARGATE"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        }

        // ========================== Merkl ==========================
        {
            _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));
        }

        // ========================== Drone ==========================
        {
            ERC20[] memory droneTransferTokens = new ERC20[](1);
            droneTransferTokens[0] = getERC20(sourceChain, "wXPL"); 

            _addLeafsForDroneTransfers(leafs, drone, droneTransferTokens);
            _addLeafsForDrone(leafs, drone);
        }

        // ========================== Finalize ===================================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Plasma/LiquidETHOperationalStrategistLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs, address _drone) internal {
        setAddress(true, plasma, "boringVault", _drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ====================== UniswapV3/OKU ==========================
        {
            address[] memory token0 = new address[](2);
            token0[0] = getAddress(sourceChain, "wXPL");
            token0[1] = getAddress(sourceChain, "USDT0");
            address[] memory token1 = new address[](2);
            token1[0] = getAddress(sourceChain, "USDT0");
            token1[1] = getAddress(sourceChain, "WETH");

            bool swapRouter02 = true;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== Merkl ==========================
        {
            _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));
        }

        _createDroneLeafs(leafs, _drone, droneStartIndex, leafIndex + 1);
        setAddress(true, plasma, "boringVault", boringVault);
    }
}
