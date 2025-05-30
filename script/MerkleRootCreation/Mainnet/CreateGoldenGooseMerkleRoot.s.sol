// SPDX-License-Identifier: UNLICENSED
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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0x93DC12E1BCF087CcD35daCF22Fe7cf1Cd2e7EdEA; 

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        ERC20[] memory remoteTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "WETH");
        remoteTokens[0] = getERC20(unichain, "WETH");

        _addStandardBridgeLeafs(
            leafs,
            unichain,
            getAddress(unichain, "crossDomainMessenger"),
            getAddress(sourceChain, "unichainResolvedDelegate"),
            getAddress(sourceChain, "unichainStandardBridge"),
            getAddress(sourceChain, "unichainPortal"),
            localTokens,
            remoteTokens
        );

        _addLidoStandardBridgeLeafs(
            leafs,
            unichain,
            getAddress(unichain, "crossDomainMessenger"),
            getAddress(sourceChain, "unichainResolvedDelegate"),
            getAddress(sourceChain, "unichainStandardBridge"),
            getAddress(sourceChain, "unichainPortal")
        );

        // ========================== Merkl ==========================
        ERC20[] memory tokensToClaim = new ERC20[](1);
        tokensToClaim[0] = getERC20(sourceChain, "UNI");
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address"),
            tokensToClaim
        );

        // ========================== Uniswap V4 ==========================
        {
            address[] memory hooks = new address[](1);
            address[] memory token0 = new address[](1);
            address[] memory token1 = new address[](1);

            hooks[0] = address(0);
            token0[0] = address(0);
            token1[0] = getAddress(sourceChain, "WSTETH");

            _addUniswapV4Leafs(
                leafs,
                token0,
                token1,
                hooks
            );
        }

        // ========================== Uniswap V3 ==========================
        {
            // WETH, wstETH
            address[] memory token0 = new address[](1);
            token0[0] = getAddress(sourceChain, "WSTETH");

            address[] memory token1 = new address[](1);
            token1[0] = getAddress(sourceChain, "WETH");

            _addUniswapV3Leafs(leafs, token0, token1, false);
        }
        // ========================== Aave V3 ==========================
        {
            // Core
            ERC20[] memory supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "WETH");
            supplyAssets[1] = getERC20(sourceChain, "WSTETH");
            _addAaveV3Leafs(leafs, supplyAssets, supplyAssets);

            // Prime
            _addAaveV3PrimeLeafs(leafs, supplyAssets, supplyAssets);
        }
        // =========================== Odos ==========================
        {
            address[] memory assets = new address[](3);
            SwapKind[] memory kind = new SwapKind[](3);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "UNI");
            kind[2] = SwapKind.Sell;

            _addOdosSwapLeafs(leafs, assets, kind);

        // =========================== 1Inch ==========================
            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        }

        // =========================== Fluid Dex ==========================
        {
            ERC20[] memory supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "WETH");
            supplyAssets[1] = getERC20(sourceChain, "WSTETH");
            ERC20[] memory borrowAssets = new ERC20[](2);
            borrowAssets[0] = getERC20(sourceChain, "WETH");
            borrowAssets[1] = getERC20(sourceChain, "WSTETH");


            _addFluidDexLeafs(leafs, getAddress(sourceChain,"DEX-wstETH-ETH_DEX-wstETH-ETH"), 4000, supplyAssets, borrowAssets, true);
        }

        // =========================== Lido ==========================
        _addLidoLeafs(leafs);

        // =========================== Mellow ==========================
        address[] memory mellowTokens = new address[](2);
        mellowTokens[0] = getAddress(sourceChain, "WETH");
        mellowTokens[1] = getAddress(sourceChain, "WSTETH");
        _addDvStETHLeafs(leafs, mellowTokens);

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
