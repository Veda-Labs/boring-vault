// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {LombardBTCocDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LombardBTCocDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract LombardBTCocIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant STRATEGIST_ROLE = 11;

    address public constant strategist = 0x653d5c6CEf72822e7C409ecB5c46C5c2858E5F2A;

    address public lbtc;
    address public btcOc;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 25481712;

        _startFork(rpcKey, blockNumber);

        // LBTCv, the real deployed BoringVault on mainnet.
        boringVault = BoringVault(payable(getAddress(sourceChain, "LBTCv")));

        // The real deployed manager for LBTCv.
        manager = ManagerWithMerkleVerification(0xcf38e37872748E3b66741A42560672A6cef75e9B);

        rawDataDecoderAndSanitizer = address(new LombardBTCocDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        lbtc = getAddress(sourceChain, "LBTC");
        btcOc = getAddress(sourceChain, "BTCoc");

        rolesAuthority = RolesAuthority(address(manager.authority()));
    }

    function testLombardBTCocDepositAndRequestRedeem() external {
        uint256 lbtcBalance = ERC20(lbtc).balanceOf(address(boringVault));
        assertGt(lbtcBalance, 0, "boringVault should already hold LBTC");

        uint256 depositAmount = lbtcBalance / 2;

        // Leafs array size must be a power of two for the merkle tree builder; unused slots
        // stay zeroed and are simply not referenced when building proofs.
        ManageLeaf[] memory leafs = new ManageLeaf[](4);

        // Resets the shared leafIndex counter used by MerkleTreeHelper's `_add*Leafs` helpers.
        leafIndex = type(uint256).max;

        // Adds: [0] approve BTCoc to spend LBTC, [1] deposit(address,uint256,address),
        // [2] requestRedeem(uint256,address).
        _addLombardBTCocLeafs(leafs, lbtc, btcOc);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        vm.prank(rolesAuthority.owner());
        manager.setManageRoot(strategist, manageTree[manageTree.length - 1][0]);

        // ---- deposit ----
        ManageLeaf[] memory depositLeafs = new ManageLeaf[](2);
        depositLeafs[0] = leafs[0]; // approve
        depositLeafs[1] = leafs[1]; // deposit

        bytes32[][] memory depositProofs = _getProofsUsingTree(depositLeafs, manageTree);

        address[] memory depositTargets = new address[](2);
        depositTargets[0] = lbtc;
        depositTargets[1] = btcOc;

        bytes[] memory depositData = new bytes[](2);
        depositData[0] = abi.encodeWithSelector(ERC20.approve.selector, btcOc, depositAmount);
        depositData[1] =
            abi.encodeWithSignature("deposit(address,uint256,address)", lbtc, depositAmount, address(boringVault));

        uint256[] memory depositValues = new uint256[](2);

        address[] memory depositDecodersAndSanitizers = new address[](2);
        depositDecodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        depositDecodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(
            depositProofs, depositDecodersAndSanitizers, depositTargets, depositData, depositValues
        );

        uint256 lbtcBalanceAfter = ERC20(lbtc).balanceOf(address(boringVault));
        assertEq(lbtcBalanceAfter, lbtcBalance - depositAmount, "LBTC should have been deposited into BTCoc");

        uint256 btcOcShares = ERC20(btcOc).balanceOf(address(boringVault));
        assertGt(btcOcShares, 0, "boringVault should have received BTCoc shares");

        // ---- requestRedeem ----
        ManageLeaf[] memory redeemLeafs = new ManageLeaf[](1);
        redeemLeafs[0] = leafs[2];

        bytes32[][] memory redeemProofs = _getProofsUsingTree(redeemLeafs, manageTree);

        address[] memory redeemTargets = new address[](1);
        redeemTargets[0] = btcOc;

        bytes[] memory redeemData = new bytes[](1);
        redeemData[0] = abi.encodeWithSignature("requestRedeem(uint256,address)", btcOcShares, address(boringVault));

        uint256[] memory redeemValues = new uint256[](1);

        address[] memory redeemDecodersAndSanitizers = new address[](1);
        redeemDecodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.prank(strategist);
        manager.manageVaultWithMerkleVerification(
            redeemProofs, redeemDecodersAndSanitizers, redeemTargets, redeemData, redeemValues
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
