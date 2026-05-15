// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport, ComplianceData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithMultiAssetSupportLib} from "src/base/Roles/TellerWithMultiAssetSupportLib.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {MockERC20} from "src/helper/MockERC20.sol";

/// @title Positive- and negative-path tests for BoringVaultWrapper's Option-2 compliance layer.
/// @dev   Each test exercises one branch of _enforceTransferPolicy or _verifyComplianceSignature.
contract Compliance_BoringVaultWrapper_Test is Test {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint8 constant ADMIN_ROLE = 1;
    uint8 constant MINTER_ROLE = 7;
    uint8 constant BURNER_ROLE = 8;
    uint8 constant WRAPPER_ROLE = 55;
    uint8 constant COMPLIANCE_ROLE = 60;
    uint8 constant TRANSFER_ALLOWED_ROLE = 70;

    MockERC20 baseAsset;
    BoringVault boringVault;
    AccountantWithRateProviders accountant;
    TellerWithMultiAssetSupport teller;
    BoringVaultWrapper wrapper;
    RolesAuthority rolesAuthority;

    uint256 constant SIGNER_KEY = uint256(keccak256("compliance-signer-key"));
    address signer;

    address feeRecipient = makeAddr("feeRecipient");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address mallory = makeAddr("mallory");
    address payoutAddress = makeAddr("payoutAddress");

    function setUp() public {
        signer = vm.addr(SIGNER_KEY);

        baseAsset = new MockERC20("Wrapped Ether", "WETH", 18);
        boringVault = new BoringVault(address(this), "Test Boring Vault", "TBV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddress, 1e18, address(baseAsset), 1.1e4, 0.9e4, 1, 0, 0
        );

        teller = new TellerWithMultiAssetSupport(
            address(this), address(boringVault), address(accountant), address(baseAsset)
        );

        wrapper = new BoringVaultWrapper(
            address(this), address(boringVault), address(accountant), address(teller), "Partner Vault", "PV"
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        wrapper.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setComplianceConfig.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setDenyFlags.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setTransferRestrictions.selector, true
        );
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(wrapper), WRAPPER_ROLE, true);

        teller.updateAssetData(baseAsset, true, true, 0);
        accountant.setRateProviderData(baseAsset, true, address(0));
    }

    // =========================================================================
    //                  HELPERS — wrapper-domain signature builder
    // =========================================================================

    function _wrapperHash(address user, address receiver, address asset, uint256 amount, uint256 deadline)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(address(wrapper), block.chainid, user, receiver, asset, amount, deadline));
    }

    function _signWrapperSig(
        uint256 key,
        address user,
        address receiver,
        address asset,
        uint256 amount,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(
            _wrapperHash(user, receiver, asset, amount, deadline)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    function _enableCompliance() internal {
        rolesAuthority.setUserRole(signer, COMPLIANCE_ROLE, true);
        teller.setComplianceConfig(COMPLIANCE_ROLE, 0);
    }

    // =========================================================================
    //                  COMPLIANCE SIGNATURE — positive path
    // =========================================================================

    function test_DepositAsset_ValidSignature_Succeeds() public {
        _enableCompliance();

        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signWrapperSig(SIGNER_KEY, alice, alice, address(baseAsset), amount, deadline);

        deal(address(baseAsset), alice, amount);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(deadline, sig));
        vm.stopPrank();

        // Wrapper shares scale by 10**DECIMALS_OFFSET (= 1e6) due to OZ virtual-offset.
        assertEq(wShares, amount * 1e6, "valid sig: first deposit at SHARE_SCALE ratio");
        assertEq(wrapper.balanceOf(alice), wShares, "alice received wrapper shares");
    }

    function test_DepositAsset_ComplianceDisabled_NoSigRequired() public {
        // Default state: complianceSignerRole = 255 → check skipped, any sig accepted (incl. empty).
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
        assertEq(wShares, amount * 1e6, "compliance disabled: empty sig is fine, shares at SHARE_SCALE");
    }

    // =========================================================================
    //                  COMPLIANCE SIGNATURE — negative paths
    // =========================================================================

    function test_DepositAsset_WrongSigner_Reverts() public {
        _enableCompliance();

        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;
        // Signed by an attacker key that does NOT hold COMPLIANCE_ROLE.
        bytes memory badSig = _signWrapperSig(uint256(0xBADBAD), alice, alice, address(baseAsset), amount, deadline);

        deal(address(baseAsset), alice, amount);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupportLib.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(deadline, badSig));
        vm.stopPrank();
    }

    function test_DepositAsset_ExpiredDeadline_Reverts() public {
        _enableCompliance();

        uint256 amount = 100e18;
        uint256 deadline = block.timestamp; // expires this block; advance once to break it
        bytes memory sig = _signWrapperSig(SIGNER_KEY, alice, alice, address(baseAsset), amount, deadline);

        skip(2);

        deal(address(baseAsset), alice, amount);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupportLib.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(deadline, sig));
        vm.stopPrank();
    }

    function test_DepositAsset_SignatureReplay_Reverts() public {
        _enableCompliance();

        uint256 amount = 50e18;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signWrapperSig(SIGNER_KEY, alice, alice, address(baseAsset), amount, deadline);

        deal(address(baseAsset), alice, amount * 2);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount * 2);

        // First use of the sig — succeeds.
        wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(deadline, sig));

        // Replay with identical args → wrapper's local usedComplianceSignatures map blocks it.
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupportLib.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(deadline, sig));
        vm.stopPrank();
    }

    function test_DepositAsset_TellerDomainSignature_NotAcceptedOnWrapper() public {
        _enableCompliance();

        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;

        // Build a Teller-domain hash (uses teller address instead of wrapper).
        bytes32 tellerHash =
            keccak256(abi.encode(address(teller), block.chainid, alice, alice, address(baseAsset), amount, deadline));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(tellerHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, ethSignedHash);
        bytes memory tellerDomainSig = abi.encodePacked(r, s, v);

        deal(address(baseAsset), alice, amount);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupportLib.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(deadline, tellerDomainSig));
        vm.stopPrank();
    }

    // =========================================================================
    //                  DENYLIST — standard ERC4626 paths
    // =========================================================================

    function test_StandardDeposit_DenylistedReceiver_Reverts() public {
        teller.setDenyFlags(mallory, false, true, false); // denyTo on receiver

        deal(address(boringVault), alice, 100e18, true);
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, mallory, alice
            )
        );
        wrapper.deposit(100e18, mallory);
        vm.stopPrank();
    }

    function test_StandardRedeem_DenylistedOwner_Reverts() public {
        // First a clean deposit so alice holds wrapper shares.
        deal(address(boringVault), alice, 100e18, true);
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        wrapper.deposit(100e18, alice);
        vm.stopPrank();

        // Now alice gets sanctioned.
        teller.setDenyFlags(alice, true, false, false); // denyFrom

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, alice, alice)
        );
        wrapper.redeem(100e18, alice, alice);
    }

    // =========================================================================
    //                  WRAPPER-SHARE TRANSFERS
    // =========================================================================

    function test_TransferFrom_DenylistedFrom_Reverts() public {
        // Alice acquires shares, then becomes denylisted.
        deal(address(boringVault), alice, 100e18, true);
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        wrapper.deposit(100e18, alice);
        wrapper.approve(bob, 50e18);
        vm.stopPrank();

        teller.setDenyFlags(alice, true, false, false); // alice now denyFrom

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, bob, bob)
        );
        wrapper.transferFrom(alice, bob, 50e18);
    }

    function test_Transfer_AllowlistOff_AnyTransferSucceeds() public {
        // Default: transferAllowedRole = 255 → no restriction.
        deal(address(boringVault), alice, 100e18, true);
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        wrapper.deposit(100e18, alice);
        wrapper.transfer(bob, 30e18); // arbitrary recipient, no role needed
        vm.stopPrank();
        assertEq(wrapper.balanceOf(bob), 30e18);
    }

    function test_Transfer_AllowlistOn_FromHoldsRole_Succeeds() public {
        teller.setTransferRestrictions(TRANSFER_ALLOWED_ROLE, type(uint8).max);
        rolesAuthority.setUserRole(alice, TRANSFER_ALLOWED_ROLE, true);

        deal(address(boringVault), alice, 100e18, true);
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        wrapper.deposit(100e18, alice);
        wrapper.transfer(bob, 10e18); // alice (from) holds role
        vm.stopPrank();

        assertEq(wrapper.balanceOf(bob), 10e18, "transfer succeeded because from holds role");
    }

    function test_Transfer_AllowlistOn_NobodyHasRole_Reverts() public {
        teller.setTransferRestrictions(TRANSFER_ALLOWED_ROLE, type(uint8).max);
        // Grant role only for the deposit step (alice), then revoke before the transfer.
        rolesAuthority.setUserRole(alice, TRANSFER_ALLOWED_ROLE, true);

        deal(address(boringVault), alice, 100e18, true);
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        wrapper.deposit(100e18, alice);
        vm.stopPrank();

        rolesAuthority.setUserRole(alice, TRANSFER_ALLOWED_ROLE, false);

        vm.prank(alice);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__TransferNotAllowed.selector);
        wrapper.transfer(bob, 10e18);
    }

    function test_RedeemAsset_DenylistedOperator_Reverts() public {
        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        wrapper.approve(mallory, 50e18);
        vm.stopPrank();

        teller.setDenyFlags(mallory, false, false, true); // denyOperator

        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(
                BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, alice, mallory
            )
        );
        wrapper.redeemAsset(baseAsset, 50e18, 0, alice, alice);
    }
}
