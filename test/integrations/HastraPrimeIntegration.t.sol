// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {HastraPrimeFullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HastraPrimeFullDecoderAndSanitizer.sol";

interface IHastraWylds {
    function requestRedeem(uint256 shares) external;
    function cancelRedeem() external;
    function completeRedeem(address user) external;
    function claimRewards(uint256 epochIndex, uint256 amount, bytes32[] calldata proof) external;
    function depositWithPermit(uint256 assets, address receiver, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (uint256 shares);
    function getPendingRedemption(address user) external view returns (bool hasPending, uint256 shares, uint256 assets);
    function redeemVault() external view returns (address);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

contract HastraPrimeIntegrationTest is BaseTestIntegration {
    /// @dev wYLDS V2 (split REDEEM_OPERATOR_ROLE) went live at block 25739887; the PRIME NAV report is
    ///      102s old at this block and goes stale after 3600s, so these tests never warp.
    uint256 internal constant FORK_BLOCK = 26047800;

    /// @dev Sole REDEEM_OPERATOR_ROLE holder on wYLDS at FORK_BLOCK (also the wYLDS redeemVault).
    address internal constant HASTRA_REDEEM_OPERATOR = 0xA8C3CF6183D49d5D372f8FC149BD2cb5CFC0faCd;

    /// @dev YieldVault.RedemptionAlreadyPending()
    bytes4 internal constant REDEMPTION_ALREADY_PENDING = 0x450dbd7f;

    // Leaf layout produced by _addHastraPrimeLeafs on a fresh tree.
    uint256 internal constant APPROVE_USDC_TO_WYLDS = 0;
    uint256 internal constant WYLDS_DEPOSIT = 1;
    uint256 internal constant WYLDS_MINT = 2;
    uint256 internal constant APPROVE_WYLDS_TO_PRIME = 3;
    uint256 internal constant PRIME_DEPOSIT = 4;
    uint256 internal constant PRIME_MINT = 5;
    uint256 internal constant PRIME_REDEEM = 6;
    uint256 internal constant PRIME_WITHDRAW = 7;
    uint256 internal constant WYLDS_REQUEST_REDEEM = 8;
    uint256 internal constant WYLDS_CANCEL_REDEEM = 9;

    ERC20 internal usdc;
    ERC4626 internal wylds;
    ERC4626 internal prime;

    address internal attacker = vm.addr(0xBAD);

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", FORK_BLOCK);
        _overrideDecoder(address(new HastraPrimeFullDecoderAndSanitizer()));

        usdc = getERC20(sourceChain, "USDC");
        wylds = ERC4626(getAddress(sourceChain, "wYLDS"));
        prime = ERC4626(getAddress(sourceChain, "PRIME"));

        assertTrue(IHastraWylds(address(wylds)).hasRole(keccak256("REDEEM_OPERATOR"), HASTRA_REDEEM_OPERATOR), "operator lost REDEEM_OPERATOR_ROLE");
    }

    function _buildTree() internal returns (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) {
        leafs = new ManageLeaf[](16);
        _addHastraPrimeLeafs(leafs);
        assertEq(leafIndex, WYLDS_CANCEL_REDEEM, "unexpected leaf count");
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
    }

    // ========================================= MINT: USDC -> wYLDS -> PRIME =========================================

    function testMintPrimeFromUsdcWithDeposits() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();

        uint256 usdcAmount = 50_000e6;
        deal(address(usdc), address(boringVault), usdcAmount);
        uint256 expectedPrime = prime.previewDeposit(usdcAmount); // wYLDS mints 1:1 for USDC

        _mintPrimeWithDeposits(leafs, manageTree, usdcAmount);

        assertEq(usdc.balanceOf(address(boringVault)), 0, "USDC not fully deposited");
        assertEq(wylds.balanceOf(address(boringVault)), 0, "wYLDS not fully staked");
        assertEq(prime.balanceOf(address(boringVault)), expectedPrime, "PRIME minted != previewDeposit");
        assertGt(expectedPrime, 0);
    }

    function testMintPrimeFromUsdcWithMints() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();

        uint256 primeShares = 10_000e6;
        uint256 wyldsNeeded = prime.previewMint(primeShares);
        uint256 usdcNeeded = wylds.previewMint(wyldsNeeded);
        assertEq(usdcNeeded, wyldsNeeded, "wYLDS should be 1:1 with USDC");
        deal(address(usdc), address(boringVault), usdcNeeded);

        Tx memory tx_ = _getTxArrays(4);
        _setCall(tx_, 0, leafs[APPROVE_USDC_TO_WYLDS], address(usdc), abi.encodeCall(ERC20.approve, (address(wylds), usdcNeeded)));
        _setCall(tx_, 1, leafs[WYLDS_MINT], address(wylds), abi.encodeCall(ERC4626.mint, (wyldsNeeded, address(boringVault))));
        _setCall(tx_, 2, leafs[APPROVE_WYLDS_TO_PRIME], address(wylds), abi.encodeCall(ERC20.approve, (address(prime), wyldsNeeded)));
        _setCall(tx_, 3, leafs[PRIME_MINT], address(prime), abi.encodeCall(ERC4626.mint, (primeShares, address(boringVault))));
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);

        assertEq(usdc.balanceOf(address(boringVault)), 0, "USDC left over");
        assertEq(wylds.balanceOf(address(boringVault)), 0, "wYLDS left over");
        assertEq(prime.balanceOf(address(boringVault)), primeShares, "PRIME minted != requested shares");
    }

    // ========================================= REDEEM: PRIME -> wYLDS -> USDC =========================================

    function testRedeemPrimeToUsdcWithRedeem() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();

        uint256 usdcAmount = 25_000e6;
        deal(address(usdc), address(boringVault), usdcAmount);
        _mintPrimeWithDeposits(leafs, manageTree, usdcAmount);

        uint256 primeShares = prime.balanceOf(address(boringVault));
        uint256 expectedWylds = prime.previewRedeem(primeShares);

        // Unstake PRIME and queue the wYLDS redemption in one manager call.
        Tx memory tx_ = _getTxArrays(2);
        _setCall(tx_, 0, leafs[PRIME_REDEEM], address(prime), abi.encodeCall(ERC4626.redeem, (primeShares, address(boringVault), address(boringVault))));
        _setCall(tx_, 1, leafs[WYLDS_REQUEST_REDEEM], address(wylds), abi.encodeCall(IHastraWylds.requestRedeem, (expectedWylds)));
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);

        assertEq(prime.balanceOf(address(boringVault)), 0, "PRIME not fully redeemed");
        assertEq(wylds.balanceOf(address(boringVault)), 0, "wYLDS not escrowed");
        _assertPending(expectedWylds);

        _completeRedemption(expectedWylds);

        // Round trip through PRIME rounds down twice at most.
        uint256 usdcOut = usdc.balanceOf(address(boringVault));
        assertLe(usdcOut, usdcAmount, "round trip created value");
        assertApproxEqAbs(usdcOut, usdcAmount, 2, "round trip lost more than rounding");
    }

    function testRedeemPrimeToUsdcWithWithdraw() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();

        uint256 usdcAmount = 25_000e6;
        deal(address(usdc), address(boringVault), usdcAmount);
        _mintPrimeWithDeposits(leafs, manageTree, usdcAmount);

        uint256 wyldsOut = prime.maxWithdraw(address(boringVault));
        uint256 expectedBurn = prime.previewWithdraw(wyldsOut);
        uint256 primeBefore = prime.balanceOf(address(boringVault));

        Tx memory tx_ = _getTxArrays(2);
        _setCall(tx_, 0, leafs[PRIME_WITHDRAW], address(prime), abi.encodeCall(ERC4626.withdraw, (wyldsOut, address(boringVault), address(boringVault))));
        _setCall(tx_, 1, leafs[WYLDS_REQUEST_REDEEM], address(wylds), abi.encodeCall(IHastraWylds.requestRedeem, (wyldsOut)));
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);

        assertEq(prime.balanceOf(address(boringVault)), primeBefore - expectedBurn, "PRIME burned != previewWithdraw");
        _assertPending(wyldsOut);

        _completeRedemption(wyldsOut);
        assertEq(usdc.balanceOf(address(boringVault)), wyldsOut, "USDC out != wYLDS withdrawn");
    }

    function testCancelPendingRedemption() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();

        uint256 usdcAmount = 5_000e6;
        deal(address(usdc), address(boringVault), usdcAmount);

        // USDC -> wYLDS, queue a redemption, then cancel it, all in one manager call.
        Tx memory tx_ = _getTxArrays(4);
        _setCall(tx_, 0, leafs[APPROVE_USDC_TO_WYLDS], address(usdc), abi.encodeCall(ERC20.approve, (address(wylds), usdcAmount)));
        _setCall(tx_, 1, leafs[WYLDS_DEPOSIT], address(wylds), abi.encodeCall(ERC4626.deposit, (usdcAmount, address(boringVault))));
        _setCall(tx_, 2, leafs[WYLDS_REQUEST_REDEEM], address(wylds), abi.encodeCall(IHastraWylds.requestRedeem, (usdcAmount)));
        _setCall(tx_, 3, leafs[WYLDS_CANCEL_REDEEM], address(wylds), abi.encodeCall(IHastraWylds.cancelRedeem, ()));
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);

        assertEq(wylds.balanceOf(address(boringVault)), usdcAmount, "escrowed wYLDS not returned");
        (bool hasPending,,) = IHastraWylds(address(wylds)).getPendingRedemption(address(boringVault));
        assertFalse(hasPending, "redemption still pending");

        // A fresh request after the cancel still settles to the vault.
        _manageSingle(leafs, manageTree, WYLDS_REQUEST_REDEEM, address(wylds), abi.encodeCall(IHastraWylds.requestRedeem, (usdcAmount)));
        _completeRedemption(usdcAmount);
        assertEq(usdc.balanceOf(address(boringVault)), usdcAmount, "USDC not returned 1:1");
    }

    /// @notice Hastra allows one pending redemption per account; a second request must wait for
    ///         completeRedeem or cancelRedeem.
    function testSecondRedemptionRequestRevertsWhilePending() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();

        uint256 usdcAmount = 2_000e6;
        deal(address(usdc), address(boringVault), usdcAmount);

        Tx memory tx_ = _getTxArrays(3);
        _setCall(tx_, 0, leafs[APPROVE_USDC_TO_WYLDS], address(usdc), abi.encodeCall(ERC20.approve, (address(wylds), usdcAmount)));
        _setCall(tx_, 1, leafs[WYLDS_DEPOSIT], address(wylds), abi.encodeCall(ERC4626.deposit, (usdcAmount, address(boringVault))));
        _setCall(tx_, 2, leafs[WYLDS_REQUEST_REDEEM], address(wylds), abi.encodeCall(IHastraWylds.requestRedeem, (usdcAmount / 2)));
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);

        tx_ = _getTxArrays(1);
        _setCall(tx_, 0, leafs[WYLDS_REQUEST_REDEEM], address(wylds), abi.encodeCall(IHastraWylds.requestRedeem, (usdcAmount / 2)));
        bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        vm.expectRevert(REDEMPTION_ALREADY_PENDING);
        _submitManagerCall(proofs, tx_);
    }

    /// @notice A tree built from the redeem helper alone unwinds a position end to end and has no way back in.
    function testRedeemOnlyTreeUnwindsPosition() external {
        _setUpMainnet();

        // Seed the vault with PRIME outside the manager.
        uint256 usdcAmount = 10_000e6;
        deal(address(usdc), address(this), usdcAmount);
        usdc.approve(address(wylds), usdcAmount);
        wylds.deposit(usdcAmount, address(this));
        wylds.approve(address(prime), usdcAmount);
        uint256 primeShares = prime.deposit(usdcAmount, address(boringVault));

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addHastraPrimeRedeemLeafs(leafs);
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        for (uint256 i; i < leafs.length; ++i) {
            assertTrue(leafs[i].target == address(prime) || leafs[i].target == address(wylds), "unexpected target");
            assertTrue(keccak256(bytes(leafs[i].signature)) != keccak256("approve(address,uint256)"), "approval in exit tree");
        }

        uint256 expectedWylds = prime.previewRedeem(primeShares);
        Tx memory tx_ = _getTxArrays(2);
        _setCall(
            tx_,
            0,
            leafs[0], // PRIME redeem
            address(prime),
            abi.encodeCall(ERC4626.redeem, (primeShares, address(boringVault), address(boringVault)))
        );
        _setCall(tx_, 1, leafs[2], address(wylds), abi.encodeCall(IHastraWylds.requestRedeem, (expectedWylds)));
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);
        _completeRedemption(expectedWylds);
        assertEq(usdc.balanceOf(address(boringVault)), expectedWylds, "unwind did not return USDC");

        // No way back in: neither approvals nor deposits/mints are authorized.
        address bv = address(boringVault);
        _assertNoLeafAllows(leafs, manageTree, 0, address(usdc), abi.encodeCall(ERC20.approve, (address(wylds), 1)));
        _assertNoLeafAllows(leafs, manageTree, 0, address(wylds), abi.encodeCall(ERC4626.deposit, (1e6, bv)));
        _assertNoLeafAllows(leafs, manageTree, 0, address(wylds), abi.encodeCall(ERC4626.mint, (1e6, bv)));
        _assertNoLeafAllows(leafs, manageTree, 0, address(wylds), abi.encodeCall(ERC20.approve, (address(prime), 1)));
        _assertNoLeafAllows(leafs, manageTree, 0, address(prime), abi.encodeCall(ERC4626.deposit, (1e6, bv)));
        _assertNoLeafAllows(leafs, manageTree, 0, address(prime), abi.encodeCall(ERC4626.mint, (1e6, bv)));
    }

    // ========================================= SANITIZATION =========================================

    /// @notice Every address the decoder surfaces is pinned by the leaf: swapping any receiver, owner or
    ///         spender away from the expected address fails proof verification.
    function testRevertsWhenAnyAddressArgumentIsNotPinnedValue() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();
        address bv = address(boringVault);

        _assertNoLeafAllows(leafs, manageTree, APPROVE_USDC_TO_WYLDS, address(usdc), abi.encodeCall(ERC20.approve, (attacker, 1)));
        _assertNoLeafAllows(leafs, manageTree, APPROVE_WYLDS_TO_PRIME, address(wylds), abi.encodeCall(ERC20.approve, (attacker, 1)));
        _assertNoLeafAllows(leafs, manageTree, WYLDS_DEPOSIT, address(wylds), abi.encodeCall(ERC4626.deposit, (1e6, attacker)));
        _assertNoLeafAllows(leafs, manageTree, WYLDS_MINT, address(wylds), abi.encodeCall(ERC4626.mint, (1e6, attacker)));
        _assertNoLeafAllows(leafs, manageTree, PRIME_DEPOSIT, address(prime), abi.encodeCall(ERC4626.deposit, (1e6, attacker)));
        _assertNoLeafAllows(leafs, manageTree, PRIME_MINT, address(prime), abi.encodeCall(ERC4626.mint, (1e6, attacker)));
        _assertNoLeafAllows(leafs, manageTree, PRIME_REDEEM, address(prime), abi.encodeCall(ERC4626.redeem, (1e6, attacker, bv)));
        _assertNoLeafAllows(leafs, manageTree, PRIME_REDEEM, address(prime), abi.encodeCall(ERC4626.redeem, (1e6, bv, attacker)));
        _assertNoLeafAllows(leafs, manageTree, PRIME_WITHDRAW, address(prime), abi.encodeCall(ERC4626.withdraw, (1e6, attacker, bv)));
        _assertNoLeafAllows(leafs, manageTree, PRIME_WITHDRAW, address(prime), abi.encodeCall(ERC4626.withdraw, (1e6, bv, attacker)));
    }

    /// @notice Leaves are bound to their target: wYLDS has no withdraw/redeem leaf (both always revert
    ///         there), PRIME has no redemption-queue leaf, and USDC can only be approved to wYLDS.
    function testLeavesAreBoundToTheirTarget() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();
        address bv = address(boringVault);

        _assertNoLeafAllows(leafs, manageTree, PRIME_REDEEM, address(wylds), abi.encodeCall(ERC4626.redeem, (1e6, bv, bv)));
        _assertNoLeafAllows(leafs, manageTree, PRIME_WITHDRAW, address(wylds), abi.encodeCall(ERC4626.withdraw, (1e6, bv, bv)));
        _assertNoLeafAllows(leafs, manageTree, WYLDS_REQUEST_REDEEM, address(prime), abi.encodeCall(IHastraWylds.requestRedeem, (1e6)));
        _assertNoLeafAllows(leafs, manageTree, WYLDS_CANCEL_REDEEM, address(prime), abi.encodeCall(IHastraWylds.cancelRedeem, ()));
        _assertNoLeafAllows(leafs, manageTree, APPROVE_USDC_TO_WYLDS, address(usdc), abi.encodeCall(ERC20.approve, (address(prime), 1)));
        _assertNoLeafAllows(leafs, manageTree, APPROVE_WYLDS_TO_PRIME, address(prime), abi.encodeCall(ERC20.approve, (address(wylds), 1)));
    }

    /// @notice Hastra functions outside the mint/redeem path never get past the decoder.
    function testUnsupportedHastraCallsRevertInDecoder() external {
        _setUpMainnet();
        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _buildTree();
        address bv = address(boringVault);

        bytes[3] memory calls = [
            abi.encodeCall(IHastraWylds.completeRedeem, (bv)),
            abi.encodeCall(IHastraWylds.depositWithPermit, (1e6, bv, block.timestamp, 27, bytes32(0), bytes32(0))),
            abi.encodeCall(IHastraWylds.claimRewards, (0, 1e6, new bytes32[](0)))
        ];
        for (uint256 i; i < calls.length; ++i) {
            Tx memory tx_ = _getTxArrays(1);
            _setCall(tx_, 0, leafs[WYLDS_DEPOSIT], address(wylds), calls[i]);
            bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
            vm.expectRevert(BaseDecoderAndSanitizer.BaseDecoderAndSanitizer__FunctionSelectorNotSupported.selector);
            _submitManagerCall(proofs, tx_);
        }
    }

    // ========================================= LEAF HELPERS =========================================

    function testLeafHelperLayoutMatchesDecoderOutput() external {
        _setUpMainnet();
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addHastraPrimeLeafs(leafs);
        address bv = address(boringVault);

        _assertLeaf(leafs[APPROVE_USDC_TO_WYLDS], address(usdc), "approve(address,uint256)", abi.encodeCall(ERC20.approve, (address(wylds), 1)));
        _assertLeaf(leafs[WYLDS_DEPOSIT], address(wylds), "deposit(uint256,address)", abi.encodeCall(ERC4626.deposit, (1, bv)));
        _assertLeaf(leafs[WYLDS_MINT], address(wylds), "mint(uint256,address)", abi.encodeCall(ERC4626.mint, (1, bv)));
        _assertLeaf(leafs[APPROVE_WYLDS_TO_PRIME], address(wylds), "approve(address,uint256)", abi.encodeCall(ERC20.approve, (address(prime), 1)));
        _assertLeaf(leafs[PRIME_DEPOSIT], address(prime), "deposit(uint256,address)", abi.encodeCall(ERC4626.deposit, (1, bv)));
        _assertLeaf(leafs[PRIME_MINT], address(prime), "mint(uint256,address)", abi.encodeCall(ERC4626.mint, (1, bv)));
        _assertLeaf(leafs[PRIME_REDEEM], address(prime), "redeem(uint256,address,address)", abi.encodeCall(ERC4626.redeem, (1, bv, bv)));
        _assertLeaf(leafs[PRIME_WITHDRAW], address(prime), "withdraw(uint256,address,address)", abi.encodeCall(ERC4626.withdraw, (1, bv, bv)));
        _assertLeaf(leafs[WYLDS_REQUEST_REDEEM], address(wylds), "requestRedeem(uint256)", abi.encodeCall(IHastraWylds.requestRedeem, (1)));
        _assertLeaf(leafs[WYLDS_CANCEL_REDEEM], address(wylds), "cancelRedeem()", abi.encodeCall(IHastraWylds.cancelRedeem, ()));
    }

    /// @notice Approvals already in the tree are not added twice.
    function testMintHelperSkipsApprovalsAlreadyInTree() external {
        _setUpMainnet();
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addHastraPrimeMintLeafs(leafs);
        assertEq(leafIndex, 5, "first pass should add 6 leafs");
        _addHastraPrimeMintLeafs(leafs);
        assertEq(leafIndex, 9, "second pass should skip both approvals");
    }

    // ========================================= HELPERS =========================================

    function _mintPrimeWithDeposits(ManageLeaf[] memory leafs, bytes32[][] memory manageTree, uint256 usdcAmount) internal {
        Tx memory tx_ = _getTxArrays(4);
        _setCall(tx_, 0, leafs[APPROVE_USDC_TO_WYLDS], address(usdc), abi.encodeCall(ERC20.approve, (address(wylds), usdcAmount)));
        _setCall(tx_, 1, leafs[WYLDS_DEPOSIT], address(wylds), abi.encodeCall(ERC4626.deposit, (usdcAmount, address(boringVault))));
        _setCall(tx_, 2, leafs[APPROVE_WYLDS_TO_PRIME], address(wylds), abi.encodeCall(ERC20.approve, (address(prime), usdcAmount)));
        _setCall(tx_, 3, leafs[PRIME_DEPOSIT], address(prime), abi.encodeCall(ERC4626.deposit, (usdcAmount, address(boringVault))));
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);
    }

    /// @dev Hastra's operator settles the vault's pending redemption; USDC comes from the redeemVault.
    function _completeRedemption(uint256 expectedUsdc) internal {
        address redeemVault = IHastraWylds(address(wylds)).redeemVault();
        // completeRedeem is all-or-nothing against the redeemVault balance (~85k USDC at FORK_BLOCK).
        if (usdc.balanceOf(redeemVault) < expectedUsdc) deal(address(usdc), redeemVault, expectedUsdc);
        uint256 usdcBefore = usdc.balanceOf(address(boringVault));
        uint256 redeemVaultBefore = usdc.balanceOf(redeemVault);

        vm.prank(HASTRA_REDEEM_OPERATOR);
        IHastraWylds(address(wylds)).completeRedeem(address(boringVault));

        assertEq(usdc.balanceOf(address(boringVault)) - usdcBefore, expectedUsdc, "vault did not receive USDC 1:1");
        assertEq(redeemVaultBefore - usdc.balanceOf(redeemVault), expectedUsdc, "USDC did not come from redeemVault");
        (bool hasPending,,) = IHastraWylds(address(wylds)).getPendingRedemption(address(boringVault));
        assertFalse(hasPending, "redemption still pending");
    }

    function _assertPending(uint256 expectedShares) internal view {
        (bool hasPending, uint256 shares, uint256 assets) = IHastraWylds(address(wylds)).getPendingRedemption(address(boringVault));
        assertTrue(hasPending, "no pending redemption");
        assertEq(shares, expectedShares, "pending shares");
        assertEq(assets, expectedShares, "pending assets should be 1:1");
    }

    function _setCall(Tx memory tx_, uint256 i, ManageLeaf memory leaf, address target, bytes memory data) internal view {
        tx_.manageLeafs[i] = leaf;
        tx_.targets[i] = target;
        tx_.targetData[i] = data;
        tx_.decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
    }

    function _manageSingle(ManageLeaf[] memory leafs, bytes32[][] memory manageTree, uint256 leafId, address target, bytes memory data) internal {
        Tx memory tx_ = _getTxArrays(1);
        _setCall(tx_, 0, leafs[leafId], target, data);
        _submitManagerCall(_getProofsUsingTree(tx_.manageLeafs, manageTree), tx_);
    }

    /// @dev Asserts no leaf in the tree authorizes `data` on `target` (digest computed the way
    ///      ManagerWithMerkleVerification does), then shows the manager rejects it with a real proof.
    function _assertNoLeafAllows(ManageLeaf[] memory leafs, bytes32[][] memory manageTree, uint256 leafId, address target, bytes memory data) internal {
        (bool success, bytes memory result) = rawDataDecoderAndSanitizer.staticcall(data);
        assertTrue(success, "decoder rejected the call");
        bytes32 digest = keccak256(abi.encodePacked(rawDataDecoderAndSanitizer, target, false, bytes4(data), abi.decode(result, (bytes))));
        for (uint256 i; i < manageTree[0].length; ++i) {
            assertTrue(manageTree[0][i] != digest, "a leaf authorizes this call");
        }

        Tx memory tx_ = _getTxArrays(1);
        _setCall(tx_, 0, leafs[leafId], target, data);
        bytes32[][] memory proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
        vm.expectRevert(
            abi.encodeWithSelector(ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, target, data, 0)
        );
        _submitManagerCall(proofs, tx_);
    }

    /// @dev Checks target, signature and decoder, and that the decoder's output for a call built with the
    ///      pinned values equals the leaf's packed argumentAddresses.
    function _assertLeaf(ManageLeaf memory leaf, address target, string memory signature, bytes memory callData) internal view {
        assertEq(leaf.target, target, signature);
        assertEq(leaf.signature, signature);
        assertFalse(leaf.canSendValue, signature);
        assertEq(leaf.decoderAndSanitizer, rawDataDecoderAndSanitizer, signature);

        bytes memory packed;
        for (uint256 i; i < leaf.argumentAddresses.length; ++i) {
            packed = abi.encodePacked(packed, leaf.argumentAddresses[i]);
        }
        (bool success, bytes memory result) = rawDataDecoderAndSanitizer.staticcall(callData);
        assertTrue(success, signature);
        assertEq(abi.decode(result, (bytes)), packed, signature);
    }
}
