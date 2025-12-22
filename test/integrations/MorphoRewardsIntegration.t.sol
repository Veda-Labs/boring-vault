// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { MainnetAddresses } from "test/resources/MainnetAddresses.sol";
import { BoringVault } from "src/base/BoringVault.sol";
import { ManagerWithMerkleVerification } from "src/base/Roles/ManagerWithMerkleVerification.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { MorphoRewardsDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/MorphoRewardsDecoderAndSanitizer.sol";
import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { RolesAuthority, Authority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

contract MorphoRewardsIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 21_537_952;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new MorphoRewardsDecoderAndSanitizer());

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
    }

    function testMorphoRewardsWrapperIntegration() external {
        deal(getAddress(sourceChain, "legacyMorpho"), address(boringVault), 1000e18);

        // approve
        // Call deposit
        // withdraw
        // complete withdraw
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addMorphoRewardWrapperLeafs(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "legacyMorpho");
        targets[1] = getAddress(sourceChain, "newMorpho");
        targets[2] = getAddress(sourceChain, "morphoRewardsWrapper");
        targets[3] = getAddress(sourceChain, "morphoRewardsWrapper");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "morphoRewardsWrapper"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "morphoRewardsWrapper"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature("depositFor(address,uint256)", boringVault, 1000e18);
        targetData[3] = abi.encodeWithSignature("withdrawTo(address,uint256)", boringVault, 1000e18);

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            getERC20(sourceChain, "legacyMorpho").balanceOf(address(boringVault)),
            1000e18,
            "BoringVault should have received 1,000 legacyMorpho"
        );
    }

    function testMorphoMerkleClaimerIntegration() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        address universalRewardsDistributor = 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb;
        address userReceivingMorpho = 0xcf4B531b4Cde95BD35d71926e09B2b54c564F5b6;
        setAddress(true, sourceChain, "boringVault", userReceivingMorpho);
        _addMorphoRewardMerkleClaimerLeafs(leafs, universalRewardsDistributor);
        setAddress(true, sourceChain, "boringVault", address(boringVault));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = universalRewardsDistributor;
        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            hex"fabed412000000000000000000000000cf4b531b4cde95bd35d71926e09b2b54c564f5b600000000000000000000000058d97b57bb95320f9a05dc918aef65434969c2b20000000000000000000000000000000000000000000000240511b9b76daebc110000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000f8082e09b6e1ff0c1a969249acec541e7f55f6119c43c82f87a9d2989e3232ab0e2051f811587dac8550a43f6ab4fb88c58b0427cb476157f4efe530fe5a3eecc5bcb0ed9fe3bb36e5b901ea1247e5135d8a24cea05bdb821fe28437fbc36dac40018f6389e7fdb40b66fc185f81387a5c343ebb34e8f8607044e83b7734646042cdb1de2c09c79321dafcedaf2599a82bbec4fbb9cbc4cccd055500c124f0e4c862d0cc96b504959625cf8c30cdee2a37e278cd919ee16896f3735c9e37103729f7f6c345cd33dd8061aa8762f5ded1f59b1c3d30cd09905112e52a31c1fbf3bea226f2b7731919697909544d91e18b42141c0335183bd23b6fc82df0052537f080f776e443978c45dd1f33390ff2f0b05fc183e68d47119dc541c95eb713c397d525c2949be0bb10fce9e93bf13e35b813fcb786bf3de2d0db3c3fa6d8235d7f34ee9235c2daabd02926c2c6550eddb54bf87acb183630b48573916875981a09e3f05fd0ecfd82da370ba9509d5c3e995834d1d076f02a530df9aa737a3ad9fd6813ffc3e1e45b519242e9de66708409d97b679ac4975e4e8205df55f604b28e76b43435be2a82a9431d9ba85ebe30596aaf3d3860f91e6fddc08e02d24024ac22d4b728dfda32860dbe7f45f52480e5290f139e48ff75ebb367b5f344a1c3c";

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);
        ERC20 morpho = getERC20(sourceChain, "newMorpho");
        uint256 morphoBalance = morpho.balanceOf(userReceivingMorpho);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(
            morpho.balanceOf(userReceivingMorpho),
            morphoBalance + 664.448063895807900689e18,
            "User should have received 664.448063895807900689 morpho"
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
