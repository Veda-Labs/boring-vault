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
 *  source .env && forge script script/MerkleRootCreation/Linea/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $LINEA_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0xef34830ac7d32873Cce15392EB4D23eaC71Cb581; 

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        setSourceChainName(linea);
        setAddress(false, linea, "boringVault", boringVault);
        setAddress(false, linea, "managerAddress", managerAddress);
        setAddress(false, linea, "accountantAddress", accountantAddress);
        setAddress(false, linea, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Linea Bridge ==========================
        {
        
        ERC20[] memory localTokens = new ERC20[](1); 
        localTokens[0] = getERC20(sourceChain, "WSTETH"); 

        _addLineaNativeBridgeLeafs(leafs, "mainnet", localTokens); 

        }

        // ========================== Euler ==========================
        {
            ERC4626[] memory depositVaults = new ERC4626[](4);
            depositVaults[0] = ERC4626(getAddress(sourceChain, "evkewstETH-1"));
            depositVaults[1] = ERC4626(getAddress(sourceChain, "evkewstETH-3"));
            depositVaults[2] = ERC4626(getAddress(sourceChain, "evkeUSDC-1"));
            depositVaults[3] = ERC4626(getAddress(sourceChain, "evkeUSDT-1"));

            address[] memory subaccounts = new address[](1);
            subaccounts[0] = address(boringVault);

            _addEulerDepositLeafs(leafs, depositVaults, subaccounts);

            ERC4626[] memory borrowVaults = new ERC4626[](2);  
            borrowVaults[0] = ERC4626(getAddress(sourceChain, "evkewETH-1"));
            borrowVaults[1] = ERC4626(getAddress(sourceChain, "evkewETH-7"));

            _addEulerBorrowLeafs(leafs, borrowVaults, subaccounts);
        }
        address[] memory assets = new address[](3);
            SwapKind[] memory kind = new SwapKind[](3);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "LINEA");
            kind[2] = SwapKind.Sell;

        // =========================== Odos ==========================
        {

            _addOdosSwapLeafs(leafs, assets, kind);
        }

        // ========================== Aave V3 ==========================
        {
            ERC20[] memory coreSupplyAssets = new ERC20[](2);
            coreSupplyAssets[0] = getERC20(sourceChain, "WETH");
            coreSupplyAssets[1] = getERC20(sourceChain, "WSTETH");

            ERC20[] memory coreBorrowAssets = new ERC20[](4);
            coreBorrowAssets[0] = getERC20(sourceChain, "WETH");
            coreBorrowAssets[1] = getERC20(sourceChain, "WSTETH");
            coreBorrowAssets[2] = getERC20(sourceChain, "USDC");
            coreBorrowAssets[3] = getERC20(sourceChain, "USDT");

            _addAaveV3Leafs(leafs, coreSupplyAssets, coreBorrowAssets);
        }

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Linea/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
