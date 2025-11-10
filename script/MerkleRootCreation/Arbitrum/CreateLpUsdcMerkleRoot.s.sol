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
 */
contract CreateLpUsdcLeafs is Script, MerkleTreeHelper {
    uint256 public privateKey;

    address public rawDataDecoderAndSanitizerArbitrum01 = 0x16E9929986A16Db5d7D8CC058C17C62EB9b91431;
    RolesAuthority internal rolesAuthority = RolesAuthority(0x53d65Fd99ef140Cf8BAC854cC6a875B5799dE64C);
    BoringVault internal boringVault = BoringVault(payable(0xD7C89623Ad20DC34C6dcaa5E7Fc643bA2Ef5862C));
    LayerZeroTeller internal teller = LayerZeroTeller(0xA649fB494dCd061c944fb9Aa2F08955EcbaaF119);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0xB3b33923066D4235e89adEDA2D6Ea0AeeEe99565);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0xbc642454e070CF653F8fC6C1AD44361e7b0Cb497);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0xef59dA2853637Cc390545cB3234c3A45a26CAdB0);
    BoringSolver internal solver = BoringSolver(0xBf2d580797466eC5d60fe09C5e0938a27a8e5730);
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
        vm.createSelectFork("arbitrum");
        setSourceChainName("arbitrum");

        setAddress(true, arbitrum, "boringVault", address(boringVault));
        setAddress(true, arbitrum, "managerAddress", address(manager));
        setAddress(true, arbitrum, "manager", address(manager));
        setAddress(true, arbitrum, "accountantAddress", address(accountant));
        setAddress(true, arbitrum, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizerArbitrum01);
    }

    function run() public {
        ManageLeaf[] memory leafs = new ManageLeaf[](1024);
        _addLeafs(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Arbitrum/LpUsdcStrategistLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        vm.startBroadcast(privateKey);
        manager.setManageRoot(agent, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(0xa86b3Bf249478488B4304B50726c7D4689aD6320, manageTree[manageTree.length - 1][0]);
        manager.setManageRoot(getAddress(sourceChain, "managerAddress"), manageTree[manageTree.length - 1][0]);
        vm.stopBroadcast();
    }

    function _addLeafs(ManageLeaf[] memory leafs) internal {
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        ERC20[] memory bridgeAssets = new ERC20[](2);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        bridgeAssets[1] = getERC20(sourceChain, "USDT0");
        ERC20[] memory feeTokens = new ERC20[](2);
        feeTokens[0] = getERC20(sourceChain, "WETH");
        feeTokens[1] = getERC20(sourceChain, "GHO");

        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDC"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDT0"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "GYD"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "USDS"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));

        // Odos assets
        address[] memory oneInchAssets = new address[](6);
        oneInchAssets[0] = getAddress(sourceChain, "USDC");
        oneInchAssets[1] = getAddress(sourceChain, "WETH");
        oneInchAssets[2] = getAddress(sourceChain, "WBTC");
        oneInchAssets[3] = getAddress(sourceChain, "syrupUSDC");
        oneInchAssets[4] = getAddress(sourceChain, "USDS");
        oneInchAssets[5] = getAddress(sourceChain, "USDT0");
        SwapKind[] memory kind = new SwapKind[](6);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        kind[2] = SwapKind.BuyAndSell;
        kind[3] = SwapKind.BuyAndSell;
        kind[4] = SwapKind.BuyAndSell;
        kind[5] = SwapKind.BuyAndSell;
        _addOdosSwapLeafs(leafs, oneInchAssets, kind);

        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[0] = getERC20(sourceChain, "USDT0");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT0");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
    }
}
