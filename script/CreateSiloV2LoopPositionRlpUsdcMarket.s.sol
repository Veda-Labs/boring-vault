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
    MerkleTreeHelper,
    IMB,
    PendleMarket,
    PendleSy,
    ISilo
} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify --with-gas-price 30000000000
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 * @dev Create RLP long position on SiloV2 ethereum
 */
contract CreateRlpLongPositionOnSiloV2 is Script, MerkleTreeHelper {
    uint256 public privateKey;

    address public rawDataDecoderAndSanitizerEthereum = 0x2942Ca9E3676cd2CfAEfB113A0Aa67FEd49198f5;
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
        setSourceChainName("mainnet");
        vm.createSelectFork(mainnet);

        // rawDataDecoderAndSanitizerEthereum = address(
        //     new SyUsdDecoderAndSanitizer(
        //         getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "odosRouterV2")
        //     )
        // );

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

        vm.startBroadcast(privateKey);
        manager.setManageRoot(agent, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(getAddress(sourceChain, "managerAddress"), manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("BORING_MORPHO_AGENT"));

        uint256 cacheUsdcBalance = 26040e6;
        uint256 flashloanAmount = cacheUsdcBalance * 65 / 10;
        // uint256 totalCapital = flashloanAmount + cacheUsdcBalance;

        (address silo0, address silo1) = ISilo(getAddress(sourceChain, "silo_rlp_usdc_config")).getSilos();

        bytes memory userData;
        {
            bytes32[][] memory flashloanManageProofs = _createFlashloanManageLeafs(manageTree);

            address[] memory targets = new address[](5);
            targets[0] = getAddress(sourceChain, "USDC"); // call approve on USDC
            targets[1] = getAddress(sourceChain, "odosRouterV2"); // call swap on odos router
            targets[2] = getAddress(sourceChain, "RLP"); // call approve on RLP
            targets[3] = silo0; // deposit RLP on silo0
            targets[4] = silo1; // borrow USDC from silo1

            bytes[] memory targetData = new bytes[](5);

            targetData[0] = abi.encodeWithSignature(
                "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
            );
            targetData[1] =
                hex"83bd37f90001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800014956b52ae2ff65d74ca2d61207523288e4528f96052a03a87c800a1eba5ba0543dac00000000c49b00017882570840A97A490a37bd8Db9e1aE39165bfBd600000001279CAD277447965AF3d24a78197aad1B02a2c589000000000d04040e01681fee696701000101020100010b1f105c0d0100030200010bb54211570205010502007fffffad01f9608d050d020506020000660301010702000102000004670000000408000101ce42b9ab66030101090a0001006803010b0a0c0d00ff0000000000000000000000000000000000000000000000000000000000003ee841f47947fefbe510366e4bbb49e145484195a0b86991c6218b36c1d19d4a2e9eb0ce3606eb488bb9cd887dd51c5aa8d7da9e244c94bec035e47c4628f13651ead6793f8d838b34b8f8522fb0cc5214cf6d2fe3e1b326114b07d22a6f6bb59e346c675c95d4b1c3321cf898d25949f41d50be2db5bc1d8e001d4bac0eae1eea348dfc22f9b8bda67dd21140d16fc0246ad3160ccc09b8d0d3a2cd28ae6c2fc907ba505c2e1cbc4658c395d4a2c7e6d2c3265666a1e37c9b0eaddca17d3662d6c05f4decf3e1109481d2483d198913281986d36f51dcfb8c0510864956b52ae2ff65d74ca2d61207523288e4528f961202f5c7b4b9e47a1a484e8b270be34dbbc7505500000000000000000000000000000000000000000000000000000000";
            targetData[2] = abi.encodeWithSignature("approve(address,uint256)", silo0, type(uint256).max);
            targetData[3] =
                abi.encodeWithSignature("deposit(uint256,address)", 145108691253476913577984, address(boringVault));
            targetData[4] = abi.encodeWithSignature(
                "borrow(uint256,address,address)", flashloanAmount, address(boringVault), address(boringVault)
            );

            uint256[] memory values = new uint256[](5);
            address[] memory decodersAndSanitizers = new address[](5);
            for (uint256 i = 0; i < 5; i++) {
                decodersAndSanitizers[i] = getAddress(sourceChain, "rawDataDecoderAndSanitizer");
            }

            userData = abi.encode(flashloanManageProofs, decodersAndSanitizers, targets, targetData, values);
        }
        {
            address[] memory targets = new address[](1);
            bytes[] memory targetData = new bytes[](1);
            ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
            uint256[] memory values = new uint256[](1);
            address[] memory decodersAndSanitizers = new address[](1);

            {
                address[] memory tokensToBorrow = new address[](1);
                tokensToBorrow[0] = getAddress(sourceChain, "USDC");
                uint256[] memory amountsToBorrow = new uint256[](1);
                amountsToBorrow[0] = flashloanAmount;
                targetData[0] = abi.encodeWithSelector(
                    BalancerVault.flashLoan.selector, address(manager), tokensToBorrow, amountsToBorrow, userData
                );

                targets[0] = getAddress(sourceChain, "manager");
                manageLeafs[0] = ManageLeaf(
                    getAddress(sourceChain, "manager"),
                    false,
                    "flashLoan(address,address[],uint256[],bytes)",
                    new address[](2),
                    string.concat("Flashloan ", getERC20(sourceChain, "USDC").symbol(), " from Balancer Vault"),
                    getAddress(sourceChain, "rawDataDecoderAndSanitizer")
                );
                manageLeafs[0].argumentAddresses[0] = getAddress(sourceChain, "managerAddress");
                manageLeafs[0].argumentAddresses[1] = getAddress(sourceChain, "USDC");
                decodersAndSanitizers[0] = getAddress(sourceChain, "rawDataDecoderAndSanitizer");
            }

            bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
            manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        }

        vm.stopBroadcast();
    }

    function _createFlashloanManageLeafs(bytes32[][] memory manageTree)
        internal
        view
        returns (bytes32[][] memory flashloanManageProofs)
    {
        ManageLeaf[] memory flashloanLeafs = new ManageLeaf[](5);
        (address silo0, address silo1) = ISilo(getAddress(sourceChain, "silo_rlp_usdc_config")).getSilos();

        // approve odos router to spend usdc
        flashloanLeafs[0] = ManageLeaf(
            getAddress(sourceChain, "USDC"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        flashloanLeafs[0].argumentAddresses[0] = getAddress(sourceChain, "odosRouterV2");

        // swap USDC for RLP
        flashloanLeafs[1] = ManageLeaf(
            getAddress(sourceChain, "odosRouterV2"),
            false,
            "swapCompact()",
            new address[](4),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        flashloanLeafs[1].argumentAddresses[0] = getAddress(sourceChain, "USDC");
        flashloanLeafs[1].argumentAddresses[1] = getAddress(sourceChain, "RLP");
        flashloanLeafs[1].argumentAddresses[2] = getAddress(sourceChain, "boringVault");
        flashloanLeafs[1].argumentAddresses[3] = getAddress(sourceChain, "odosExecutor");

        // approve silo0 to spend RLP
        flashloanLeafs[2] = ManageLeaf(
            getAddress(sourceChain, "RLP"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        flashloanLeafs[2].argumentAddresses[0] = silo0;

        // deposit RLP on silo0 of RLP/USDC config
        flashloanLeafs[3] = ManageLeaf(
            silo0,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        flashloanLeafs[3].argumentAddresses[0] = getAddress(sourceChain, "boringVault");

        // borrow usdc from silo1 of RLP/USDC config
        flashloanLeafs[4] = ManageLeaf(
            silo1,
            false,
            "borrow(uint256,address,address)",
            new address[](2),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        flashloanLeafs[4].argumentAddresses[0] = getAddress(sourceChain, "boringVault");
        flashloanLeafs[4].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        flashloanManageProofs = _getProofsUsingTree(flashloanLeafs, manageTree);
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

        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_iUSD_09_04_2025"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_syrupUSDC_08_28_2025"), false);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "LP_sUSDf_9_25_2025"), false);

        // 1inch assets;
        address[] memory oneInchAssets = new address[](10);
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
        SwapKind[] memory kind = new SwapKind[](10);
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
        _addLeafsFor1InchGeneralSwapping(leafs, oneInchAssets, kind);
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);

        address[] memory incentivesControllers = new address[](2);
        incentivesControllers[0] = address(0);
        incentivesControllers[1] = address(0);
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_PT-sUSDf_25Sep_USDC_config"), incentivesControllers);
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_rlp_usdc_config"), incentivesControllers);

        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "SUSDE");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDf")));
    }
}
