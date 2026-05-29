// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {SafeApproveHashGuard} from "src/base/Governance/SafeApproveHashGuard.sol";

interface ISafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function nonce() external view returns (uint256);
    function approveHash(bytes32 hashToApprove) external;
    function swapOwner(address prevOwner, address oldOwner, address newOwner) external;
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);
    function setGuard(address guard) external;
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);
}

contract SafeApproveHashGuardIntegrationTest is Test, ChainValues {
    uint256 constant BLOCK_NUMBER = 24826904;
    address constant SENTINEL = address(0x1);

    ISafe safe;
    SafeApproveHashGuard guard;

    address[] owners;
    uint256 threshold;

    function setUp() external {
        uint256 forkId = vm.createFork(vm.envString("MAINNET_RPC_URL"), BLOCK_NUMBER);
        vm.selectFork(forkId);

        safe = ISafe(getAddress(mainnet, "liquidMultisig"));
        guard = new SafeApproveHashGuard();

        threshold = safe.getThreshold();
        owners = safe.getOwners();

        // Set the guard on the Safe (authorized = msg.sender == address(this))
        vm.prank(address(safe));
        safe.setGuard(address(guard));
    }

    // ======================== E2E through Safe ========================

    function testApproveHashTransactionSucceeds() external {
        address to = address(0xdead);

        bytes32 txHash = safe.getTransactionHash(to, 0, "", 0, 0, 0, 0, address(0), address(0), safe.nonce());

        address[] memory signers = _getSortedSigners();

        for (uint256 i; i < threshold; ++i) {
            vm.prank(signers[i]);
            safe.approveHash(txHash);
        }

        bytes memory signatures = _buildApproveHashSignatures(signers);

        bool success = safe.execTransaction(to, 0, "", 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertTrue(success, "approve-hash tx should succeed");
    }

    function testECDSATransactionBlockedByGuard() external {
        // Swap one owner with a test account whose private key we control.
        // In Safe v1.3.0, checkSignatures runs before the guard. So we need valid
        // ECDSA signatures that pass checkSignatures but are then caught by the guard.
        uint256 testPk = 0xBEEF;
        address testAddr = vm.addr(testPk);

        vm.prank(address(safe));
        safe.swapOwner(SENTINEL, owners[0], testAddr);

        // Refresh owners after swap
        address[] memory updatedOwners = safe.getOwners();
        address[] memory signers = new address[](threshold);
        for (uint256 i; i < threshold; ++i) {
            signers[i] = updatedOwners[i];
        }
        _sortAddresses(signers);

        address to = address(0xbeef);
        bytes32 txHash = safe.getTransactionHash(to, 0, "", 0, 0, 0, 0, address(0), address(0), safe.nonce());

        // Approve hash for non-test signers, ECDSA for the test signer
        bytes memory signatures;
        for (uint256 i; i < threshold; ++i) {
            if (signers[i] == testAddr) {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(testPk, txHash);
                signatures = abi.encodePacked(signatures, r, s, bytes1(v));
            } else {
                vm.prank(signers[i]);
                safe.approveHash(txHash);
                signatures =
                    abi.encodePacked(signatures, bytes32(uint256(uint160(signers[i]))), bytes32(0), bytes1(uint8(1)));
            }
        }

        // checkSignatures passes (all signatures are valid), then guard catches v != 1
        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        safe.execTransaction(to, 0, "", 0, 0, 0, 0, address(0), payable(address(0)), signatures);
    }

    // ======================== E2E: Safe self-management ========================

    function testSwapOwnerViaApproveHash() external {
        address newOwner = address(0xCAFE);
        address oldOwner = owners[0];

        bytes memory data = abi.encodeWithSelector(ISafe.swapOwner.selector, SENTINEL, oldOwner, newOwner);

        _execApproveHashSafeTx(address(safe), 0, data);

        // Verify the swap
        address[] memory newOwners = safe.getOwners();
        bool foundNew;
        bool foundOld;
        for (uint256 i; i < newOwners.length; ++i) {
            if (newOwners[i] == newOwner) foundNew = true;
            if (newOwners[i] == oldOwner) foundOld = true;
        }
        assertTrue(foundNew, "new owner should be present");
        assertFalse(foundOld, "old owner should be removed");
        assertEq(newOwners.length, owners.length, "owner count unchanged");
    }

    function testGuardCanBeDisabledViaApproveHash() external {
        // Disable the guard through a Safe transaction using approveHash
        bytes memory data = abi.encodeWithSelector(ISafe.setGuard.selector, address(0));
        _execApproveHashSafeTx(address(safe), 0, data);

        // Swap in a test account so we can produce valid ECDSA signatures
        uint256 testPk = 0xBEEF;
        address testAddr = vm.addr(testPk);
        vm.prank(address(safe));
        safe.swapOwner(SENTINEL, owners[0], testAddr);

        // Build a tx with one ECDSA signature -- should succeed now that guard is disabled
        address[] memory updatedOwners = safe.getOwners();
        address[] memory signers = new address[](threshold);
        for (uint256 i; i < threshold; ++i) {
            signers[i] = updatedOwners[i];
        }
        _sortAddresses(signers);

        address to = address(0xbeef);
        bytes32 txHash = safe.getTransactionHash(to, 0, "", 0, 0, 0, 0, address(0), address(0), safe.nonce());

        bytes memory signatures;
        for (uint256 i; i < threshold; ++i) {
            if (signers[i] == testAddr) {
                (uint8 v, bytes32 r, bytes32 s) = vm.sign(testPk, txHash);
                signatures = abi.encodePacked(signatures, r, s, bytes1(v));
            } else {
                vm.prank(signers[i]);
                safe.approveHash(txHash);
                signatures =
                    abi.encodePacked(signatures, bytes32(uint256(uint160(signers[i]))), bytes32(0), bytes1(uint8(1)));
            }
        }

        bool success = safe.execTransaction(to, 0, "", 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertTrue(success, "ECDSA tx should succeed after guard disabled");
    }

    function testSequentialApproveHashTransactions() external {
        // Execute two transactions in sequence to verify nonce handling
        for (uint256 n; n < 2; ++n) {
            _execApproveHashSafeTx(address(uint160(0xdead + n)), 0, "");
        }
    }

    function testDelegateCallWithApproveHash() external {
        // delegateCall (operation=1) should also work with approveHash
        // Target a no-op: delegatecall to an address with no code just returns true
        address to = address(0xdead);

        bytes32 txHash = safe.getTransactionHash(to, 0, "", 1, 0, 0, 0, address(0), address(0), safe.nonce());

        address[] memory signers = _getSortedSigners();
        for (uint256 i; i < threshold; ++i) {
            vm.prank(signers[i]);
            safe.approveHash(txHash);
        }
        bytes memory signatures = _buildApproveHashSignatures(signers);

        bool success = safe.execTransaction(to, 0, "", 1, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertTrue(success, "delegateCall with approveHash should succeed");
    }

    // ======================== Guard direct ========================
    // Safe v1.3.0 validates signatures before calling the guard, so edge cases
    // that fail signature validation (empty, malformed) must be tested directly.

    function testGuardRejectsECDSASignatures() external {
        address[] memory signers = _getSortedSigners();
        bytes memory ecdsaSigs = _buildFakeECDSASignatures(signers);

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), ecdsaSigs, address(0));
    }

    function testGuardRejectsMixedSignatures() external {
        address[] memory signers = _getSortedSigners();

        bytes memory signatures;
        for (uint256 i; i < signers.length; ++i) {
            uint8 v = i == 0 ? uint8(1) : uint8(27);
            signatures = abi.encodePacked(signatures, bytes32(uint256(uint160(signers[i]))), bytes32(0), bytes1(v));
        }

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), signatures, address(0));
    }

    function testGuardRejectsEmptySignatures() external {
        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__InvalidSignatureLength.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), "", address(0));
    }

    function testGuardRejectsMalformedSignatureLength() external {
        // 64 bytes: one byte too short
        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__InvalidSignatureLength.selector);
        guard.checkTransaction(
            address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), new bytes(64), address(0)
        );
    }

    function testGuardRejects66Bytes() external {
        // 66 bytes: one byte too long (not a multiple of 65)
        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__InvalidSignatureLength.selector);
        guard.checkTransaction(
            address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), new bytes(66), address(0)
        );
    }

    function testGuardRejects1Byte() external {
        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__InvalidSignatureLength.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), new bytes(1), address(0));
    }

    function testGuardRejects130Bytes() external {
        // 130 = 2 * 65, but this is the exact-multiple check -- should proceed to v-check.
        // Since all bytes are zero, v=0 for both sigs -> revert OnlyApproveHashSignatures.
        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(
            address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), new bytes(130), address(0)
        );
    }

    function testGuardRejectsEIP1271MockPayload() external {
        // 97 bytes: 65-byte signature + 32 bytes of dynamic offset data (mimics how Safe
        // formats v=0 contract signatures with appended EIP-1271 verification data)
        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__InvalidSignatureLength.selector);
        guard.checkTransaction(
            address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), new bytes(97), address(0)
        );
    }

    function testGuardRejectsContractSignatureV0() external {
        // v=0 is the Safe "contract signature" type (EIP-1271)
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(address(0xABC)))), bytes32(0), bytes1(uint8(0)));

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sig, address(0));
    }

    function testGuardRejectsEthSignV31() external {
        // v>30 is the Safe "eth_sign" flow (pre-image prefixed hash)
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(address(0xABC)))), bytes32(0), bytes1(uint8(31)));

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sig, address(0));
    }

    function testGuardRejectsV28() external {
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(address(0xABC)))), bytes32(0), bytes1(uint8(28)));

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sig, address(0));
    }

    function testGuardRejectsV2() external {
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(address(0xABC)))), bytes32(0), bytes1(uint8(2)));

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sig, address(0));
    }

    function testGuardRejectsV30() external {
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(address(0xABC)))), bytes32(0), bytes1(uint8(30)));

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sig, address(0));
    }

    function testGuardRejectsV255() external {
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(address(0xABC)))), bytes32(0), bytes1(uint8(255)));

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sig, address(0));
    }

    function testGuardAcceptsSingleApproveHashSignature() external {
        // 1-of-1: single 65-byte signature with v=1
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(address(0xABC)))), bytes32(0), bytes1(uint8(1)));

        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sig, address(0));
    }

    function testGuardAcceptsMultipleValidSignatures() external {
        // 3-of-3: three 65-byte signatures all with v=1
        bytes memory sigs = abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(0),
            bytes1(uint8(1)),
            bytes32(uint256(2)),
            bytes32(0),
            bytes1(uint8(1)),
            bytes32(uint256(3)),
            bytes32(0),
            bytes1(uint8(1))
        );

        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sigs, address(0));
    }

    function testGuardRejectsFirstInvalidInSet() external {
        // 1st signature has v=27, rest have v=1 -- tests loop initiation
        bytes memory sigs = abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(0),
            bytes1(uint8(27)),
            bytes32(uint256(2)),
            bytes32(0),
            bytes1(uint8(1)),
            bytes32(uint256(3)),
            bytes32(0),
            bytes1(uint8(1))
        );

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sigs, address(0));
    }

    function testGuardRejectsMiddleInvalidInSet() external {
        // 2nd signature has v=27, rest have v=1 -- tests loop progression
        bytes memory sigs = abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(0),
            bytes1(uint8(1)),
            bytes32(uint256(2)),
            bytes32(0),
            bytes1(uint8(27)),
            bytes32(uint256(3)),
            bytes32(0),
            bytes1(uint8(1))
        );

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sigs, address(0));
    }

    function testGuardRejectsLastInvalidInSet() external {
        // 3rd (last) signature has v=27, rest have v=1 -- tests loop termination / off-by-one
        bytes memory sigs = abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(0),
            bytes1(uint8(1)),
            bytes32(uint256(2)),
            bytes32(0),
            bytes1(uint8(1)),
            bytes32(uint256(3)),
            bytes32(0),
            bytes1(uint8(27))
        );

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sigs, address(0));
    }

    function testGuardAcceptsTwoValidSignatures() external {
        // 2-of-2: 130 bytes, both v=1
        bytes memory sigs = abi.encodePacked(
            bytes32(uint256(1)), bytes32(0), bytes1(uint8(1)), bytes32(uint256(2)), bytes32(0), bytes1(uint8(1))
        );

        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sigs, address(0));
    }

    function testMoreSignaturesThanThresholdAccepted() external {
        // Safe allows submitting more signatures than threshold. Guard should accept
        // as long as all v=1, regardless of count vs threshold.
        // Build owners.length signatures (more than threshold) all with v=1.
        address[] memory allOwners = safe.getOwners();
        _sortAddresses(allOwners);

        address to = address(0xbeef);
        bytes32 txHash = safe.getTransactionHash(to, 0, "", 0, 0, 0, 0, address(0), address(0), safe.nonce());

        for (uint256 i; i < allOwners.length; ++i) {
            vm.prank(allOwners[i]);
            safe.approveHash(txHash);
        }

        bytes memory signatures = _buildApproveHashSignatures(allOwners);

        bool success = safe.execTransaction(to, 0, "", 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertTrue(success, "more sigs than threshold should succeed");
    }

    function testFuzzGarbageDataWithValidVBytes(uint256 seed) external {
        // Random data where every 65th byte (v position) is forced to 1.
        // Guard should pass; Safe's core logic would reject the invalid cryptographic data later.
        uint256 sigCount = (seed % 5) + 1; // 1 to 5 signatures
        bytes memory sigs;
        for (uint256 i; i < sigCount; ++i) {
            bytes32 r = keccak256(abi.encode(seed, i, "r"));
            bytes32 s = keccak256(abi.encode(seed, i, "s"));
            sigs = abi.encodePacked(sigs, r, s, bytes1(uint8(1)));
        }

        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sigs, address(0));
    }

    function testFuzzInvalidSignatureLength(uint256 length) external {
        // Any length that is 0 or not a multiple of 65 should revert.
        vm.assume(length < 10_000); // bound to avoid OOM
        vm.assume(length == 0 || length % 65 != 0);

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__InvalidSignatureLength.selector);
        guard.checkTransaction(
            address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), new bytes(length), address(0)
        );
    }

    function testFuzzInvalidVValue(uint8 v) external {
        // Any v != 1 should revert.
        vm.assume(v != 1);

        bytes memory sig = abi.encodePacked(bytes32(uint256(0xABC)), bytes32(0), bytes1(v));

        vm.expectRevert(SafeApproveHashGuard.SafeApproveHashGuard__OnlyApproveHashSignatures.selector);
        guard.checkTransaction(address(0), 0, "", 0, 0, 0, 0, address(0), payable(address(0)), sig, address(0));
    }

    function testCheckAfterExecutionIsNoOp() external {
        guard.checkAfterExecution(bytes32(0), true);
        guard.checkAfterExecution(bytes32(uint256(1)), false);
        guard.checkAfterExecution(keccak256("test"), true);
    }

    // ======================== Interface ========================

    function testSupportsInterface() external {
        assertTrue(guard.supportsInterface(0xe6d7a83a), "should support Guard interface");
        assertTrue(guard.supportsInterface(0x01ffc9a7), "should support ERC-165");
        assertFalse(guard.supportsInterface(0xdeadbeef), "should not support random interface");
        assertFalse(guard.supportsInterface(0xffffffff), "should not support 0xffffffff");
    }

    // ======================== Safe config ========================

    function testSafeOwners() external {
        address[6] memory expectedOwners = [
            0x95A2115018b84cfe0630C16CCA277E1569a84BEf,
            0x4A4e996Dd8F36Dcf46b30A7F97877da922323EEb,
            0x3DE2da610996eA5A72B9Af7cB8740caC48A9329f,
            0x83954FBd07f8A868F4A72103e7bBCc8Ec59CeA1C,
            0x544bDcBb88F2756000De227580aaad7376f3794E,
            0x9eaC7114D1a1EaBc4732A886795cFD9E6E35843f
        ];

        address[] memory actualOwners = safe.getOwners();
        assertEq(actualOwners.length, expectedOwners.length, "owner count mismatch");

        for (uint256 i; i < expectedOwners.length; ++i) {
            bool found;
            for (uint256 j; j < actualOwners.length; ++j) {
                if (actualOwners[j] == expectedOwners[i]) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "expected owner not found");
        }
    }

    // ==================== Helpers ====================

    function _execApproveHashSafeTx(address to, uint256 value, bytes memory data) internal {
        bytes32 txHash = safe.getTransactionHash(to, value, data, 0, 0, 0, 0, address(0), address(0), safe.nonce());

        address[] memory signers = _getSortedSigners();
        for (uint256 i; i < threshold; ++i) {
            vm.prank(signers[i]);
            safe.approveHash(txHash);
        }

        bytes memory signatures = _buildApproveHashSignatures(signers);
        bool success = safe.execTransaction(to, value, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertTrue(success, "approve-hash safe tx failed");
    }

    function _getSortedSigners() internal view returns (address[] memory signers) {
        signers = new address[](threshold);
        for (uint256 i; i < threshold; ++i) {
            signers[i] = owners[i];
        }
        _sortAddresses(signers);
    }

    function _buildApproveHashSignatures(address[] memory signers) internal pure returns (bytes memory signatures) {
        for (uint256 i; i < signers.length; ++i) {
            signatures = abi.encodePacked(
                signatures,
                bytes32(uint256(uint160(signers[i]))), // r = owner address
                bytes32(0), // s = 0
                bytes1(uint8(1)) // v = 1 (approved hash)
            );
        }
    }

    function _buildFakeECDSASignatures(address[] memory signers) internal pure returns (bytes memory signatures) {
        for (uint256 i; i < signers.length; ++i) {
            signatures = abi.encodePacked(
                signatures,
                bytes32(uint256(uint160(signers[i]))), // r
                bytes32(uint256(1)), // s
                bytes1(uint8(27)) // v = 27 (ECDSA)
            );
        }
    }

    function _sortAddresses(address[] memory arr) internal pure {
        uint256 n = arr.length;
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                if (uint160(arr[i]) > uint160(arr[j])) {
                    (arr[i], arr[j]) = (arr[j], arr[i]);
                }
            }
        }
    }
}
