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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0x2aa1F761eC74EC12Aa465332C29446311425712f;
    address public kingClaimingDecoderAndSanitizer = 0xd4067b594C6D48990BE42a559C8CfDddad4e8D6F;
    address public drone = 0x4341135454A602D46b95ACfaDD88db967Bcc35CA;
    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        // Force mainnet fork
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== Rewards ==========================
        _addMerklLeafs(
            leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address")
        );
        _addrEULWrappingLeafs(leafs);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](0);
        ERC20[] memory remoteTokens = new ERC20[](0);

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
            getAddress(sourceChain, "lidoUnichainResolvedDelegate"),
            getAddress(sourceChain, "lidoUnichainStandardBridge"),
            getAddress(sourceChain, "lidoUnichainPortal")
        );

        // ========================== Layer Zero ==========================
        _addLayerZeroLeafNative(
            leafs,
            getAddress(sourceChain, "stargateNative"),
            layerZeroUnichainEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Morpho ==========================
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WSTETH_WETH_945"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WSTETH_WETH_965"));

        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WSTETH_WETH_945"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WSTETH_WETH_965"));

        // Additional Morpho Blue market: 0xc54d7acf14de29e0e5527cabd7a576506870346a78a11a6762e2cca66322ec41
        _addMorphoBlueCollateralLeafs(leafs, 0xc54d7acf14de29e0e5527cabd7a576506870346a78a11a6762e2cca66322ec41);
        _addMorphoBlueSupplyLeafs(leafs, 0xc54d7acf14de29e0e5527cabd7a576506870346a78a11a6762e2cca66322ec41);

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseETH")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWETHPrime")));

        // ========================== Euler ==========================
        {
            ERC4626[] memory depositVaults = new ERC4626[](2);
            depositVaults[0] = ERC4626(getAddress(sourceChain, "eulerPrimeWETH"));
            depositVaults[1] = ERC4626(getAddress(sourceChain, "evkWSTETH"));

            address[] memory subaccounts = new address[](1);
            subaccounts[0] = address(boringVault);

            _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        }

        // ========================== Balancer ==========================
        _addBalancerV3Leafs(
            leafs,
            getAddress(sourceChain, "balancerV3_Surge_Fluid_wstETH-wETH_boosted"),
            true,
            getAddress(sourceChain, "balancerV3_Surge_Fluid_wstETH-wETH_boosted_gauge")
        );
        _addBalancerV3Leafs(
            leafs,
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted"),
            true,
            getAddress(sourceChain, "balancerV3_WETH_WSTETH_boosted_gauge")
        );

        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== Balancer Flash Loans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WSTETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDT"));

        // =========================== Lido ==========================
        _addLidoLeafs(leafs);

        // =========================== Odos ==========================
        {
            address[] memory assets = new address[](14);
            SwapKind[] memory kind = new SwapKind[](14);
            assets[0] = getAddress(sourceChain, "WETH");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WSTETH");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "WEETH");
            kind[2] = SwapKind.BuyAndSell;
            assets[3] = getAddress(sourceChain, "UNI");
            kind[3] = SwapKind.Sell;
            assets[4] = getAddress(sourceChain, "rEUL");
            kind[4] = SwapKind.Sell;
            assets[5] = getAddress(sourceChain, "EUL");
            kind[5] = SwapKind.Sell;
            assets[6] = getAddress(sourceChain, "ETHFI");
            kind[6] = SwapKind.Sell;
            assets[7] = getAddress(sourceChain, "EIGEN");
            kind[7] = SwapKind.Sell;
            assets[8] = getAddress(sourceChain, "MORPHO");
            kind[8] = SwapKind.Sell;
            assets[9] = getAddress(sourceChain, "MNT");
            kind[9] = SwapKind.Sell;
            assets[10] = getAddress(sourceChain, "USDC");
            kind[10] = SwapKind.BuyAndSell;
            assets[11] = getAddress(sourceChain, "USDT");
            kind[11] = SwapKind.BuyAndSell;
            assets[12] = getAddress(sourceChain, "USR");
            kind[12] = SwapKind.BuyAndSell;
            assets[13] = getAddress(sourceChain, "wstUSR");
            kind[13] = SwapKind.BuyAndSell;

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

            _addFluidDexLeafs(
                leafs, getAddress(sourceChain, "DEX-wstETH-ETH_DEX-wstETH-ETH"), 4000, supplyAssets, borrowAssets, true
            );
        }

        // ========================== Uniswap V4 ==========================
        {
            address[] memory hooks = new address[](1);
            address[] memory token0 = new address[](1);
            address[] memory token1 = new address[](1);

            hooks[0] = address(0);
            token0[0] = address(0);
            token1[0] = getAddress(sourceChain, "WSTETH");

            _addUniswapV4Leafs(leafs, token0, token1, hooks);
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
            // Core - including weETH supply
            ERC20[] memory coreSupplyAssets = new ERC20[](3);
            coreSupplyAssets[0] = getERC20(sourceChain, "WETH");
            coreSupplyAssets[1] = getERC20(sourceChain, "WSTETH");
            coreSupplyAssets[2] = getERC20(sourceChain, "weETH");

            ERC20[] memory coreBorrowAssets = new ERC20[](2);
            coreBorrowAssets[0] = getERC20(sourceChain, "WETH");
            coreBorrowAssets[1] = getERC20(sourceChain, "WSTETH");

            _addAaveV3Leafs(leafs, coreSupplyAssets, coreBorrowAssets);

            // Prime
            ERC20[] memory primeAssets = new ERC20[](2);
            primeAssets[0] = getERC20(sourceChain, "WETH");
            primeAssets[1] = getERC20(sourceChain, "WSTETH");
            _addAaveV3PrimeLeafs(leafs, primeAssets, primeAssets);
        }

        // =========================== Mellow ==========================
        // dvstETH operations (handles Mellow vault deposits/withdrawals)
        _addDvStETHLeafs(leafs);

        // rstETH restaking via Mellow (Lido restaked ETH)
        // TODO: Add Mellow rstETH restaking implementation once decoder supports it
        // This is different from dvstETH and requires specific rstETH handling

        // =========================== EtherFi ==========================
        // weETH operations
        _addEtherFiLeafs(leafs);

        // =========================== Treehouse ==========================
        // tETH vault deposits
        {
            ERC20[] memory routerTokensIn = new ERC20[](1);
            routerTokensIn[0] = getERC20(sourceChain, "WSTETH");
            _addTreehouseLeafs(
                leafs,
                routerTokensIn,
                getAddress(sourceChain, "TreehouseRouter"),
                getAddress(sourceChain, "TreehouseRedemption"),
                getERC20(sourceChain, "tETH"),
                getAddress(sourceChain, "tETH_wstETH_curve_pool"),
                2,
                address(0) // No gauge
            );
        }

        // =========================== Gearbox ==========================
        // TODO: Add Gearbox rstETH/wstETH loop strategy when decoder supports it

        // =========================== Turtle Club ==========================
        // Katana Pre-deposit vault for WETH - commented out until vault address is available
        // Note: Turtle Club Katana vault is intentionally commented out pending final address confirmation
        // _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "katanaVault")));

        // =========================== Additional Bridging ==========================
        // Arbitrum Bridge
        {
            ERC20[] memory arbBridgeAssets = new ERC20[](2);
            arbBridgeAssets[0] = getERC20(sourceChain, "WETH");
            arbBridgeAssets[1] = getERC20(sourceChain, "WSTETH");
            _addArbitrumNativeBridgeLeafs(leafs, arbBridgeAssets);
        }

        // Optimism Bridge (using standard bridge which is already configured above)
        // Base Bridge (using standard bridge pattern)
        {
            ERC20[] memory baseLocalTokens = new ERC20[](0);
            ERC20[] memory baseRemoteTokens = new ERC20[](0);

            _addStandardBridgeLeafs(
                leafs,
                base,
                getAddress(base, "crossDomainMessenger"),
                getAddress(sourceChain, "baseResolvedDelegate"),
                getAddress(sourceChain, "baseStandardBridge"),
                getAddress(sourceChain, "basePortal"),
                baseLocalTokens,
                baseRemoteTokens
            );

            _addLidoStandardBridgeLeafs(
                leafs,
                base,
                getAddress(base, "crossDomainMessenger"),
                getAddress(sourceChain, "lidoBaseResolvedDelegate"),
                getAddress(sourceChain, "lidoBaseStandardBridge"),
                getAddress(sourceChain, "lidoBasePortal")
            );
        }

        // Optimism Bridge addition
        {
            ERC20[] memory opLocalTokens = new ERC20[](0);
            ERC20[] memory opRemoteTokens = new ERC20[](0);

            _addStandardBridgeLeafs(
                leafs,
                optimism,
                getAddress(optimism, "crossDomainMessenger"),
                getAddress(sourceChain, "optimismResolvedDelegate"),
                getAddress(sourceChain, "optimismStandardBridge"),
                getAddress(sourceChain, "optimismPortal"),
                opLocalTokens,
                opRemoteTokens
            );

            _addLidoStandardBridgeLeafs(
                leafs,
                optimism,
                getAddress(optimism, "crossDomainMessenger"),
                getAddress(sourceChain, "lidoOptimismResolvedDelegate"),
                getAddress(sourceChain, "lidoOptimismStandardBridge"),
                getAddress(sourceChain, "lidoOptimismPortal")
            );
        }

        // ========================== vbVault ==========================

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "vbETH")));

        // Agglayer bridging to Katana
        // Note: Agglayer bridge addresses need to be added to MainnetAddresses.sol
        _addAgglayerTokenLeafs(
            leafs,
            getAddress(sourceChain, "agglayerBridgeKatana"),
            getAddress(sourceChain, "vbETH"),
            0, // Mainnet chain ID in Agglayer
            20 // Katana chain ID in Agglayer
        );
        _addAgglayerTokenLeafs(
            leafs,
            getAddress(sourceChain, "agglayerBridgeKatana"),
            getAddress(sourceChain, "WSTETH"),
            0, // Mainnet chain ID in Agglayer
            20 // Katana chain ID in Agglayer
        );

        // ========================== Layer Zero ==========================
        // to Base
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WEETH"),
            getAddress(sourceChain, "EtherFiOFTAdapter"),
            layerZeroBaseEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Linea Bridge ==========================
        {
            ERC20[] memory lineaTokens = new ERC20[](1); 
            lineaTokens[0] = getERC20(sourceChain, "WSTETH"); 

            _addLineaNativeBridgeLeafs(leafs, "linea", lineaTokens); 
        }

        // ========================== King Claiming  ==========================
        {
             setAddress(true, mainnet, "rawDataDecoderAndSanitizer", kingClaimingDecoderAndSanitizer);
            _addKingRewardsClaimingLeafs(leafs, new address[](0), getAddress(sourceChain, "boringVault"));
        }

        // ==========================  Drone Transfers ==========================

        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        {
            ERC20[] memory droneTokens = new ERC20[](6);
            droneTokens[0] = getERC20(sourceChain, "WSTUSR");
            droneTokens[1] = getERC20(sourceChain, "USDC");
            droneTokens[2] = getERC20(sourceChain, "WSTETH");
            droneTokens[3] = getERC20(sourceChain, "USDT");
            droneTokens[4] = getERC20(sourceChain, "WETH");
            droneTokens[5] = getERC20(sourceChain, "USR");
            _addLeafsForDroneTransfers(leafs, drone, droneTokens);
            _addLeafsForDrone(leafs);
        }

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs) internal {
        setAddress(true, mainnet, "boringVault", drone);
        uint256 droneStartIndex = leafIndex + 1;
        
        // ========================== AAVE Drone Leaves ==========================
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== resolv leaves ==========================
        _addAllResolvLeafs(leafs);
        // ========================== swap leaves ==========================
        address[] memory swapAssets = new address[](6);
        swapAssets[0] = getAddress(sourceChain, "USDC");
        swapAssets[1] = getAddress(sourceChain, "USDT");
        swapAssets[2] = getAddress(sourceChain, "WSTETH");
        swapAssets[3] = getAddress(sourceChain, "WETH");
        swapAssets[4] = getAddress(sourceChain, "USR");
        swapAssets[5] = getAddress(sourceChain, "WSTUSR");
        SwapKind[] memory kind = new SwapKind[](6);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell; // We only want to buy wstETH and WETH
        kind[3] = SwapKind.BuyAndSell; // We only want to buy wstETH and WETH
        kind[4] = SwapKind.BuyAndSell;
        kind[5] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, swapAssets, kind);
        _addOdosSwapLeafs(leafs, swapAssets, kind);
        // ========================== merkl claiming leaves ==========================
        _addMerklLeafs(
            leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address")
        );
        // ========================== fluid leaves ==========================
        ERC20[] memory supplyAssets2 = new ERC20[](1);
        supplyAssets2[0] = getERC20(sourceChain, "wstUSR");
        ERC20[] memory borrowAssets2 = new ERC20[](1);
        borrowAssets2[0] = getERC20(sourceChain, "USDC");
        _addFluidDexLeafs(
            leafs, getAddress(sourceChain, "wstUSR-USDC"), 1000, supplyAssets2, borrowAssets2, false
        );
        ERC20[] memory borrowAssets3 = new ERC20[](1);
        borrowAssets3[0] = getERC20(sourceChain, "USDT");
        _addFluidDexLeafs(
            leafs, getAddress(sourceChain, "wstUSR-USDT"), 1000, supplyAssets2, borrowAssets3, false
        );
        
        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }
}
