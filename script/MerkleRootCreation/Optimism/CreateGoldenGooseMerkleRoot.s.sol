// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Optimism/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $OPTIMISM_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0xCa82ADD835880df591913c42EE946E2c214d23c5;
    address public goldenGooseTeller = 0xE89fAaf3968ACa5dCB054D4a9287E54aa84F67e9;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        // Force Optimism fork
        vm.createSelectFork(vm.envString("OPTIMISM_RPC_URL"));

        setSourceChainName(optimism);
        setAddress(false, optimism, "boringVault", boringVault);
        setAddress(false, optimism, "managerAddress", managerAddress);
        setAddress(false, optimism, "accountantAddress", accountantAddress);
        setAddress(false, optimism, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, optimism, "goldenGooseTeller", goldenGooseTeller);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);
        
        // ========================== Standard Bridge ==========================
        // Bridge WETH and wstETH between Mainnet and Optimism
        {
            ERC20[] memory localTokens = new ERC20[](2);
            ERC20[] memory remoteTokens = new ERC20[](2);
            
            // WETH bridging
            localTokens[0] = getERC20(sourceChain, "WETH");
            remoteTokens[0] = getERC20(mainnet, "WETH");
            
            // wstETH bridging
            localTokens[1] = getERC20(sourceChain, "WSTETH");
            remoteTokens[1] = getERC20(mainnet, "WSTETH");
            
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
            
            // Add Lido-specific standard bridge support for wstETH
            _addLidoStandardBridgeLeafs(
                leafs,
                mainnet,
                address(0),
                address(0),
                getAddress(sourceChain, "standardBridge"),
                address(0)
            );
        }

        // ========================== Aave V3 ==========================
        {
            // Supply assets
            ERC20[] memory supplyAssets = new ERC20[](1);
            supplyAssets[0] = getERC20(sourceChain, "WSTETH");
            
            // Borrow assets
            ERC20[] memory borrowAssets = new ERC20[](1);
            borrowAssets[0] = getERC20(sourceChain, "WETH");
            
            _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
        }

        // ========================== Velodrome ==========================
        // wstETH/WETH LP on Velodrome
        {
            address[] memory token0 = new address[](1);
            address[] memory token1 = new address[](1);
            token0[0] = getAddress(sourceChain, "WSTETH");
            token1[0] = getAddress(sourceChain, "WETH");
            
            // Add gauge for staking positions
            address[] memory gauges = new address[](1);
            gauges[0] = getAddress(sourceChain, "velodrome_Weth_Wsteth_v3_1_gauge");
            
            // Add Velodrome V3 support
            _addVelodromeV3Leafs(
                leafs,
                token0,
                token1,
                getAddress(sourceChain, "velodromeNonFungiblePositionManager"),
                gauges
            );
        }

        // ========================== Odos ==========================
        {
            address[] memory assets = new address[](2);
            SwapKind[] memory kind = new SwapKind[](2);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;

            _addOdosSwapLeafs(leafs, assets, kind);
        }

        // ========================== 1Inch ==========================
        {
            address[] memory assets = new address[](2);
            SwapKind[] memory kind = new SwapKind[](2);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;

            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        }

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Optimism/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}