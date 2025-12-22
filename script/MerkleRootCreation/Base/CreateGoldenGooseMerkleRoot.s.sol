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
 *  source .env && forge script script/MerkleRootCreation/Base/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $BASE_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // Base Golden Goose deployment addresses
    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0xE2Fc8A38FA3B9a57E538fBed7101D0E059F82D7B;
    address public goldenGooseTeller = 0xE89fAaf3968ACa5dCB054D4a9287E54aa84F67e9;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        // Force Base fork
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        setSourceChainName(base);
        setAddress(false, base, "boringVault", boringVault);
        setAddress(false, base, "managerAddress", managerAddress);
        setAddress(false, base, "accountantAddress", accountantAddress);
        setAddress(false, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, base, "goldenGooseTeller", goldenGooseTeller);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Native Bridge (Superbridge) ==========================
        // Bridge ETH and wstETH between Mainnet and Base
        {
            ERC20[] memory localTokens = new ERC20[](0);
            ERC20[] memory remoteTokens = new ERC20[](0);

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

            _addLidoStandardBridgeLeafs(
                leafs, mainnet, address(0), address(0), getAddress(sourceChain, "l2ERC20TokenBridge"), address(0)
            );
        }

        // ========================== Layer Zero / Stargate ==========================
        // Bridge weETH between Base and Mainnet
        {
            // weETH bridging via LayerZero
            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "weETH"),
                getAddress(sourceChain, "weETH"),
                layerZeroMainnetEndpointId,
                getBytes32(sourceChain, "boringVault")
            );
        }

        // ========================== Balancer V3 ==========================
        // wstETH/WETH LP on Base
        address balancerV3Pool = getAddress(sourceChain, "wstETH-fWETH-pool");
        _addBalancerV3Leafs(
            leafs,
            balancerV3Pool,
            true,
            getAddress(sourceChain, "wstETH-fWETH-pool-guage") // buffer address if needed
        );

        // ========================== Aave V3 ==========================
        {
            // Supply assets
            ERC20[] memory supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "WSTETH");
            supplyAssets[1] = getERC20(sourceChain, "weETH");

            // Borrow assets
            ERC20[] memory borrowAssets = new ERC20[](2);
            borrowAssets[0] = getERC20(sourceChain, "WETH");
            borrowAssets[1] = getERC20(sourceChain, "WSTETH");

            _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
        }

        // ========================== Aerodrome (Velodrome V3 Fork) ==========================
        // wstETH/WETH LP on Aerodrome
        {
            address[] memory token0 = new address[](1);
            token0[0] = getAddress(sourceChain, "WSTETH");

            address[] memory token1 = new address[](1);
            token1[0] = getAddress(sourceChain, "WETH");

            // Aerodrome gauge for wstETH/WETH pool
            address[] memory gauges = new address[](1);
            gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Wsteth_v3_1_gauge");

            // Aerodrome uses same interface as Velodrome V3
            _addVelodromeV3Leafs(
                leafs, token0, token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
            );
        }

        // ========================== Odos ==========================
        {
            address[] memory assets = new address[](3);
            SwapKind[] memory kind = new SwapKind[](3);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "AERO");
            kind[2] = SwapKind.Sell;

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
            assets[2] = getAddress(sourceChain, "AERO");
            kind[2] = SwapKind.Sell;

            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        }

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Base/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
