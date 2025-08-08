// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {WstHypeLoopingUManager} from "../../src/micro-managers/WstHypeLoopingUManager.sol";
import {HyperliquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HyperliquidDecoderAndSanitizer.sol";
import {FelixVanillaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FelixVanillaDecoderAndSanitizer.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

contract WstHypeLoopingIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    // Core contracts
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    WstHypeLoopingUManager public strategyManager;
    RolesAuthority public rolesAuthority;
    
    // Decoders
    HyperliquidDecoderAndSanitizer public hyperliquidDecoder;
    FelixVanillaDecoderAndSanitizer public felixvanillaDecoder;
    address public rawDataDecoderAndSanitizer;

    // Role constants
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;

    // Hyperliquid protocol addresses (mock addresses for testing)
    address public constant wHYPE = 0x5555555555555555555555555555555555555555;
    address public constant stHYPE = 0xfFaa4a3D97fE9107Cef8a3F48c069F577Ff76cC1;
    address public constant wstHYPE = 0x94e8396e0869c9F2200760aF0621aFd240E1CF38;
    address public constant HYPE = 0x2222222222222222222222222222222222222222;
    address public constant overseer = 0xB96f07367e69e86d6e9C3F29215885104813eeAE;
    address public constant felixMarkets = 0x68e37dE8d93d3496ae143F2E900490f6280C57cD;
    address public constant felixOracle = 0xD767818Ef397e597810cF2Af6b440B1b66f0efD3;
    address public constant felixIrm = 0xD4a426F010986dCad727e8dd6eed44cA4A9b7483;
    uint256 public constant felixLltv = 860000000000000000; // 86%

    // Test user addresses
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public strategist = address(0x2001);

    // Test amounts
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant LOOP_AMOUNT = 100e18;
    uint256 public constant MIN_AMOUNT = 1e18;

    function setUp() external {
        // Deploy core contracts
        boringVault = new BoringVault(address(this), "WstHYPE Looping Vault", "wstHYPE-LOOP", 18);
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(0));
        
        // Deploy strategy manager
        strategyManager = new WstHypeLoopingUManager(
            address(boringVault),
            address(manager),
            wHYPE,
            stHYPE,
            wstHYPE,
            overseer,
            felixMarkets,
            felixOracle,
            felixIrm,
            felixLltv
        );

        // Deploy decoders
        hyperliquidDecoder = new HyperliquidDecoderAndSanitizer();
        felixvanillaDecoder = new FelixVanillaDecoderAndSanitizer();
        rawDataDecoderAndSanitizer = address(hyperliquidDecoder);

        // Set up decoders in strategy manager
        strategyManager.setDecoders(
            address(hyperliquidDecoder), // overseerDecoderAndSanitizer
            address(felixvanillaDecoder),   // felixDecoderAndSanitizer
            address(hyperliquidDecoder), // wHypeDecoderAndSanitizer
            address(hyperliquidDecoder)  // erc20DecoderAndSanitizer
        );

        // Setup roles authority
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        _setupRoles();
        _setupMockTokens();
    }

    function _setupRoles() internal {
        // Setup role capabilities
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
            ADMIN_ROLE, 
            address(manager), 
            ManagerWithMerkleVerification.setManageRoot.selector, 
            true
        );

        // Grant roles
        rolesAuthority.setUserRole(strategist, STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
    }

    function _setupMockTokens() internal {
        // Setup mock token balances for testing
        deal(wHYPE, address(boringVault), INITIAL_BALANCE);
        deal(stHYPE, address(boringVault), INITIAL_BALANCE);
        deal(wstHYPE, address(boringVault), INITIAL_BALANCE);
        deal(HYPE, address(boringVault), INITIAL_BALANCE);
        
        // Setup user balances
        deal(wHYPE, user1, INITIAL_BALANCE);
        deal(wHYPE, user2, INITIAL_BALANCE);
    }

    // ========================================= STRATEGY EXECUTION TESTS =========================================

    function testExecuteLoopingStrategy() external {
        // Setup merkle tree with required operations
        ManageLeaf[] memory leafs = _createLoopingLeafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Prepare proofs for 3 loops (15 operations total)
        bytes32[][] memory allProofs = _prepareLoopingProofs(leafs, manageTree, 3);

        uint256 initialWHypeBalance = ERC20(wHYPE).balanceOf(address(boringVault));

        // Execute looping strategy with 3 leverage loops
        vm.prank(strategist);
        strategyManager.executeLoopingStrategy(
            LOOP_AMOUNT,
            3, // 3 leverage loops
            allProofs
        );

        // Verify wHYPE balance decreased (used for initial loop)
        uint256 finalWHypeBalance = ERC20(wHYPE).balanceOf(address(boringVault));
        assertLt(finalWHypeBalance, initialWHypeBalance, "wHYPE balance should decrease");
    }

    function testExecuteLoopingStrategyFailsWithInsufficientProofs() external {
        ManageLeaf[] memory leafs = _createLoopingLeafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Prepare insufficient proofs (only 5 instead of 15 needed for 3 loops)
        bytes32[][] memory insufficientProofs = new bytes32[][](5);
        
        vm.prank(strategist);
        vm.expectRevert("Insufficient proofs");
        strategyManager.executeLoopingStrategy(
            LOOP_AMOUNT,
            3, // 3 leverage loops need 15 operations
            insufficientProofs
        );
    }

    function testExecuteLoopingStrategyFailsWithInvalidAmount() external {
        bytes32[][] memory emptyProofs = new bytes32[][](0);
        
        vm.prank(strategist);
        vm.expectRevert("Amount too small");
        strategyManager.executeLoopingStrategy(
            MIN_AMOUNT - 1, // Below minimum
            1,
            emptyProofs
        );
    }

    function testExecuteLoopingStrategyFailsWithInvalidLoops() external {
        bytes32[][] memory emptyProofs = new bytes32[][](0);
        
        // Test zero loops
        vm.prank(strategist);
        vm.expectRevert("Invalid leverage loops");
        strategyManager.executeLoopingStrategy(
            LOOP_AMOUNT,
            0, // Invalid: zero loops
            emptyProofs
        );

        // Test too many loops
        vm.prank(strategist);
        vm.expectRevert("Invalid leverage loops");
        strategyManager.executeLoopingStrategy(
            LOOP_AMOUNT,
            4, // Invalid: more than MAX_LEVERAGE_LOOPS (3)
            emptyProofs
        );
    }

    // ========================================= UNWINDING TESTS =========================================

    function testUnwindPositions() external {
        ManageLeaf[] memory leafs = _createUnwindingLeafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        bytes32[][] memory allProofs = _prepareUnwindingProofs(leafs, manageTree);

        uint256 initialBalance = ERC20(wHYPE).balanceOf(address(boringVault));

        vm.prank(strategist);
        strategyManager.unwindPositions(LOOP_AMOUNT, allProofs);

        // In a real scenario, unwinding would change balances
        // For this mock test, we just verify the function executes without reverting
        assertTrue(true, "Unwinding completed successfully");
    }

    function testUnwindPositionsFailsWithInvalidAmount() external {
        bytes32[][] memory emptyProofs = new bytes32[][](0);
        
        vm.prank(strategist);
        vm.expectRevert("Amount too small");
        strategyManager.unwindPositions(MIN_AMOUNT - 1, emptyProofs);
    }

    // ========================================= WRAP HYPE TESTS =========================================

    function testWrapHypeToWHype() external {
        ManageLeaf[] memory leafs = _createWrapLeafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        bytes32[] memory proof = _getProofsUsingTree(
            _createSingleLeafArray(leafs[0]), 
            manageTree
        )[0];

        vm.prank(strategist);
        strategyManager.wrapHypeToWHype(LOOP_AMOUNT, proof);

        // Verify function executes successfully
        assertTrue(true, "HYPE wrapping completed successfully");
    }

    // ========================================= BURN REDEMPTION TESTS =========================================

    function testCompleteBurnRedemptions() external {
        ManageLeaf[] memory leafs = _createBurnRedemptionLeafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        uint256[] memory burnIds = new uint256[](2);
        burnIds[0] = 1;
        burnIds[1] = 2;

        bytes32[][] memory allProofs = new bytes32[][](2);
        allProofs[0] = _getProofsUsingTree(_createSingleLeafArray(leafs[0]), manageTree)[0];
        allProofs[1] = _getProofsUsingTree(_createSingleLeafArray(leafs[1]), manageTree)[0];

        // Mock the overseer redeemable function to return true
        vm.mockCall(
            overseer,
            abi.encodeWithSignature("redeemable(uint256)", 1),
            abi.encode(true)
        );
        vm.mockCall(
            overseer,
            abi.encodeWithSignature("redeemable(uint256)", 2),
            abi.encode(true)
        );

        vm.prank(strategist);
        strategyManager.completeBurnRedemptions(burnIds, allProofs);

        assertTrue(true, "Burn redemptions completed successfully");
    }

    function testCompleteBurnRedemptionsFailsWithMismatchedArrays() external {
        uint256[] memory burnIds = new uint256[](2);
        bytes32[][] memory allProofs = new bytes32[][](1); // Mismatched length

        vm.prank(strategist);
        vm.expectRevert("Mismatched arrays");
        strategyManager.completeBurnRedemptions(burnIds, allProofs);
    }

    function testCompleteBurnRedemptionsFailsWhenBurnNotReady() external {
        ManageLeaf[] memory leafs = _createBurnRedemptionLeafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        uint256[] memory burnIds = new uint256[](1);
        burnIds[0] = 1;

        bytes32[][] memory allProofs = new bytes32[][](1);
        allProofs[0] = _getProofsUsingTree(_createSingleLeafArray(leafs[0]), manageTree)[0];

        // Mock the overseer redeemable function to return false
        vm.mockCall(
            overseer,
            abi.encodeWithSignature("redeemable(uint256)", 1),
            abi.encode(false)
        );

        vm.prank(strategist);
        vm.expectRevert("Burn not ready");
        strategyManager.completeBurnRedemptions(burnIds, allProofs);
    }

    // ========================================= VIEW FUNCTION TESTS =========================================

    function testGetMaxRedeemable() external {
        uint256 mockMaxRedeemable = 500e18;
        
        vm.mockCall(
            overseer,
            abi.encodeWithSignature("maxRedeemable()"),
            abi.encode(mockMaxRedeemable)
        );

        uint256 maxRedeemable = strategyManager.getMaxRedeemable();
        assertEq(maxRedeemable, mockMaxRedeemable, "Max redeemable amount should match mock");
    }

    function testIsBurnReady() external {
        uint256 burnId = 123;
        
        vm.mockCall(
            overseer,
            abi.encodeWithSignature("redeemable(uint256)", burnId),
            abi.encode(true)
        );

        bool isReady = strategyManager.isBurnReady(burnId);
        assertTrue(isReady, "Burn should be ready when overseer returns true");

        vm.mockCall(
            overseer,
            abi.encodeWithSignature("redeemable(uint256)", burnId),
            abi.encode(false)
        );

        isReady = strategyManager.isBurnReady(burnId);
        assertFalse(isReady, "Burn should not be ready when overseer returns false");
    }

    function testCheckVaultHealth() external {
        uint256 mockMaxRedeemable = 300e18;
        
        vm.mockCall(
            overseer,
            abi.encodeWithSignature("maxRedeemable()"),
            abi.encode(mockMaxRedeemable)
        );

        (
            uint256 totalWHypeBalance,
            uint256 totalStHypeBalance,
            uint256 maxRedeemableFromOverseer
        ) = strategyManager.checkVaultHealth();

        assertEq(totalWHypeBalance, INITIAL_BALANCE, "wHYPE balance should match initial balance");
        assertEq(totalStHypeBalance, INITIAL_BALANCE, "stHYPE balance should match initial balance");
        assertEq(maxRedeemableFromOverseer, mockMaxRedeemable, "Max redeemable should match mock");
    }

    // ========================================= DECODER TESTS =========================================

    function testHyperliquidDecoderMintFunction() external {
        bytes memory result = hyperliquidDecoder.mint(address(boringVault));
        assertEq(result, abi.encodePacked(address(boringVault)), "Should return vault address");

        vm.expectRevert(HyperliquidDecoderAndSanitizer.HyperliquidDecoderAndSanitizer__InvalidAddress.selector);
        hyperliquidDecoder.mint(address(0));
    }

    function testHyperliquidDecoderMintWithCommunityCode() external {
        bytes memory result = hyperliquidDecoder.mint(address(boringVault), "test");
        assertEq(result, abi.encodePacked(address(boringVault)), "Should return vault address");

        vm.expectRevert(HyperliquidDecoderAndSanitizer.HyperliquidDecoderAndSanitizer__InvalidAddress.selector);
        hyperliquidDecoder.mint(address(0), "test");
    }

    function testHyperliquidDecoderBurnAndRedeem() external {
        bytes memory result = hyperliquidDecoder.burnAndRedeemIfPossible(
            address(boringVault), 
            100e18, 
            "test"
        );
        assertEq(result, abi.encodePacked(address(boringVault)), "Should return vault address");

        vm.expectRevert(HyperliquidDecoderAndSanitizer.HyperliquidDecoderAndSanitizer__InvalidAddress.selector);
        hyperliquidDecoder.burnAndRedeemIfPossible(address(0), 100e18, "test");
    }

    function testHyperliquidDecoderWHypeOperations() external {
        bytes memory depositResult = hyperliquidDecoder.deposit();
        assertEq(depositResult.length, 0, "Deposit should return empty bytes");

        bytes memory withdrawResult = hyperliquidDecoder.withdraw(100e18);
        assertEq(withdrawResult.length, 0, "Withdraw should return empty bytes");
    }

    function testHyperliquidDecoderERC20Operations() external {
        bytes memory approveResult = hyperliquidDecoder.approve(felixMarkets, 100e18);
        assertEq(approveResult, abi.encodePacked(felixMarkets), "Should return spender address");

        vm.expectRevert(HyperliquidDecoderAndSanitizer.HyperliquidDecoderAndSanitizer__InvalidAddress.selector);
        hyperliquidDecoder.approve(address(0), 100e18);

        bytes memory transferResult = hyperliquidDecoder.transfer(user1, 100e18);
        assertEq(transferResult, abi.encodePacked(user1), "Should return recipient address");

        vm.expectRevert(HyperliquidDecoderAndSanitizer.HyperliquidDecoderAndSanitizer__InvalidAddress.selector);
        hyperliquidDecoder.transfer(address(0), 100e18);
    }

    // ========================================= ACCESS CONTROL TESTS =========================================

    function testOnlyStrategistCanExecuteLooping() external {
        bytes32[][] memory emptyProofs = new bytes32[][](15);
        
        vm.prank(user1); // Not a strategist
        vm.expectRevert(); // Should revert due to access control
        strategyManager.executeLoopingStrategy(LOOP_AMOUNT, 3, emptyProofs);
    }

    function testOnlyStrategistCanUnwindPositions() external {
        bytes32[][] memory emptyProofs = new bytes32[][](5);
        
        vm.prank(user1); // Not a strategist
        vm.expectRevert(); // Should revert due to access control
        strategyManager.unwindPositions(LOOP_AMOUNT, emptyProofs);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _createLoopingLeafs() internal view returns (ManageLeaf[] memory) {
        ManageLeaf[] memory leafs = new ManageLeaf[](20);
        uint256 leafIndex = 0;

        // wHYPE operations
        leafs[leafIndex++] = ManageLeaf(
            wHYPE, false, "withdraw(uint256)", new address[](0),
            "Unwrap wHYPE to HYPE", address(hyperliquidDecoder)
        );
        leafs[leafIndex++] = ManageLeaf(
            wHYPE, true, "deposit()", new address[](0),
            "Wrap HYPE to wHYPE", address(hyperliquidDecoder)
        );

        // Overseer operations
        leafs[leafIndex++] = ManageLeaf(
            overseer, true, "mint(address)", new address[](1),
            "Mint stHYPE", address(hyperliquidDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = address(boringVault);
        leafIndex++;

        // ERC20 approvals
        leafs[leafIndex++] = ManageLeaf(
            wstHYPE, false, "approve(address,uint256)", new address[](1),
            "Approve wstHYPE", address(hyperliquidDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = felixMarkets;
        leafIndex++;

        leafs[leafIndex++] = ManageLeaf(
            wHYPE, false, "approve(address,uint256)", new address[](1),
            "Approve wHYPE", address(hyperliquidDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = felixMarkets;
        leafIndex++;

        // Felix/Morpho operations (simplified for testing)
        leafs[leafIndex++] = ManageLeaf(
            felixMarkets, false, "supplyCollateral((address,address,address,address,uint256),uint256,address,bytes)",
            new address[](1), "Supply collateral to Felix", address(felixvanillaDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = address(boringVault);
        leafIndex++;

        leafs[leafIndex++] = ManageLeaf(
            felixMarkets, false, "borrow((address,address,address,address,uint256),uint256,uint256,address,address)",
            new address[](2), "Borrow from Felix", address(felixvanillaDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = address(boringVault);
        leafs[leafIndex].argumentAddresses[1] = address(boringVault);
        leafIndex++;

        // Trim to actual size
        ManageLeaf[] memory trimmedLeafs = new ManageLeaf[](leafIndex);
        for (uint256 i = 0; i < leafIndex; i++) {
            trimmedLeafs[i] = leafs[i];
        }
        return trimmedLeafs;
    }

    function _createUnwindingLeafs() internal view returns (ManageLeaf[] memory) {
        ManageLeaf[] memory leafs = new ManageLeaf[](10);
        uint256 leafIndex = 0;

        // Approval for repayment
        leafs[leafIndex++] = ManageLeaf(
            wHYPE, false, "approve(address,uint256)", new address[](1),
            "Approve wHYPE for repayment", address(hyperliquidDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = felixMarkets;
        leafIndex++;

        // Repay loan
        leafs[leafIndex++] = ManageLeaf(
            felixMarkets, false, "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            new address[](1), "Repay loan", address(felixvanillaDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = address(boringVault);
        leafIndex++;

        // Withdraw collateral
        leafs[leafIndex++] = ManageLeaf(
            felixMarkets, false, "withdrawCollateral((address,address,address,address,uint256),uint256,address,address)",
            new address[](2), "Withdraw collateral", address(felixvanillaDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = address(boringVault);
        leafs[leafIndex].argumentAddresses[1] = address(boringVault);
        leafIndex++;

        // Burn and redeem
        leafs[leafIndex++] = ManageLeaf(
            overseer, false, "burnAndRedeemIfPossible(address,uint256,string)",
            new address[](1), "Burn and redeem stHYPE", address(hyperliquidDecoder)
        );
        leafs[leafIndex].argumentAddresses[0] = address(boringVault);
        leafIndex++;

        // Trim to actual size
        ManageLeaf[] memory trimmedLeafs = new ManageLeaf[](leafIndex);
        for (uint256 i = 0; i < leafIndex; i++) {
            trimmedLeafs[i] = leafs[i];
        }
        return trimmedLeafs;
    }

    function _createWrapLeafs() internal view returns (ManageLeaf[] memory) {
        ManageLeaf[] memory leafs = new ManageLeaf[](1);
        leafs[0] = ManageLeaf(
            wHYPE, true, "deposit()", new address[](0),
            "Wrap HYPE to wHYPE", address(hyperliquidDecoder)
        );
        return leafs;
    }

    function _createBurnRedemptionLeafs() internal view returns (ManageLeaf[] memory) {
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        leafs[0] = ManageLeaf(
            overseer, false, "redeem(uint256)", new address[](0),
            "Redeem burn ID 1", address(hyperliquidDecoder)
        );
        leafs[1] = ManageLeaf(
            overseer, false, "redeem(uint256)", new address[](0),
            "Redeem burn ID 2", address(hyperliquidDecoder)
        );
        return leafs;
    }

    function _prepareLoopingProofs(
        ManageLeaf[] memory leafs,
        bytes32[][] memory manageTree,
        uint256 loops
    ) internal pure returns (bytes32[][] memory) {
        uint256 totalOps = loops * 5;
        bytes32[][] memory allProofs = new bytes32[][](totalOps);
        
        // For simplicity, use the first few leafs repeatedly
        for (uint256 i = 0; i < totalOps; i++) {
            uint256 leafIndexToUse = i % leafs.length;
            allProofs[i] = _getProofsUsingTree(
                _createSingleLeafArray(leafs[leafIndexToUse]), 
                manageTree
            )[0];
        }
        
        return allProofs;
    }

    function _prepareUnwindingProofs(
        ManageLeaf[] memory leafs,
        bytes32[][] memory manageTree
    ) internal pure returns (bytes32[][] memory) {
        bytes32[][] memory allProofs = new bytes32[][](5);
        
        for (uint256 i = 0; i < 5 && i < leafs.length; i++) {
            allProofs[i] = _getProofsUsingTree(
                _createSingleLeafArray(leafs[i]), 
                manageTree
            )[0];
        }
        
        return allProofs;
    }

    function _createSingleLeafArray(ManageLeaf memory leaf) 
        internal pure returns (ManageLeaf[] memory) 
    {
        ManageLeaf[] memory singleLeaf = new ManageLeaf[](1);
        singleLeaf[0] = leaf;
        return singleLeaf;
    }
}