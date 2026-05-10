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
import {MorphoFlashLoanAdapter} from "src/base/Roles/MorphoFlashLoan/MorphoFlashLoanAdapter.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify --with-gas-price 30000000000
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract CreateSyUsdEthereumLeafs is Script, MerkleTreeHelper {
    uint256 public privateKey;

    address public rawDataDecoderAndSanitizerEthereum = 0x02649C96083c61C5419e3b3516fEDC0f5E8115C2;
    RolesAuthority internal rolesAuthority = RolesAuthority(0xf7F3ace7f6cA2Cb1E7ccbE3Bf2Da13D001D36fdF);
    BoringVault internal boringVault = BoringVault(payable(0x279CAD277447965AF3d24a78197aad1B02a2c589));
    LayerZeroTeller internal teller = LayerZeroTeller(0xaefc11908fF97c335D16bdf9F2Bf720817423825);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x9B3e565ffC70c4b72516BC2dbec4b3c790940CE8);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0xF632c10b19f2a0451cD4A653fC9ca0c15eA1040b);
    BoringSolver internal solver = BoringSolver(0x1d82e9bCc8F325caBBca6E6A3B287fE586536805);
    MorphoFlashLoanAdapter internal flashLoanAdapter =
        MorphoFlashLoanAdapter(0x82baFd173334e9cd34eB746BA6b55ffcb4d06a4d);

    address public roycoJrUsdcVault = 0x71861827Aa95cA48148bdA0b40BC740d1c421070;
    address public roycoJrUsdcWithdrawQueue = 0x6823Cf7f97970748A34407Acf6056562415b7237;
    address public roycoJrUsdcTeller = 0x8C87d801B6CA569a73D9428351415afAeC293E28;
    address public roycoJrUsdcQueueSolver = 0x78acDecABb2Faa7d811b02937Db3806968c7dc2b;

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
        privateKey = vm.envUint("DEPLOYER01");
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
        string memory filePath = "./leafs/Mainnet/SyUsdMainnetStrategist02Leafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        vm.startBroadcast(privateKey);
        manager.setManageRoot(0x31Cf9D74d825E8BcF9608275B85dD9F1f4B3b429, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(address(flashLoanAdapter), manageTree[manageTree.length - 1][0]);

        rolesAuthority.setUserRole(address(flashLoanAdapter), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(flashLoanAdapter), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(0x31Cf9D74d825E8BcF9608275B85dD9F1f4B3b429, STRATEGIST_ROLE, true);
        vm.stopBroadcast();
    }

    function _addLeafs(ManageLeaf[] memory leafs) internal {
        // fee claiming
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "USDT");
        feeAssets[2] = getERC20(sourceChain, "USDS");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ccip bridge
        ERC20[] memory bridgeAssets = new ERC20[](2);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        bridgeAssets[1] = getERC20(sourceChain, "USDT");
        ERC20[] memory feeTokens = new ERC20[](2);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        feeTokens[1] = getERC20(sourceChain, "GHO");

        _addCcipBridgeLeafs(leafs, ccipBaseChainSelector, bridgeAssets, feeTokens);
        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, bridgeAssets, feeTokens);
        _addCcipBridgeLeafs(leafs, ccipBscChainSelector, bridgeAssets, feeTokens);

        // infiniFi
        _addInfiniV1Leafs(leafs, getAddress(sourceChain, "USDC"));

        // cap money
        address[] memory capDepositTokens = new address[](1);
        capDepositTokens[0] = getAddress(sourceChain, "USDC");
        _addCapLeafs(leafs, capDepositTokens);

        // syrup
        _addSyrupPoolLeafs(leafs);

        // fly.trade
        address[] memory oneInchAssets = new address[](8);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "SUSDE");
        oneInchAssets[2] = getAddress(sourceChain, "USDS");
        oneInchAssets[3] = getAddress(sourceChain, "USDT");
        oneInchAssets[4] = getAddress(sourceChain, "USDE");
        oneInchAssets[5] = getAddress(sourceChain, "sUSDS");
        oneInchAssets[6] = getAddress(sourceChain, "RLUSD");
        oneInchAssets[7] = getAddress(sourceChain, "PYUSD");
        SwapKind[] memory kind = new SwapKind[](8);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;
        kind[3] = SwapKind.BuyAndSell;
        kind[4] = SwapKind.BuyAndSell;
        kind[5] = SwapKind.BuyAndSell;
        kind[6] = SwapKind.BuyAndSell;
        kind[7] = SwapKind.BuyAndSell;
        _addMagpieSwapLeafs(leafs, oneInchAssets, kind);

        // aave core
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "SUSDE");
        supplyAssets[1] = getERC20(sourceChain, "SUSDE");
        supplyAssets[2] = getERC20(sourceChain, "SUSDE");
        supplyAssets[3] = getERC20(sourceChain, "syrupUSDC");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // morpho blue flashLoan
        _addMorphoBlueFlashLoanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addMorphoBlueFlashLoanLeafs(leafs, getAddress(sourceChain, "USDT"));
        _addMorphoBlueFlashLoanLeafs(leafs, getAddress(sourceChain, "RLUSD"));
        _addMorphoBlueFlashLoanLeafs(leafs, getAddress(sourceChain, "PYUSD"));
        _addMorphoBlueFlashLoanLeafs(leafs, getAddress(sourceChain, "USDE"));

        // katana agglayer vbusdc bridge
        _addEthereumOVaultLeafsForDepositAndSend(
            leafs, getAddress(sourceChain, "USDC"), getAddress(sourceChain, "OVaultComposerForvbUSDC")
        );

        // morpho blue markets to supply
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "fxSAVE_USDC_86"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "srRoyUSDC_USDC_915"));

        // morpho blue markets to collateralise
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "syrupUSDC_RLUSD_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "syrupUSDC_PYUSD_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDS_USDT_965"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "sUSDe_PYUSD_915"));

        // uniswap v3
        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "USDE");
        token0[1] = getAddress(sourceChain, "RLUSD");
        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "USDC");
        token1[1] = getAddress(sourceChain, "USDC");
        _addUniswapV3Leafs(leafs, token0, token1, false, false);

        // royco junior usdc vault
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "USDC"));
        _addTellerLeafs(leafs, address(roycoJrUsdcTeller), assets, false, true);
        _addWithdrawQueueLeafs(leafs, roycoJrUsdcWithdrawQueue, roycoJrUsdcVault, assets);
        _addSelfSolveLeafs(leafs, assets, roycoJrUsdcQueueSolver, address(boringVault), roycoJrUsdcTeller);
    }
}
