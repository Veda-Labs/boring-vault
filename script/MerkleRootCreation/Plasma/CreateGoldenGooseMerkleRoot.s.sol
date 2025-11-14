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
 * @title CreateGoldenGooseMerkleRoot
 * @notice Creates merkle root for Golden Goose vault on Plasma network
 * Usage:
 *  source .env && forge script script/MerkleRootCreation/Plasma/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $PLASMA_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0x648Ea7629EEed1a7F081079850b278FF919dbb89;
    address public goldenGooseTeller = 0xE89fAaf3968ACa5dCB054D4a9287E54aa84F67e9;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        vm.createSelectFork(vm.envString("PLASMA_RPC_URL"));

        setSourceChainName(plasma);
        setAddress(false, plasma, "boringVault", boringVault);
        setAddress(false, plasma, "managerAddress", managerAddress);
        setAddress(false, plasma, "accountantAddress", accountantAddress);
        setAddress(false, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, plasma, "goldenGooseTeller", goldenGooseTeller);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "wXPL"));

        // ========================== Aave V3 ==========================
        {
            ERC20[] memory supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "wstETH");
            supplyAssets[1] = getERC20(sourceChain, "WEETH");

            ERC20[] memory borrowAssets = new ERC20[](2);
            borrowAssets[0] = getERC20(sourceChain, "USDT0");
            borrowAssets[1] = getERC20(sourceChain, "WETH");

            _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
        }

        // ========================== Swaps - Red Snwapper ==========================
        
        {
            address[] memory assets = new address[](6);
            SwapKind[] memory kind = new SwapKind[](6);

            assets[0] = getAddress(sourceChain, "USDT0");
            kind[0] = SwapKind.BuyAndSell;

            assets[1] = getAddress(sourceChain, "wstETH");
            kind[1] = SwapKind.BuyAndSell;

            assets[2] = getAddress(sourceChain, "WEETH");
            kind[2] = SwapKind.BuyAndSell;

            assets[3] = getAddress(sourceChain, "WETH");
            kind[3] = SwapKind.BuyAndSell;

            assets[4] = getAddress(sourceChain, "wXPL");
            kind[4] = SwapKind.Sell;

            assets[5] = getAddress(sourceChain, "FLUID");
            kind[5] = SwapKind.Sell;

            // TODO: Add GEAR token once available on Plasma for Gearbox rewards
            // assets[6] = getAddress(sourceChain, "GEAR");
            // kind[6] = SwapKind.Sell;

            _addSnwapLeafs(leafs, assets, kind);
        }

        // ========================== Swaps - GlueX ==========================
        {
            address[] memory assets = new address[](6);
            SwapKind[] memory kind = new SwapKind[](6);

            assets[0] = getAddress(sourceChain, "USDT0");
            kind[0] = SwapKind.BuyAndSell;

            assets[1] = getAddress(sourceChain, "wstETH");
            kind[1] = SwapKind.BuyAndSell;

            assets[2] = getAddress(sourceChain, "WEETH");
            kind[2] = SwapKind.BuyAndSell;

            assets[3] = getAddress(sourceChain, "WETH");
            kind[3] = SwapKind.BuyAndSell;

            assets[4] = getAddress(sourceChain, "wXPL");
            kind[4] = SwapKind.Sell;

            assets[5] = getAddress(sourceChain, "FLUID");
            kind[5] = SwapKind.Sell;

            _addGlueXLeafs(leafs, assets, kind);
        }

        // ========================== Fluid fUSDT0 Vault ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDT0"));

        // TODO: Add Fluid rewards claiming once addresses verified
        // _addFluidRewardsClaiming(leafs);

        // ========================== Euler Vaults ==========================
        {
            ERC4626[] memory depositVaults = new ERC4626[](3);
            depositVaults[0] = ERC4626(getAddress(sourceChain, "evkTelosCurveUSDT0"));
            depositVaults[1] = ERC4626(getAddress(sourceChain, "evkK3KapitalUSDT0"));
            depositVaults[2] = ERC4626(getAddress(sourceChain, "evkRe7USDT0Core"));

            address[] memory subaccounts = new address[](1);
            subaccounts[0] = getAddress(sourceChain, "boringVault");

            _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        }

        // ========================== Gearbox Edge UltraYield ==========================
            _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dUSDT0")), address(0)); // No staking address yet
        
        // TODO: Add staking address once GEAR rewards become available on Plasma
        // TODO: Add GEAR token to ChainValues for swap support once available

        // ========================== Merkl Rewards ==========================
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address") 
        );

          // ========================== CCIP ==========================
        {
            ERC20[] memory ccipBridgeAssets = new ERC20[](1);
            ccipBridgeAssets[0] = getERC20(sourceChain, "wstETH");
            ERC20[] memory ccipBridgeFeeAssets = new ERC20[](2);
            ccipBridgeFeeAssets[0] = getERC20(sourceChain, "WETH");
            ccipBridgeFeeAssets[1] = getERC20(sourceChain, "LINK");
            _addCcipBridgeLeafs(leafs, ccipMainnetChainSelector, ccipBridgeAssets, ccipBridgeFeeAssets);
        }


        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Plasma/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
