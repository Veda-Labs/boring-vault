// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AaveV4FullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AaveV4FullDecoderAndSanitizer.sol";
import {AaveV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV4DecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

interface IAaveV4Spoke {
    function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
    function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);
    function getUserReserveStatus(uint256 reserveId, address user)
        external
        view
        returns (bool usingAsCollateral, bool borrowing);
}

contract AaveV4IntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
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

    // Reserve ids on the Aave V4 Main Spoke; supply/borrow ids are validated onchain during leaf
    // generation via _verifyAaveV4Reserve.
    uint256 internal constant WETH_RESERVE_ID = 0;
    uint256 internal constant WSTETH_RESERVE_ID = 1;
    // Any id not pinned by the leaf under test works here (7 is USDC on the Main Spoke; this
    // constant is never validated onchain).
    uint256 internal constant UNAUTHORIZED_RESERVE_ID = 7;
    // USDT on the Main Spoke. USDT is a nonstandard ERC20 (approve/transfer return no value;
    // approve reverts on a non-zero -> non-zero change), so it exercises those paths end to end.
    uint256 internal constant USDT_RESERVE_ID = 8;

    IAaveV4Spoke internal spoke;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 25100000;

        _startFork(rpcKey, blockNumber);

        spoke = IAaveV4Spoke(getAddress(sourceChain, "aaveV4MainSpoke"));

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new AaveV4FullDecoderAndSanitizer());

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

    function testAaveV4Integration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        uint256[] memory supplyReserveIds = new uint256[](1);
        supplyReserveIds[0] = WSTETH_RESERVE_ID;
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "WSTETH");
        uint256[] memory borrowReserveIds = new uint256[](1);
        borrowReserveIds[0] = WETH_RESERVE_ID;
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        _addAaveV4Leafs(leafs, supplyReserveIds, supplyAssets, borrowReserveIds, borrowAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Approve wstETH, approve WETH, supply wstETH, enable wstETH as collateral, borrow WETH.
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[4];
        manageLeafs[4] = leafs[5];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "WSTETH");
        targets[1] = getAddress(sourceChain, "WETH");
        targets[2] = getAddress(sourceChain, "aaveV4MainSpoke");
        targets[3] = getAddress(sourceChain, "aaveV4MainSpoke");
        targets[4] = getAddress(sourceChain, "aaveV4MainSpoke");

        bytes[] memory targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aaveV4MainSpoke"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aaveV4MainSpoke"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "supply(uint256,uint256,address)", WSTETH_RESERVE_ID, 1_000e18, address(boringVault)
        );
        targetData[3] = abi.encodeWithSignature(
            "setUsingAsCollateral(uint256,bool,address)", WSTETH_RESERVE_ID, true, address(boringVault)
        );
        targetData[4] =
            abi.encodeWithSignature("borrow(uint256,uint256,address)", WETH_RESERVE_ID, 100e18, address(boringVault));

        address[] memory decodersAndSanitizers = new address[](5);
        for (uint256 i; i < 5; ++i) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        uint256 hubWstEthBefore = getERC20(sourceChain, "WSTETH").balanceOf(getAddress(sourceChain, "aaveV4CoreHub"));

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](5)
        );

        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(WSTETH_RESERVE_ID, address(boringVault)),
            1_000e18,
            2,
            "vault should have supplied wstETH"
        );
        assertEq(
            getERC20(sourceChain, "WSTETH").balanceOf(getAddress(sourceChain, "aaveV4CoreHub")),
            hubWstEthBefore + 1_000e18,
            "supplied wstETH should be held by the Aave V4 core hub"
        );
        (bool usingAsCollateral,) = spoke.getUserReserveStatus(WSTETH_RESERVE_ID, address(boringVault));
        assertTrue(usingAsCollateral, "wstETH should be enabled as collateral");
        assertApproxEqAbs(
            spoke.getUserTotalDebt(WETH_RESERVE_ID, address(boringVault)), 100e18, 2, "vault should have WETH debt"
        );
        assertEq(
            getERC20(sourceChain, "WETH").balanceOf(address(boringVault)),
            1_100e18,
            "vault should have received borrowed WETH"
        );

        // Repay WETH, withdraw wstETH, refresh risk premium and dynamic config.
        manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[6];
        manageLeafs[1] = leafs[3];
        manageLeafs[2] = leafs[7];
        manageLeafs[3] = leafs[8];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](4);
        for (uint256 i; i < 4; ++i) {
            targets[i] = getAddress(sourceChain, "aaveV4MainSpoke");
        }

        targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "repay(uint256,uint256,address)", WETH_RESERVE_ID, type(uint256).max, address(boringVault)
        );
        targetData[1] = abi.encodeWithSignature(
            "withdraw(uint256,uint256,address)", WSTETH_RESERVE_ID, type(uint256).max, address(boringVault)
        );
        targetData[2] = abi.encodeWithSignature("updateUserRiskPremium(address)", address(boringVault));
        targetData[3] = abi.encodeWithSignature("updateUserDynamicConfig(address)", address(boringVault));

        decodersAndSanitizers = new address[](4);
        for (uint256 i; i < 4; ++i) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](4)
        );

        assertEq(spoke.getUserTotalDebt(WETH_RESERVE_ID, address(boringVault)), 0, "vault WETH debt should be repaid");
        assertEq(
            spoke.getUserSuppliedAssets(WSTETH_RESERVE_ID, address(boringVault)),
            0,
            "vault wstETH supply should be withdrawn"
        );
        assertApproxEqAbs(
            getERC20(sourceChain, "WSTETH").balanceOf(address(boringVault)),
            1_000e18,
            2,
            "vault should have its wstETH back"
        );
        assertApproxEqAbs(
            getERC20(sourceChain, "WETH").balanceOf(address(boringVault)),
            1_000e18,
            2,
            "vault should have repaid all borrowed WETH"
        );
    }

    function testAaveV4IntegrationReverts() external {
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        uint256[] memory supplyReserveIds = new uint256[](1);
        supplyReserveIds[0] = WSTETH_RESERVE_ID;
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "WSTETH");
        uint256[] memory borrowReserveIds = new uint256[](1);
        borrowReserveIds[0] = WETH_RESERVE_ID;
        ERC20[] memory borrowAssets = new ERC20[](1);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        _addAaveV4Leafs(leafs, supplyReserveIds, supplyAssets, borrowReserveIds, borrowAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // The supply leaf pins (reserveId, onBehalfOf), so supplying a different reserve id with
        // the wstETH supply proof must fail verification.
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "aaveV4MainSpoke");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "supply(uint256,uint256,address)", UNAUTHORIZED_RESERVE_ID, 1_000e18, address(boringVault)
        );

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                0
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );

        // Supplying on behalf of an address other than the boring vault must also fail verification.
        targetData[0] =
            abi.encodeWithSignature("supply(uint256,uint256,address)", WSTETH_RESERVE_ID, 1_000e18, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                0
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );

        // A reserveId aliasing the pinned one under uint160 truncation (id + 2^160 packs to the
        // same 20 bytes) must be rejected by the decoder before proof verification.
        targetData[0] = abi.encodeWithSignature(
            "supply(uint256,uint256,address)", WSTETH_RESERVE_ID + (uint256(1) << 160), 1_000e18, address(boringVault)
        );

        vm.expectRevert(AaveV4DecoderAndSanitizer.AaveV4DecoderAndSanitizer__InvalidReserveId.selector);
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );

        // The shared _sanitizeReserveId guard covers every reserve function; exercise a second
        // path (withdraw) to keep the mechanism pinned by tests.
        manageLeafs[0] = leafs[3];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
        targetData[0] = abi.encodeWithSignature(
            "withdraw(uint256,uint256,address)", WSTETH_RESERVE_ID + (uint256(1) << 160), 1_000e18, address(boringVault)
        );

        vm.expectRevert(AaveV4DecoderAndSanitizer.AaveV4DecoderAndSanitizer__InvalidReserveId.selector);
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    function testAaveV4SuppliesAndWithdrawsUsdt() external {
        // Full supply + withdraw of real USDT through the decoder + merkle + live spoke. USDT's
        // approve()/transfer() return no value, so this proves the vault drives them correctly.
        ERC20 usdt = getERC20(sourceChain, "USDT");
        uint256 supplyAmount = 100_000e6; // USDT has 6 decimals
        deal(address(usdt), address(boringVault), supplyAmount);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        uint256[] memory supplyReserveIds = new uint256[](1);
        supplyReserveIds[0] = USDT_RESERVE_ID;
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = usdt;
        uint256[] memory borrowReserveIds = new uint256[](0);
        ERC20[] memory borrowAssets = new ERC20[](0);
        _addAaveV4Leafs(leafs, supplyReserveIds, supplyAssets, borrowReserveIds, borrowAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // leafs[0] = approve USDT to spoke, leafs[1] = supply USDT, leafs[2] = withdraw USDT.
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(usdt);
        targets[1] = getAddress(sourceChain, "aaveV4MainSpoke");
        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aaveV4MainSpoke"), supplyAmount
        );
        targetData[1] = abi.encodeWithSignature(
            "supply(uint256,uint256,address)", USDT_RESERVE_ID, supplyAmount, address(boringVault)
        );
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](2)
        );

        assertApproxEqAbs(
            spoke.getUserSuppliedAssets(USDT_RESERVE_ID, address(boringVault)),
            supplyAmount,
            2,
            "vault should have supplied USDT"
        );
        assertEq(usdt.balanceOf(address(boringVault)), 0, "vault should have no idle USDT after supply");

        // Withdraw everything back to the vault.
        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "aaveV4MainSpoke");
        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "withdraw(uint256,uint256,address)", USDT_RESERVE_ID, type(uint256).max, address(boringVault)
        );
        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );

        assertApproxEqAbs(usdt.balanceOf(address(boringVault)), supplyAmount, 3, "vault should have its USDT back");
        assertEq(
            spoke.getUserSuppliedAssets(USDT_RESERVE_ID, address(boringVault)), 0, "USDT position should be closed"
        );
    }

    function testFuzz_AaveV4DecoderRejectsOutOfRangeReserveId(uint256 reserveId) external {
        // Any reserveId that does not fit in 160 bits must be rejected before proof verification,
        // so it can never alias a pinned id once cast to an address.
        reserveId = bound(reserveId, uint256(type(uint160).max) + 1, type(uint256).max);
        vm.expectRevert(AaveV4DecoderAndSanitizer.AaveV4DecoderAndSanitizer__InvalidReserveId.selector);
        AaveV4DecoderAndSanitizer(rawDataDecoderAndSanitizer).supply(reserveId, 0, address(boringVault));
    }

    function testFuzz_AaveV4DecoderPinsReserveIdAndOnBehalfOf(uint160 reserveId, uint256 amount, address onBehalfOf)
        external
    {
        // Every reserve function commits (reserveId-as-address, onBehalfOf) and nothing else, so a
        // wrong reserve or a non-vault onBehalfOf produces different bytes and fails verification.
        bytes memory expected = abi.encodePacked(address(reserveId), onBehalfOf);
        assertEq(
            AaveV4DecoderAndSanitizer(rawDataDecoderAndSanitizer).supply(reserveId, amount, onBehalfOf),
            expected,
            "supply must pin reserveId + onBehalfOf"
        );
        assertEq(
            AaveV4DecoderAndSanitizer(rawDataDecoderAndSanitizer).withdraw(reserveId, amount, onBehalfOf),
            expected,
            "withdraw must pin reserveId + onBehalfOf"
        );
        assertEq(
            AaveV4DecoderAndSanitizer(rawDataDecoderAndSanitizer).borrow(reserveId, amount, onBehalfOf),
            expected,
            "borrow must pin reserveId + onBehalfOf"
        );
        assertEq(
            AaveV4DecoderAndSanitizer(rawDataDecoderAndSanitizer).repay(reserveId, amount, onBehalfOf),
            expected,
            "repay must pin reserveId + onBehalfOf"
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
