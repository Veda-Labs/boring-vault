// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {CompoundV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CompoundV2DecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CompoundV2IntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("flare");
        // Setup forked environment.
        string memory rpcKey = "FLARE_RPC_URL";
        uint256 blockNumber = 40871926; // Block where USDT0 borrows are enabled and there is still cap remaining

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullCompoundV2DecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testCompoundV2ForkIntegration() external {
        uint256 assets = 10_000e6;
        deal(getAddress(sourceChain, "USDT0"), address(boringVault), assets);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory collateralAssets = new ERC20[](1);
        collateralAssets[0] = ERC20(getAddress(sourceChain, "USDT0"));
        address[] memory cTokens = new address[](1);
        cTokens[0] = getAddress(sourceChain, "kUSDT0");
        address unitroller = getAddress(sourceChain, "kineticUnitroller");
        _addCompoundV2Leafs(leafs, collateralAssets, cTokens, unitroller);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[4];
        manageLeafs[4] = leafs[3];
        manageLeafs[5] = leafs[5];
        manageLeafs[6] = leafs[6];
        manageLeafs[7] = leafs[7];
        manageLeafs[8] = leafs[8];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](9);
        targets[0] = getAddress(sourceChain, "kineticUnitroller");
        targets[1] = getAddress(sourceChain, "USDT0");
        targets[2] = getAddress(sourceChain, "kUSDT0");
        targets[3] = getAddress(sourceChain, "kUSDT0");
        targets[4] = getAddress(sourceChain, "kUSDT0");
        targets[5] = getAddress(sourceChain, "kUSDT0");
        targets[6] = getAddress(sourceChain, "kUSDT0");
        targets[7] = getAddress(sourceChain, "kineticUnitroller");
        targets[8] = getAddress(sourceChain, "kineticUnitroller");

        address[] memory markets = new address[](1);
        markets[0] = getAddress(sourceChain, "kUSDT0");
        bytes[] memory targetData = new bytes[](9);
        targetData[0] = abi.encodeWithSignature("enterMarkets(address[])", markets);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "kUSDT0"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature("mint(uint256)", 1e6);
        targetData[3] = abi.encodeWithSignature("borrow(uint256)", 4e5);
        targetData[4] = abi.encodeWithSignature("repayBorrow(uint256)", 4e5);
        targetData[5] = abi.encodeWithSignature("redeem(uint256)", 4e5);
        targetData[6] = abi.encodeWithSignature("redeemUnderlying(uint256)", 4e5);
        targetData[7] = abi.encodeWithSignature("claimReward(uint8,address)", 1, getAddress(sourceChain, "boringVault"));
        targetData[8] = abi.encodeWithSignature("exitMarket(address)", getAddress(sourceChain, "kUSDT0"));

        uint256[] memory values = new uint256[](9);

        address[] memory decodersAndSanitizers = new address[](9);

        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testCompoundV2ForkIntegrationNativeAsset() external {
        uint256 assets = 10_000e18;
        deal(address(boringVault), assets);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory collateralAssets = new ERC20[](1);
        collateralAssets[0] = ERC20(getAddress(sourceChain, "FLR"));
        address[] memory cTokens = new address[](1);
        cTokens[0] = getAddress(sourceChain, "isoFLR");
        address unitroller = getAddress(sourceChain, "isoUnitroller");

        // allow borrowing
        uint256[] memory borrowCaps = new uint256[](1);
        borrowCaps[0] = 10_000_000e18;
        vm.prank(0x37C6C7c719DB93085678cE72981CDd96219C9B72);
        IUnitroller(unitroller)._setMarketBorrowCaps(cTokens, borrowCaps);

        _addCompoundV2Leafs(leafs, collateralAssets, cTokens, unitroller);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[3];
        manageLeafs[3] = leafs[2];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "isoUnitroller");
        targets[1] = getAddress(sourceChain, "isoFLR");
        targets[2] = getAddress(sourceChain, "isoFLR");
        targets[3] = getAddress(sourceChain, "isoFLR");

        address[] memory markets = new address[](1);
        markets[0] = getAddress(sourceChain, "isoFLR");
        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature("enterMarkets(address[])", markets);
        targetData[1] = abi.encodeWithSignature("mint()");
        targetData[2] = abi.encodeWithSignature("borrow(uint256)", 4e17);
        targetData[3] = abi.encodeWithSignature("repayBorrow()");

        uint256[] memory values = new uint256[](4);
        values[1] = 1e18;
        values[3] = 4e17;

        address[] memory decodersAndSanitizers = new address[](4);

        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullCompoundV2DecoderAndSanitizer is CompoundV2DecoderAndSanitizer {}

interface IUnitroller {
    function _setMarketBorrowCaps(address[] memory cTokens, uint256[] memory newBorrowCaps) external;
}
