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
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ForkAaveBorrowPositionIntegration is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    address public rawDataDecoderAndSanitizer;
    RolesAuthority internal rolesAuthority = RolesAuthority(0xf7F3ace7f6cA2Cb1E7ccbE3Bf2Da13D001D36fdF);
    BoringVault internal boringVault = BoringVault(payable(0x279CAD277447965AF3d24a78197aad1B02a2c589));
    LayerZeroTeller internal teller = LayerZeroTeller(0xaefc11908fF97c335D16bdf9F2Bf720817423825);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x9B3e565ffC70c4b72516BC2dbec4b3c790940CE8);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x03D9a9cE13D16C7cFCE564f41bd7E85E5cde8Da6);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0xF632c10b19f2a0451cD4A653fC9ca0c15eA1040b);
    BoringSolver internal solver = BoringSolver(0x1d82e9bCc8F325caBBca6E6A3B287fE586536805);

    /// roles
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
        setSourceChainName("mainnet");
        vm.createSelectFork(sourceChain);

        rawDataDecoderAndSanitizer = address(
            new SyUsdDecoderAndSanitizer(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"), getAddress(sourceChain, "odosRouterV2")
            )
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(accountant));

        vm.startPrank(rolesAuthority.owner());
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(manager), manager.manageVaultWithMerkleVerification.selector, true
        );
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        vm.stopPrank();
    }

    function testAaveBorrow() external {
        uint256 flashloanAmount = 100_000 * 1e6; // 100k USDC
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100_000e6);
        deal(getAddress(sourceChain, "SUSDE"), address(boringVault), 100_000e18);

        // create ManageLeaf array for all operations
        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "SUSDE");
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        vm.prank(manager.owner());
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = ManageLeaf(
            getAddress(sourceChain, "SUSDE"),
            false,
            "approve(address,uint256)",
            new address[](1),
            "",
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        manageLeafs[0].argumentAddresses[0] = getAddress(sourceChain, "v3Pool");

        manageLeafs[1] = ManageLeaf(
            getAddress(sourceChain, "v3Pool"),
            false,
            "supply(address,uint256,address,uint16)",
            new address[](2),
            string.concat("Supply ", getERC20(sourceChain, "SUSDE").symbol(), " to Aave V3"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        manageLeafs[1].argumentAddresses[0] = getAddress(sourceChain, "SUSDE");
        manageLeafs[1].argumentAddresses[1] = getAddress(sourceChain, "boringVault");

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "SUSDE");
        targets[1] = getAddress(sourceChain, "v3Pool");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "v3Pool"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "supply(address,uint256,address,uint16)",
            getAddress(sourceChain, "SUSDE"),
            1000e18,
            getAddress(sourceChain, "boringVault"),
            0
        );

        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = getAddress(sourceChain, "rawDataDecoderAndSanitizer");
        decodersAndSanitizers[1] = getAddress(sourceChain, "rawDataDecoderAndSanitizer");

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function _logLeafInfo(ManageLeaf memory leaf) internal pure {
        console.log("target:", leaf.target);
        console.log("canSendValue:", leaf.canSendValue);
        console.log("signature:", leaf.signature);
        for (uint256 i; i < leaf.argumentAddresses.length; i++) {
            console.log(
                string.concat("argumentAddresses[", vm.toString(i), "]: ", vm.toString(leaf.argumentAddresses[i]))
            );
        }
        console.log("description:", leaf.description);
        console.log("decoderAndSanitizer:", leaf.decoderAndSanitizer);
    }
}
