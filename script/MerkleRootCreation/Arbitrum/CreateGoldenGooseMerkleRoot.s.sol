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
 *  source .env && forge script script/MerkleRootCreation/Arbitrum/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $ARBITRUM_RPC_URL
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
        // Force arbitrum fork
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        setSourceChainName(arbitrum);
        setAddress(false, arbitrum, "boringVault", boringVault);
        setAddress(false, arbitrum, "managerAddress", managerAddress);
        setAddress(false, arbitrum, "accountantAddress", accountantAddress);
        setAddress(false, arbitrum, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, arbitrum, "goldenGooseTeller", goldenGooseTeller);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Arbitrum Native Bridge ==========================
        // Bridge WETH, wstETH, and weETH between Mainnet and Arbitrum
        {
            ERC20[] memory bridgeAssets = new ERC20[](3);

            // ETH bridging (using WETH)
            bridgeAssets[0] = getERC20(mainnet, "WETH");

            // wstETH bridging
            bridgeAssets[1] = getERC20(mainnet, "WSTETH");

            // weETH bridging via native bridge
            bridgeAssets[2] = getERC20(mainnet, "weETH");

            _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets);
        }

        // ========================== Balancer V3 ==========================
        // WETH/wstETH boosted (Aave/Fluid) pool
        // Pool address: 0xb1b8b406eeebbb636fdbb20e6732c117d828363c
        _addBalancerV3Leafs(
            leafs,
            0xB1B8B406EeeBBB636fdBB20E6732c117d828363C, // WETH/wstETH boosted pool
            true, // boosted pool
            0x1C81E457d435788C70B7BB71e1eE149f3C6710D3
        );

        // ========================== Balancer Flash Loans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WSTETH"));

        // ========================== Uniswap V3 ==========================
        // wstETH/WETH pair
        // Pool address: 0x35218a1cbaC5Bbc3E57fd9Bd38219D37571b3537
        {
            address[] memory token0 = new address[](1);
            token0[0] = getAddress(sourceChain, "WSTETH");

            address[] memory token1 = new address[](1);
            token1[0] = getAddress(sourceChain, "WETH");

            _addUniswapV3Leafs(leafs, token0, token1, false);
        }

        // ========================== Aave V3 ==========================
        {
            // Supply assets (removing Renzo and Kelp assets)
            ERC20[] memory supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "WSTETH");
            supplyAssets[1] = getERC20(sourceChain, "weETH");

            // Borrow assets
            ERC20[] memory borrowAssets = new ERC20[](2);
            borrowAssets[0] = getERC20(sourceChain, "WETH");
            borrowAssets[1] = getERC20(sourceChain, "WSTETH");

            _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
        }

        // ========================== Odos ==========================
        {
            address[] memory assets = new address[](3);
            SwapKind[] memory kind = new SwapKind[](3);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "weETH");
            kind[2] = SwapKind.BuyAndSell;

            _addOdosSwapLeafs(leafs, assets, kind);
        }

        // ========================== 1Inch ==========================
        {
            address[] memory assets = new address[](3);
            SwapKind[] memory kind = new SwapKind[](3);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "weETH");
            kind[2] = SwapKind.BuyAndSell;

            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        }

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Arbitrum/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
