// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

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
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {MorphoFlashLoanAdapter} from "src/base/Roles/MorphoFlashLoan/MorphoFlashLoanAdapter.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify --with-gas-price 30000000000
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract CreateInfiniUsdcClusterLeafs is Script, MerkleTreeHelper {
    uint256 public privateKey;

    address public rawDataDecoderAndSanitizerEthereum = 0xcACfF0b03e1f468D810840e0F4033895e8737AE1;
    RolesAuthority internal rolesAuthority = RolesAuthority(0xF312FC97f7552299cd581C9238768D435A8B00B8);
    BoringVault internal boringVault = BoringVault(payable(0x96Ee83F0C132A8b29866c8Ae6E149D6e6822b291));
    LayerZeroTeller internal teller = LayerZeroTeller(0x9A12D5A30F4c0fB13a5D5a00CD24f47909F9E96C);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x617f47CC5021607a46d9d76942d8103d5cc47175);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x2E6B1bA9CdE7fAD66E34122ad744c3B004adAdaF);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0x9374D182818A46019b10b62d7d8F55f7298090C4);
    BoringSolver internal solver = BoringSolver(0xAa2530BACD753694b374B2004d20EdC50071ebDe);
    MorphoFlashLoanAdapter internal flashLoanAdapter =
        MorphoFlashLoanAdapter(0xcd89d9f48dD6C318e59AED84473bF011bed4ECE5);

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
    }
}
