// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {SyUsdDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {
    MerkleTreeHelper, IMB, PendleMarket, PendleSy, ISilo
} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify --with-gas-price 30000000000
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract CreateSyUsdEthereumLeafs is Script, MerkleTreeHelper {
    uint256 public privateKey;

    // address public rawDataDecoderAndSanitizerEthereum = 0x2942Ca9E3676cd2CfAEfB113A0Aa67FEd49198f5;
    // address public rawDataDecoderAndSanitizerEthereum = 0x90992585BeF22047669fD3d166a78d992e4079cB;
    address public rawDataDecoderAndSanitizerEthereum = 0x16E9929986A16Db5d7D8CC058C17C62EB9b91431;
    address public rawDataDecoderAndSanitizerBase01 = 0x53F0b212d28320DD0aB504AbD6871941EFf5AD45;
    address public rawDataDecoderAndSanitizerArbitrum01 = 0x53F0b212d28320DD0aB504AbD6871941EFf5AD45;
    RolesAuthority internal rolesAuthority = RolesAuthority(0xf7F3ace7f6cA2Cb1E7ccbE3Bf2Da13D001D36fdF);
    BoringVault internal boringVault = BoringVault(payable(0x279CAD277447965AF3d24a78197aad1B02a2c589));
    LayerZeroTeller internal teller = LayerZeroTeller(0xaefc11908fF97c335D16bdf9F2Bf720817423825);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x9B3e565ffC70c4b72516BC2dbec4b3c790940CE8);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0xF632c10b19f2a0451cD4A653fC9ca0c15eA1040b);
    BoringSolver internal solver = BoringSolver(0x1d82e9bCc8F325caBBca6E6A3B287fE586536805);
    address agent = 0xF171cAf19B2a55B015a68D80C337a16216775509;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant PAUSER_ROLE = 5;
    uint8 public constant SOLVER_ROLE = 12;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 public constant GENERIC_PAUSER_ROLE = 14;
    uint8 public constant GENERIC_UNPAUSER_ROLE = 15;
    uint8 public constant PAUSE_ALL_ROLE = 16;
    uint8 public constant UNPAUSE_ALL_ROLE = 17;
    uint8 public constant SENDER_PAUSER_ROLE = 18;
    uint8 public constant SENDER_UNPAUSER_ROLE = 19;
    uint8 public constant CAN_SOLVE_ROLE = 31;
    uint8 public constant ONLY_QUEUE_ROLE = 32;
    uint8 public constant SOLVER_ORIGIN_ROLE = 33;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
        setSourceChainName("mainnet");

        setAddress(true, mainnet, "boringVault", address(boringVault));
        setAddress(true, mainnet, "managerAddress", address(manager));
        setAddress(true, mainnet, "manager", address(manager));
        setAddress(true, mainnet, "accountantAddress", address(accountant));
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizerEthereum);
    }

    function run() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](1024);
        _addLeafs(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Mainnet/SyUsdMainnetStrategistLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        vm.startBroadcast(privateKey);
        manager.setManageRoot(agent, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(0xa86b3Bf249478488B4304B50726c7D4689aD6320, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(getAddress(sourceChain, "managerAddress"), manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }

    function _addLeafs(ManageLeaf[] memory leafs) internal {
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "USDT");
        feeAssets[2] = getERC20(sourceChain, "USDS");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory bridgeAssets = new ERC20[](2);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        bridgeAssets[1] = getERC20(sourceChain, "USDT");
        ERC20[] memory feeTokens = new ERC20[](2);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        feeTokens[1] = getERC20(sourceChain, "GHO");

        _addCcipBridgeLeafs(leafs, ccipBaseChainSelector, bridgeAssets, feeTokens);
        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, bridgeAssets, feeTokens);
        _addCcipBridgeLeafs(leafs, ccipBscChainSelector, bridgeAssets, feeTokens);

        _addInfiniV1Leafs(leafs, getAddress(sourceChain, "USDC"));
        _addCurveLeafs(
            leafs, getAddress(sourceChain, "USDC_USDf_Curve_Pool"), 2, getAddress(sourceChain, "USDC_USDf_Curve_Gauge")
        );

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "WETH"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "ccipRouter");

        unchecked {
            leafIndex++;
        }
        leafs[leafIndex] = ManageLeaf(
            getAddress(sourceChain, "sUSDf"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        leafs[leafIndex].argumentAddresses[0] = getAddress(sourceChain, "pendleRouter");

        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDT"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "DAI"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDS"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));

        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "syrupUSDC_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "PT-syrupUSDC-28AUG2025_USDC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "PT-iUSD-4SEP2025_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "syrupUSDC_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "PT-syrupUSDC-28AUG2025_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "PT-iUSD-4SEP2025_USDC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "RLP_USDC_86"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "siUSD_USDC_915"));

        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_iUSD_09_04_2025"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_syrupUSDC_08_28_2025"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "LP_sUSDf_9_25_2025"), false);

        // 1inch assets;
        address[] memory oneInchAssets = new address[](12);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "SUSDE");
        oneInchAssets[2] = getAddress(sourceChain, "USDS");
        oneInchAssets[3] = getAddress(sourceChain, "USDT");
        oneInchAssets[4] = getAddress(sourceChain, "USDE");
        oneInchAssets[5] = getAddress(sourceChain, "lvlUSD");
        oneInchAssets[6] = getAddress(sourceChain, "RLP");
        oneInchAssets[7] = getAddress(sourceChain, "USR");
        oneInchAssets[8] = getAddress(sourceChain, "wstUSR");
        oneInchAssets[9] = getAddress(sourceChain, "cUSDO");
        oneInchAssets[10] = getAddress(sourceChain, "USDf");
        oneInchAssets[11] = getAddress(sourceChain, "sUSDf");
        SwapKind[] memory kind = new SwapKind[](12);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;
        kind[3] = SwapKind.BuyAndSell;
        kind[4] = SwapKind.BuyAndSell;
        kind[5] = SwapKind.BuyAndSell;
        kind[6] = SwapKind.BuyAndSell;
        kind[7] = SwapKind.BuyAndSell;
        kind[8] = SwapKind.BuyAndSell;
        kind[9] = SwapKind.BuyAndSell;
        kind[10] = SwapKind.BuyAndSell;
        kind[11] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, kind);
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);

        address[] memory incentivesControllers = new address[](2);
        incentivesControllers[0] = address(0);
        incentivesControllers[1] = address(0);
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_PT-sUSDf_25Sep_USDC_config"), incentivesControllers);

        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "SUSDE");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT"),
            getAddress(sourceChain, "USDTOFTAdapter"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDf")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCfrontier")));
    }
}
