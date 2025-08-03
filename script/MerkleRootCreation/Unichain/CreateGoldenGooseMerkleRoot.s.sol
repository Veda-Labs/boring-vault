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
 *  source .env && forge script script/MerkleRootCreation/Unichain/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $UNICHAIN_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0x6eBFeB1DECeE6Ef24fc7d9bd2360E87f75b29f0B; 
    address public primeGoldenGooseTeller = 0x4ecC202775678F7bCfF8350894e2F2E3167Cc3Df;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        vm.createSelectFork(vm.envString("UNICHAIN_RPC_URL"));
        setSourceChainName("unichain"); 
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        setSourceChainName(unichain);
        setAddress(false, unichain, "boringVault", boringVault);
        setAddress(false, unichain, "managerAddress", managerAddress);
        setAddress(false, unichain, "accountantAddress", accountantAddress);
        setAddress(false, unichain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, unichain, "primeGoldenGooseTeller", primeGoldenGooseTeller);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

         // ========================== Teller ==========================
        // Enable bulkDeposit and bulkWithdraw on Prime Golden Goose vault
        ERC20[] memory tellerAssets = new ERC20[](2);
        tellerAssets[0] = getERC20(sourceChain, "WETH");
        tellerAssets[1] = getERC20(sourceChain, "WSTETH");
        _addTellerLeafs(leafs, getAddress(sourceChain, "primeGoldenGooseTeller"), tellerAssets, false, true);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        ERC20[] memory remoteTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "WETH");
        remoteTokens[0] = getERC20(mainnet, "WETH");
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
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0)
        );

        // ========================== Layer Zero ==========================
        _addLayerZeroLeafNative(leafs, getAddress(sourceChain, "stargateNative"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Uniswap V4 ==========================
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
        
         // =========================== Odos ==========================
        {
            address[] memory assets = new address[](2);
            SwapKind[] memory kind = new SwapKind[](2);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;


            _addOdosSwapLeafs(leafs, assets, kind);

        // =========================== 1Inch ==========================
            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        }

        // ========================== Morpho ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "morphowstETHmarket"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "morphowstETHmarket"));

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "morphoSmokehouseWSTETH")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "morphoSteakhouseETH")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "morphoK3CapitalETHMaxi")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "morphoGauntletWETH")));

        // ========================== Euler ==========================
        {
            ERC4626[] memory depositVaults = new ERC4626[](2);
            depositVaults[0] = ERC4626(getAddress(sourceChain, "eulerWETH"));
            depositVaults[1] = ERC4626(getAddress(sourceChain, "eulerwstETHmarket"));

            address[] memory subaccounts = new address[](2);
            subaccounts[0] = address(boringVault);
            subaccounts[1] = address(boringVault);

            _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        }

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Unichain/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
