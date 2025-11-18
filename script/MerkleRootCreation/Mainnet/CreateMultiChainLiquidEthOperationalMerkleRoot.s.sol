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

contract CreateMultichainLiquidEthOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x8fB043d30BAf4Eba2C8f7158aCBc07ec9A53Fe85;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public drone = 0x0a42b2F3a0D54157Dbd7CC346335A4F1909fc02c;

    address public kingClaimingDecoderAndSanitizer = 0xd4067b594C6D48990BE42a559C8CfDddad4e8D6F;

    function setUp() external {}

    function run() external {
        generateLiquidEthOperationalStrategistMerkleRoot();
    }

    function generateLiquidEthOperationalStrategistMerkleRoot() public {

        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);
        leafIndex = 0;

        // ========================== UniswapV3 ==========================
        {
            address[] memory token0 = new address[](6);
            token0[0] = getAddress(sourceChain, "RLUSD");
            token0[1] = getAddress(sourceChain, "RLUSD");
            token0[2] = getAddress(sourceChain, "USDC");
            token0[3] = getAddress(sourceChain, "EIGEN");
            token0[4] = getAddress(sourceChain, "rEUL");
            token0[5] = getAddress(sourceChain, "MNT");

            address[] memory token1 = new address[](6);
            token1[0] = getAddress(sourceChain, "USDC");
            token1[1] = getAddress(sourceChain, "WETH");
            token1[2] = getAddress(sourceChain, "WETH");
            token1[3] = getAddress(sourceChain, "WETH");
            token1[4] = getAddress(sourceChain, "WETH");
            token1[5] = getAddress(sourceChain, "WETH");

            bool swapRouter02 = false;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== Odos ==========================
        {
            address RLUSD = getAddress(sourceChain, "RLUSD");
            address USDC = getAddress(sourceChain, "USDC");
            address WETH = getAddress(sourceChain, "WETH");
            address EIGEN = getAddress(sourceChain, "EIGEN");
            address rEUL = getAddress(sourceChain, "rEUL");
            address MNT = getAddress(sourceChain, "MNT");

            _addOdosOneWaySwapLeafs(leafs, RLUSD, USDC);
            _addOdosOneWaySwapLeafs(leafs, RLUSD, WETH);
            _addOdosOneWaySwapLeafs(leafs, USDC, WETH);
            _addOdosOneWaySwapLeafs(leafs, EIGEN, WETH);
            _addOdosOneWaySwapLeafs(leafs, rEUL, WETH);
            _addOdosOneWaySwapLeafs(leafs, MNT, WETH);
        }

        // ========================== Merkl ==========================
        {
            _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));
        }


        // ========================== Drone ==========================
        {
            ERC20[] memory droneTransferTokens = new ERC20[](5);
            droneTransferTokens[0] = getERC20(sourceChain, "USDC"); 
            droneTransferTokens[1] = getERC20(sourceChain, "RLUSD");
            droneTransferTokens[2] = getERC20(sourceChain, "EIGEN");
            droneTransferTokens[3] = getERC20(sourceChain, "rEUL");
            droneTransferTokens[4] = getERC20(sourceChain, "MNT");

            _addLeafsForDroneTransfers(leafs, drone, droneTransferTokens);
            _addLeafsForDrone(leafs, drone);
        }

        // ==================== KING Claiming ========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", kingClaimingDecoderAndSanitizer);
        _addKingRewardsClaimingLeafs(leafs, new address[](0), getAddress(sourceChain, "boringVault"));
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== Finalize ===================================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Mainnet/MultiChainLiquidEthOperationalStrategistLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs, address _drone) internal {
        setAddress(true, mainnet, "boringVault", _drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](6);
        token0[0] = getAddress(sourceChain, "RLUSD");
        token0[1] = getAddress(sourceChain, "RLUSD");
        token0[2] = getAddress(sourceChain, "USDC");
        token0[3] = getAddress(sourceChain, "EIGEN");
        token0[4] = getAddress(sourceChain, "rEUL");
        token0[5] = getAddress(sourceChain, "MNT");

        address[] memory token1 = new address[](6);
        token1[0] = getAddress(sourceChain, "USDC");
        token1[1] = getAddress(sourceChain, "WETH");
        token1[2] = getAddress(sourceChain, "WETH");
        token1[3] = getAddress(sourceChain, "WETH");
        token1[4] = getAddress(sourceChain, "WETH");
        token1[5] = getAddress(sourceChain, "WETH");

        bool swapRouter02 = false;
        _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);

        // ========================== Odos ==========================
        {
            address RLUSD = getAddress(sourceChain, "RLUSD");
            address USDC = getAddress(sourceChain, "USDC");
            address WETH = getAddress(sourceChain, "WETH");
            address EIGEN = getAddress(sourceChain, "EIGEN");
            address rEUL = getAddress(sourceChain, "rEUL");
            address MNT = getAddress(sourceChain, "MNT");

            _addOdosOneWaySwapLeafs(leafs, RLUSD, USDC);
            _addOdosOneWaySwapLeafs(leafs, RLUSD, WETH);
            _addOdosOneWaySwapLeafs(leafs, USDC, WETH);
            _addOdosOneWaySwapLeafs(leafs, EIGEN, WETH);
            _addOdosOneWaySwapLeafs(leafs, rEUL, WETH);
            _addOdosOneWaySwapLeafs(leafs, MNT, WETH);
        }

        // ========================== Merkl ==========================
        {
            _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));
        }

        _createDroneLeafs(leafs, _drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }
}
