// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UsualMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UsualMoneyDecoderAndSanitizer.sol";
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract UsualMoneyIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21495090;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidUsdDecoderAndSanitizer(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"))
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

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

    function testUsualMoneyIntegration() external {
        uint256 mintAmount = 100_000e18;
        //mintAmount = bound(mintAmount, 1e18, 1_000_000e18);
        deal(getAddress(sourceChain, "USD0"), address(boringVault), mintAmount);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e8);

        uint256 usdcBalance = getERC20(sourceChain, "USDC").balanceOf(address(boringVault));
        console.log("USDC balance", usdcBalance);
        assertGt(usdcBalance, 0);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addUsualMoneyLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //approve
        manageLeafs[2] = leafs[2]; //approve
        manageLeafs[3] = leafs[3]; //wrap
        manageLeafs[4] = leafs[4]; //unlock@floor
        //manageLeafs[4] = leafs[5]; //unwrap -> skip
        manageLeafs[5] = leafs[6]; //deposit
        manageLeafs[6] = leafs[7]; //provide
        manageLeafs[7] = leafs[8]; //swap
        manageLeafs[8] = leafs[9]; //withdraw

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](9);
        targets[0] = getAddress(sourceChain, "USD0"); //approve usd0pp
        targets[1] = getAddress(sourceChain, "USD0"); //approve swapper
        targets[2] = getAddress(sourceChain, "USDC"); //approve swapper
        targets[3] = getAddress(sourceChain, "USD0_plus"); //wrap
        targets[4] = getAddress(sourceChain, "USD0_plus"); //unlock@floor
        targets[5] = getAddress(sourceChain, "usualSwapperEngine"); //depositUSDC
        targets[6] = getAddress(sourceChain, "usualSwapperEngine"); //provideUsd0
        targets[7] = getAddress(sourceChain, "usualSwapperEngine"); //swapUsd0
        targets[8] = getAddress(sourceChain, "usualSwapperEngine"); //withdrawUSDC

        uint256[] memory orderIds = new uint256[](1);
        orderIds[0] = ISwapperEngine(getAddress(sourceChain, "usualSwapperEngine")).getNextOrderId();
        console.log("order id", orderIds[0]);

        bytes[] memory targetData = new bytes[](9);
        targetData[0] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "USD0_plus"), type(uint256).max);
        targetData[1] = abi.encodeWithSelector(
            ERC20.approve.selector, getAddress(sourceChain, "usualSwapperEngine"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSelector(
            ERC20.approve.selector, getAddress(sourceChain, "usualSwapperEngine"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature("mint(uint256)", 100e18);
        targetData[4] = abi.encodeWithSignature("unlockUsd0ppFloorPrice(uint256)", 10e18);
        targetData[5] = abi.encodeWithSignature("depositUSDC(uint256)", 100_000e6);
        targetData[6] = abi.encodeWithSignature(
            "provideUsd0ReceiveUSDC(address,uint256,uint256[],bool)", address(boringVault), 10_000e6, orderIds, false
        );
        targetData[7] = abi.encodeWithSignature(
            "swapUsd0(address,uint256,uint256[],bool)", address(boringVault), 10_000e18, orderIds, false
        );
        targetData[8] = abi.encodeWithSignature("withdrawUSDC(uint256)", orderIds[0]);

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

        assertGt(
            ERC20(getAddress(sourceChain, "USD0_plus")).balanceOf(address(boringVault)),
            0,
            "BoringVault should have minted USD0++"
        );
        console.log("USD0 in: ", mintAmount);
        console.log("USO0++ Balance: ", ERC20(getAddress(sourceChain, "USD0_plus")).balanceOf(address(boringVault)));

        // After 4 years the USD0++ can be unwrapped for USD0.
        skip(4 * 365 days);

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[5]; // unwrap

        (manageProofs) = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "USD0_plus");

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("unwrap()");

        values = new uint256[](1);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        uint256 fee = 5e15;
        assertEq(
            ERC20(getAddress(sourceChain, "USD0")).balanceOf(address(boringVault)),
            mintAmount - fee,
            "BoringVault should have unwrapped USD0++ and received principal back minus floor price unlock dif"
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullUsualMoneyDecoderAndSanitizer is UsualMoneyDecoderAndSanitizer {}

interface ISwapperEngine {
    function getNextOrderId() external view returns (uint256);
}
