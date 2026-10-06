// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";
import {BridgingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test} from "@forge-std/Test.sol";

interface ICCIPRouterView {
    function getOnRamp(uint64 destChainSelector) external view returns (address);
    function getFee(uint64 destinationChainSelector, DecoderCustomTypes.EVM2AnyMessage memory message)
        external
        view
        returns (uint256);
}

interface ITypeAndVersion {
    function typeAndVersion() external view returns (string memory);
}

/// @dev CCIP v2.0.0 FeeQuoter: the parser the OnRamp uses for every non-V3 extraArgs.
interface ICCIPFeeQuoterV2 {
    function resolveLegacyArgs(uint64 destChainSelector, bytes calldata extraArgs)
        external
        view
        returns (bytes memory tokenReceiver, uint32 gasLimit, bytes memory executorArgs);
}

/// @dev Verbatim copy of CCIPDecoderAndSanitizer before GenericExtraArgsV2 support (boring-vault-private main
///      539e3c4763fa8361387c868bd5e14770147ad4fb), renamed. Reference implementation for the regression
///      differential: for every input without the V2 tag, the new decoder must match it exactly. Error names are
///      kept, so revert selectors compare equal.
contract LegacyCCIPDecoderAndSanitizer {
    bytes4 internal constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;
    bytes4 internal constant SVM_EXTRA_ARGS_V1_TAG = 0x1f3b3aba;

    error CCIPDecoderAndSanitizer__NonZeroDataLength();
    error CCIPDecoderAndSanitizer__NonZeroGasLimit();
    error CCIPDecoderAndSanitizer__InvalidExtraArgsTag();
    error CCIPDecoderAndSanitizer__NonZeroComputeUnits();
    error CCIPDecoderAndSanitizer__NonEmptyAccounts();
    error CCIPDecoderAndSanitizer__NonZeroWritableBitmap();
    error CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired();
    error CCIPDecoderAndSanitizer__InvalidSVMReceiver();

    function ccipSend(uint64 destinationChainSelector, DecoderCustomTypes.EVM2AnyMessage calldata message)
        external
        pure
        virtual
        returns (bytes memory sensitiveArguments)
    {
        if (message.data.length > 0) revert CCIPDecoderAndSanitizer__NonZeroDataLength();

        bytes4 tag = bytes4(message.extraArgs[:4]);
        if (tag == EVM_EXTRA_ARGS_V1_TAG) {
            DecoderCustomTypes.EVMExtraArgsV1 memory extraArgs =
                abi.decode(message.extraArgs[4:], (DecoderCustomTypes.EVMExtraArgsV1));

            if (extraArgs.gasLimit != 0) revert CCIPDecoderAndSanitizer__NonZeroGasLimit();

            sensitiveArguments =
                abi.encodePacked(address(uint160(destinationChainSelector)), abi.decode(message.receiver, (address)));
        } else if (tag == SVM_EXTRA_ARGS_V1_TAG) {
            DecoderCustomTypes.SVMExtraArgsV1 memory extraArgs =
                abi.decode(message.extraArgs[4:], (DecoderCustomTypes.SVMExtraArgsV1));

            if (extraArgs.computeUnits != 0) revert CCIPDecoderAndSanitizer__NonZeroComputeUnits();
            if (extraArgs.accounts.length != 0) revert CCIPDecoderAndSanitizer__NonEmptyAccounts();
            if (extraArgs.accountIsWritableBitmap != 0) revert CCIPDecoderAndSanitizer__NonZeroWritableBitmap();
            if (!extraArgs.allowOutOfOrderExecution) revert CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired();
            if (message.receiver.length != 32 || bytes32(message.receiver) != bytes32(0)) {
                revert CCIPDecoderAndSanitizer__InvalidSVMReceiver();
            }

            sensitiveArguments = abi.encodePacked(
                address(uint160(destinationChainSelector)),
                address(bytes20(bytes16(extraArgs.tokenReceiver))),
                address(bytes20(bytes16(extraArgs.tokenReceiver << 128)))
            );
        } else {
            revert CCIPDecoderAndSanitizer__InvalidExtraArgsTag();
        }

        uint256 tokenAmountsLength = message.tokenAmounts.length;
        for (uint256 i; i < tokenAmountsLength; ++i) {
            sensitiveArguments = abi.encodePacked(sensitiveArguments, message.tokenAmounts[i].token);
        }

        sensitiveArguments = abi.encodePacked(sensitiveArguments, message.feeToken);
    }
}

/// @dev Seeded input generators shared by the differential fuzz tests. Each generator mixes well-formed encodings
///      (so success paths are exercised) with malformed ones (so revert paths are compared too).
abstract contract CCIPExtraArgsFuzzHelpers is Test {
    bytes4 internal constant EVM_V1_TAG = 0x97a657c9;
    bytes4 internal constant V2_TAG = 0x181dcf10;
    bytes4 internal constant SVM_V1_TAG = 0x1f3b3aba;
    bytes4 internal constant V3_TAG = 0xa69dd4aa;

    function _word(bytes32 seed, uint256 salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, salt)));
    }

    function _pick(bytes32 seed, uint256 salt, uint256 mod) internal pure returns (uint256) {
        return _word(seed, salt) % mod;
    }

    /// @dev Zero half the time, so gasLimit checks see both outcomes.
    function _gas(bytes32 seed, uint256 salt) internal pure returns (uint256) {
        return _pick(seed, salt, 2) == 0 ? 0 : _word(seed, salt + 1);
    }

    function _slice(bytes memory b, uint256 len) internal pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i; i < len; ++i) {
            out[i] = b[i];
        }
    }

    function _sliceFrom(bytes memory b, uint256 start) internal pure returns (bytes memory out) {
        out = new bytes(b.length - start);
        for (uint256 i; i < out.length; ++i) {
            out[i] = b[start + i];
        }
    }

    function _canonicalV1() internal pure returns (bytes memory) {
        return abi.encodePacked(EVM_V1_TAG, abi.encode(uint256(0)));
    }

    function _canonicalV2() internal pure returns (bytes memory) {
        return Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: true}));
    }

    function _receiver(bytes32 seed, bytes memory randomBytes) internal pure returns (bytes memory) {
        uint256 kind = _pick(seed, 1, 6);
        address a = address(uint160(_word(seed, 2)));
        if (kind <= 1) return abi.encode(a); // canonical EVM receiver
        if (kind == 2) return abi.encode(bytes32(0)); // SVM default pubkey
        if (kind == 3) return abi.encodePacked(bytes32(_word(seed, 2))); // dirty upper 12 bytes
        if (kind == 4) return abi.encodePacked(abi.encode(a), bytes1(0x01)); // 33 bytes
        return randomBytes;
    }

    function _tokens(bytes32 seed) internal pure returns (DecoderCustomTypes.EVMTokenAmount[] memory tokens) {
        tokens = new DecoderCustomTypes.EVMTokenAmount[](_pick(seed, 3, 3));
        for (uint256 i; i < tokens.length; ++i) {
            tokens[i].token = address(uint160(_word(seed, 10 + i)));
            tokens[i].amount = _word(seed, 20 + i);
        }
    }

    function _baseMessage(bytes32 seed, bytes memory randomBytes)
        internal
        pure
        returns (DecoderCustomTypes.EVM2AnyMessage memory m)
    {
        m.receiver = _receiver(seed, randomBytes);
        m.data = _pick(seed, 4, 4) == 0 ? bytes(hex"01") : bytes("");
        m.tokenAmounts = _tokens(seed);
        m.feeToken = address(uint160(_word(seed, 5)));
    }

    function _svmArgs(bytes32 seed) internal pure returns (DecoderCustomTypes.SVMExtraArgsV1 memory a) {
        a.computeUnits = _pick(seed, 30, 2) == 0 ? 0 : uint32(_word(seed, 31));
        a.accountIsWritableBitmap = _pick(seed, 32, 2) == 0 ? 0 : uint64(_word(seed, 33));
        a.allowOutOfOrderExecution = _pick(seed, 34, 4) != 0;
        a.tokenReceiver = bytes32(_word(seed, 35));
        a.accounts = new bytes32[](_pick(seed, 36, 4) == 0 ? 1 : 0);
    }

    function _tokenOnlySvmArgs(bytes32 seed) internal pure returns (DecoderCustomTypes.SVMExtraArgsV1 memory a) {
        a.allowOutOfOrderExecution = true;
        a.tokenReceiver = bytes32(_word(seed, 37));
        a.accounts = new bytes32[](0);
    }

    /// @dev Every extraArgs family except V2: V1 (canonical 36-byte, V0.0's 64-byte form, trailing bytes), SVM
    ///      (valid token-only and arbitrary fields), V3, raw.
    function _nonV2ExtraArgs(bytes32 seed, bytes memory randomBytes) internal pure returns (bytes memory) {
        uint256 kind = _pick(seed, 6, 9);
        if (kind == 0) return abi.encodePacked(EVM_V1_TAG, abi.encode(_gas(seed, 7)));
        if (kind == 1) return abi.encode(EVM_V1_TAG, _gas(seed, 7));
        if (kind == 2) return abi.encodePacked(SVM_V1_TAG, abi.encode(_svmArgs(seed)));
        if (kind == 3) return abi.encodePacked(SVM_V1_TAG, abi.encode(_tokenOnlySvmArgs(seed)));
        if (kind == 4) return abi.encodePacked(_canonicalV1(), randomBytes);
        if (kind == 5) return abi.encodePacked(EVM_V1_TAG, randomBytes);
        if (kind == 6) return abi.encodePacked(SVM_V1_TAG, randomBytes);
        if (kind == 7) return abi.encodePacked(V3_TAG, randomBytes);
        return randomBytes;
    }

    /// @dev V2-tagged extraArgs: canonical (gas and bool varied), padded, truncated, and raw.
    function _v2ExtraArgs(bytes32 seed, bytes memory randomBytes) internal pure returns (bytes memory) {
        uint256 kind = _pick(seed, 40, 5);
        bytes memory encoded = abi.encodePacked(V2_TAG, abi.encode(_gas(seed, 41), _pick(seed, 43, 3) != 0));
        if (kind <= 1) return encoded;
        if (kind == 2) return abi.encodePacked(encoded, randomBytes);
        if (kind == 3) return _slice(encoded, 4 + _pick(seed, 44, 64));
        return abi.encodePacked(V2_TAG, randomBytes);
    }

    /// @dev Biased toward the 64-byte V1 form the deployed V0.0 decoder accepts.
    function _v00FocusedExtraArgs(bytes32 seed, bytes memory randomBytes) internal pure returns (bytes memory) {
        uint256 kind = _pick(seed, 50, 6);
        if (kind <= 1) return abi.encode(EVM_V1_TAG, uint256(0));
        if (kind == 2) return abi.encodePacked(abi.encode(EVM_V1_TAG, uint256(0)), randomBytes);
        if (kind == 3) return abi.encode(EVM_V1_TAG, _gas(seed, 51));
        if (kind == 4) return _nonV2ExtraArgs(seed, randomBytes);
        return _v2ExtraArgs(seed, randomBytes);
    }

    function _call(address decoder, uint64 dest, DecoderCustomTypes.EVM2AnyMessage memory m)
        internal
        view
        returns (bool ok, bytes memory ret)
    {
        (ok, ret) = decoder.staticcall(abi.encodeWithSelector(CCIPDecoderAndSanitizer.ccipSend.selector, dest, m));
    }

    function _evmMessage(address receiver, address token, address feeToken)
        internal
        pure
        returns (DecoderCustomTypes.EVM2AnyMessage memory m)
    {
        m.receiver = abi.encode(receiver);
        m.data = "";
        m.tokenAmounts = new DecoderCustomTypes.EVMTokenAmount[](1);
        m.tokenAmounts[0].token = token;
        m.tokenAmounts[0].amount = 1e18;
        m.feeToken = feeToken;
    }
}

/// @notice Fork-free tests of GenericExtraArgsV2 support and of regression against the pre-V2 decoder.
contract CCIPExtraArgsV2Test is CCIPExtraArgsFuzzHelpers {
    uint64 internal constant DEST = 4949039107694359620; // Arbitrum selector; any value works for the decoder.
    address internal constant RECEIVER = address(0xB0B);
    address internal constant TOKEN = address(0x7070);
    address internal constant FEE_TOKEN = address(0xFEE);

    CCIPDecoderAndSanitizer internal decoder;
    LegacyCCIPDecoderAndSanitizer internal legacy;

    function setUp() external {
        decoder = new CCIPDecoderAndSanitizer();
        legacy = new LegacyCCIPDecoderAndSanitizer();
    }

    // ========================================= VERSION / LAYOUT =========================================

    function testVersion() external view {
        assertEq(decoder.CCIP_DECODER_VERSION(), "V0.2");
    }

    function testGenericExtraArgsV2MatchesCanonicalCcipLayout() external pure {
        // Distinct nonzero sentinels: a field swap or retype changes the bytes.
        bytes memory ours = abi.encodePacked(
            V2_TAG,
            abi.encode(DecoderCustomTypes.GenericExtraArgsV2({gasLimit: 0x1111, allowOutOfOrderExecution: true}))
        );
        bytes memory canonical =
            Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 0x1111, allowOutOfOrderExecution: true}));
        assertEq(ours, canonical, "GenericExtraArgsV2 layout must match chainlink-ccip");
        assertEq(Client.EVM_EXTRA_ARGS_V2_TAG, V2_TAG, "V2 tag must match chainlink-ccip");
        assertEq(canonical.length, 68, "canonical V2 encoding is 68 bytes");
    }

    // ========================================= V2 ACCEPTANCE =========================================

    function testV2CanonicalAcceptedWithV1Output() external view {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        m.extraArgs = _canonicalV2();
        bytes memory outV2 = decoder.ccipSend(DEST, m);

        m.extraArgs = _canonicalV1();
        assertEq(outV2, decoder.ccipSend(DEST, m), "V2 output must equal V1 output");
        assertEq(outV2, legacy.ccipSend(DEST, m), "V2 output must equal pre-V2 decoder V1 output");
        assertEq(outV2, abi.encodePacked(address(uint160(DEST)), RECEIVER, TOKEN, FEE_TOKEN));
    }

    function testFuzz_V2OutputEqualsV1Output(uint64 dest, address receiver, address token, address feeToken)
        external
        view
    {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(receiver, token, feeToken);
        m.extraArgs = _canonicalV2();
        bytes memory outV2 = decoder.ccipSend(dest, m);
        m.extraArgs = _canonicalV1();
        assertEq(outV2, legacy.ccipSend(dest, m));
    }

    // ========================================= V2 REJECTION =========================================

    function testFuzz_V2RevertsOnNonZeroGasLimit(uint256 gasLimit, bool allowOutOfOrderExecution) external {
        gasLimit = bound(gasLimit, 1, type(uint256).max);
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        m.extraArgs = Client._argsToBytes(
            Client.EVMExtraArgsV2({gasLimit: gasLimit, allowOutOfOrderExecution: allowOutOfOrderExecution})
        );
        vm.expectRevert(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroGasLimit.selector);
        decoder.ccipSend(DEST, m);
    }

    function testV2RevertsWhenOutOfOrderExecutionDisabled() external {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        m.extraArgs = Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: false}));
        vm.expectRevert(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired.selector);
        decoder.ccipSend(DEST, m);
    }

    function testFuzz_V2RevertsOnAnyOtherLength(uint256 length, bytes32 filler) external {
        length = bound(length, 4, 400);
        vm.assume(length != 68);
        bytes memory padded = abi.encodePacked(_canonicalV2(), filler, filler, filler, filler, filler, filler);
        padded = abi.encodePacked(padded, padded, padded, padded, padded, padded);
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        m.extraArgs = _slice(padded, length);
        vm.expectRevert(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidExtraArgsLength.selector);
        decoder.ccipSend(DEST, m);
    }

    function testV2RevertsOnTrailingZeroByte() external {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        m.extraArgs = abi.encodePacked(_canonicalV2(), bytes1(0));
        vm.expectRevert(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidExtraArgsLength.selector);
        decoder.ccipSend(DEST, m);
    }

    function testV2RevertsOnDirtyBool() external view {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        m.extraArgs = abi.encodePacked(V2_TAG, uint256(0), uint256(2));
        (bool ok, bytes memory ret) = _call(address(decoder), DEST, m);
        assertFalse(ok);
        assertEq(ret.length, 0, "strict ABI decode of a dirty bool reverts without data");
    }

    function testNonZeroGasLimitEdgeValuesRejectedUnderV1AndV2() external view {
        uint256[4] memory gasLimits = [uint256(1), uint256(1) << 32, uint256(1) << 255, type(uint256).max];
        bytes memory expected =
            abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroGasLimit.selector);
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        for (uint256 i; i < gasLimits.length; ++i) {
            m.extraArgs = abi.encodePacked(EVM_V1_TAG, abi.encode(gasLimits[i]));
            (bool ok, bytes memory ret) = _call(address(decoder), DEST, m);
            assertFalse(ok);
            assertEq(ret, expected, "V1 non-zero gasLimit");

            m.extraArgs =
                Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: gasLimits[i], allowOutOfOrderExecution: true}));
            (ok, ret) = _call(address(decoder), DEST, m);
            assertFalse(ok);
            assertEq(ret, expected, "V2 non-zero gasLimit");
        }
    }

    function testV2RevertsOnNonEmptyData() external {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        m.data = hex"01";
        m.extraArgs = _canonicalV2();
        vm.expectRevert(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroDataLength.selector);
        decoder.ccipSend(DEST, m);
    }

    function testV2RevertsOnDirtyReceiver() external view {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        m.receiver = abi.encodePacked(bytes32(type(uint256).max));
        m.extraArgs = _canonicalV2();
        (bool ok, bytes memory ret) = _call(address(decoder), DEST, m);
        assertFalse(ok);
        assertEq(ret.length, 0, "strict ABI decode of a dirty receiver reverts without data");
    }

    function testV3StillRejected() external {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);
        // Minimal GenericExtraArgsV3 (tag + 15 zero bytes): no CCVs, default executor, no tokenReceiver.
        m.extraArgs = abi.encodePacked(V3_TAG, bytes15(0));
        vm.expectRevert(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidExtraArgsTag.selector);
        decoder.ccipSend(DEST, m);

        // V3 tag with a V2-shaped body must not be mistaken for V2.
        m.extraArgs = abi.encodePacked(V3_TAG, abi.encode(uint256(0), true));
        vm.expectRevert(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidExtraArgsTag.selector);
        decoder.ccipSend(DEST, m);
    }

    // ========================================= REGRESSION DIFFERENTIAL =========================================

    /// @notice Directed regression cases, one per pre-existing success path, checked against the pre-V2 decoder.
    function testExistingSuccessPathsUnchanged() external view {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(RECEIVER, TOKEN, FEE_TOKEN);

        m.extraArgs = _canonicalV1();
        assertEq(decoder.ccipSend(DEST, m), legacy.ccipSend(DEST, m), "canonical 36-byte V1");

        m.extraArgs = abi.encode(EVM_V1_TAG, uint256(0));
        assertEq(decoder.ccipSend(DEST, m), legacy.ccipSend(DEST, m), "V0.0 64-byte V1");

        DecoderCustomTypes.SVMExtraArgsV1 memory svm;
        svm.allowOutOfOrderExecution = true;
        svm.tokenReceiver = keccak256("solana receiver");
        svm.accounts = new bytes32[](0);
        m.receiver = abi.encode(bytes32(0));
        m.extraArgs = abi.encodePacked(SVM_V1_TAG, abi.encode(svm));
        assertEq(decoder.ccipSend(DEST, m), legacy.ccipSend(DEST, m), "SVM V1");
    }

    /// @notice For every input without the V2 tag, the new decoder returns (or reverts with) exactly the same bytes
    ///         as the pre-V2 decoder.
    function testFuzz_NonV2InputsBehaveExactlyAsBefore(uint64 dest, bytes32 seed, bytes memory randomBytes)
        external
        view
    {
        DecoderCustomTypes.EVM2AnyMessage memory m = _baseMessage(seed, randomBytes);
        m.extraArgs = _nonV2ExtraArgs(seed, randomBytes);
        // Only raw random bytes could start with the V2 tag; those are covered by the V2 differential below.
        if (m.extraArgs.length >= 4 && bytes4(m.extraArgs) == V2_TAG) return;
        // SVM args need the default-pubkey receiver to reach the SVM success path, so bias toward it.
        if (m.extraArgs.length >= 4 && bytes4(m.extraArgs) == SVM_V1_TAG && _pick(seed, 8, 4) != 0) {
            m.receiver = abi.encode(bytes32(0));
        }

        (bool okNew, bytes memory retNew) = _call(address(decoder), dest, m);
        (bool okOld, bytes memory retOld) = _call(address(legacy), dest, m);
        assertEq(okNew, okOld, "success must match the pre-V2 decoder");
        assertEq(retNew, retOld, "return/revert data must match the pre-V2 decoder");
    }

    /// @dev Reference model of the V2 branch's revert data for non-canonical input, in check order.
    function _expectedV2Revert(DecoderCustomTypes.EVM2AnyMessage memory m) internal pure returns (bytes memory) {
        if (m.data.length != 0) {
            return abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroDataLength.selector);
        }
        if (m.extraArgs.length != 68) {
            bytes4 lengthError = CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidExtraArgsLength.selector;
            return abi.encodeWithSelector(lengthError);
        }
        (uint256 gasWord, uint256 boolWord) = abi.decode(_sliceFrom(m.extraArgs, 4), (uint256, uint256));
        if (boolWord > 1) return ""; // strict ABI decode of a dirty bool reverts without data
        if (gasWord != 0) {
            return abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroGasLimit.selector);
        }
        return
            abi.encodeWithSelector(
                CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired.selector
            );
    }

    /// @notice V2-tagged inputs: the pre-V2 decoder rejected all of them. The new decoder accepts exactly the
    ///         canonical V2(gasLimit 0, allowOutOfOrderExecution true) encoding with empty data, and then behaves
    ///         exactly like the pre-V2 decoder does for canonical V1 on the same message.
    function testFuzz_V2AcceptedOnlyInCanonicalFormWithV1Output(uint64 dest, bytes32 seed, bytes memory randomBytes)
        external
        view
    {
        DecoderCustomTypes.EVM2AnyMessage memory m = _baseMessage(seed, randomBytes);
        m.extraArgs = _v2ExtraArgs(seed, randomBytes);

        (bool okOld, bytes memory retOld) = _call(address(legacy), dest, m);
        assertFalse(okOld, "pre-V2 decoder rejects every V2-tagged input");
        bytes4 expectedOld = m.data.length > 0
            ? CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroDataLength.selector
            : CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidExtraArgsTag.selector;
        assertEq(retOld, abi.encodeWithSelector(expectedOld));

        (bool okNew, bytes memory retNew) = _call(address(decoder), dest, m);
        if (m.data.length != 0 || keccak256(m.extraArgs) != keccak256(_canonicalV2())) {
            assertFalse(okNew, "only canonical V2(0, true) with empty data is accepted");
            assertEq(retNew, _expectedV2Revert(m), "V2 revert reason must follow the check order");
            return;
        }

        m.extraArgs = _canonicalV1();
        (bool okV1, bytes memory retV1) = _call(address(legacy), dest, m);
        assertEq(okNew, okV1, "canonical V2 must succeed exactly when canonical V1 did");
        assertEq(retNew, retV1, "canonical V2 must produce the canonical V1 output");
    }
}

/// @notice Mainnet fork tests: regression against the deployed V0.0 decoder, end-to-end sends through the manager on
///         a CCIP v2.0 lane, and parse-equivalence with the live CCIP fee quoter.
contract CCIPExtraArgsV2ForkTest is CCIPExtraArgsFuzzHelpers, MerkleTreeHelper {
    /// @dev "CCIP Decoder and Sanitizer V0.0" CREATE3 singleton deployed through Deployer
    ///      0xe80F045fc6F551229f98FA21E0Db35784A590e05 (the address merkle-core derives). V1-only, 64-byte extraArgs.
    address internal constant DEPLOYED_CCIP_DECODER_V0_0 = 0x9EcB74E55cf395598338C2a1E8D5Db50D3E8AceA;
    /// @dev Mainnet FeeQuoter 2.0.0 behind OnRamp 2.0.0 0xc3423F3FB30857D9C14717b119884b1B63d250b7.
    address internal constant MAINNET_FEE_QUOTER_V2_0 = 0x93669Cf8EabE869687544De34B453063fb23Bb69;
    /// @dev Block where Mainnet->Arbitrum runs OnRamp 2.0.0 and Mainnet->Katana runs EVM2EVMOnRamp 1.5.0.
    uint256 internal constant FORK_BLOCK = 26050000;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    CCIPDecoderAndSanitizer internal decoder;

    function setUp() external {
        setSourceChainName("mainnet");
        vm.selectFork(vm.createFork(vm.envString("MAINNET_RPC_URL"), FORK_BLOCK));

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));
        rawDataDecoderAndSanitizer = address(new BridgingDecoderAndSanitizer());
        decoder = new CCIPDecoderAndSanitizer();

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);
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
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
    }

    // ========================================= REGRESSION VS DEPLOYED V0.0 =========================================

    function testDeployedV00DecoderIsV1Only() external view {
        DecoderCustomTypes.EVM2AnyMessage memory m = _evmMessage(address(boringVault), address(1), address(2));
        m.extraArgs = abi.encode(EVM_V1_TAG, uint256(0));
        (bool ok,) = _call(DEPLOYED_CCIP_DECODER_V0_0, ccipArbitrumChainSelector, m);
        assertTrue(ok, "V0.0 accepts its 64-byte V1 form");
        m.extraArgs = _canonicalV2();
        (ok,) = _call(DEPLOYED_CCIP_DECODER_V0_0, ccipArbitrumChainSelector, m);
        assertFalse(ok, "V0.0 rejects V2");
    }

    /// @notice Everything the production V0.0 decoder accepts, the new decoder accepts with identical output.
    function testFuzz_DeployedV00AcceptsImpliesIdenticalOutput(uint64 dest, bytes32 seed, bytes memory randomBytes)
        external
        view
    {
        DecoderCustomTypes.EVM2AnyMessage memory m = _baseMessage(seed, randomBytes);
        m.extraArgs = _v00FocusedExtraArgs(seed, randomBytes);

        (bool okV00, bytes memory retV00) = _call(DEPLOYED_CCIP_DECODER_V0_0, dest, m);
        if (!okV00) return;
        (bool okNew, bytes memory retNew) = _call(address(decoder), dest, m);
        assertTrue(okNew, "new decoder must accept every input V0.0 accepts");
        assertEq(retNew, retV00, "new decoder must return V0.0's packed arguments");
    }

    // ========================================= PARSE EQUIVALENCE =========================================

    /// @notice The only V2 input the decoder accepts is parsed by the live CCIP 2.0 fee quoter as a token-only
    ///         message: gas limit 0, no token receiver override, no executor args.
    function testLiveFeeQuoterParsesAcceptedV2AsTokenOnly() external view {
        (bytes memory tokenReceiver, uint32 gasLimit, bytes memory executorArgs) =
            ICCIPFeeQuoterV2(MAINNET_FEE_QUOTER_V2_0).resolveLegacyArgs(ccipArbitrumChainSelector, _canonicalV2());
        assertEq(tokenReceiver.length, 0);
        assertEq(gasLimit, 0);
        assertEq(executorArgs.length, 0);
    }

    function testV2AcceptedByLegacyV15Lane() external view {
        address router = getAddress(sourceChain, "ccipRouter");
        address onRamp = ICCIPRouterView(router).getOnRamp(ccipKatanaChainSelector);
        assertEq(ITypeAndVersion(onRamp).typeAndVersion(), "EVM2EVMOnRamp 1.5.0");

        DecoderCustomTypes.EVM2AnyMessage memory m =
            _evmMessage(address(boringVault), getAddress(sourceChain, "LBTC"), getAddress(sourceChain, "WETH"));
        m.tokenAmounts[0].amount = 1e8;
        m.extraArgs = _canonicalV2();
        assertGt(ICCIPRouterView(router).getFee(ccipKatanaChainSelector, m), 0);
    }

    // ========================================= END TO END =========================================

    function testV2BridgeEndToEndOnCcipV2Lane() external {
        address router = getAddress(sourceChain, "ccipRouter");
        assertEq(
            ITypeAndVersion(ICCIPRouterView(router).getOnRamp(ccipArbitrumChainSelector)).typeAndVersion(),
            "OnRamp 2.0.0"
        );
        _sendWethToArbitrumAndCheck(_buildWethToArbitrumTree(), _canonicalV2());
    }

    function testV1FormsStillBridgeEndToEndOnCcipV2Lane() external {
        bytes32[][] memory proofs = _buildWethToArbitrumTree();
        _sendWethToArbitrumAndCheck(proofs, _canonicalV1());
        _sendWethToArbitrumAndCheck(proofs, abi.encode(EVM_V1_TAG, uint256(0)));
    }

    function testV2OutOfOrderDisabledRevertsThroughManager() external {
        bytes32[][] memory proofs = _buildWethToArbitrumTree();
        bytes memory extraArgs =
            Client._argsToBytes(Client.EVMExtraArgsV2({gasLimit: 0, allowOutOfOrderExecution: false}));
        (address[] memory decoders, address[] memory targets, bytes[] memory targetData, uint256[] memory values) =
            _wethToArbitrumManageCall(extraArgs, 1e18);
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 2e18);
        vm.expectRevert(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired.selector);
        manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);
    }

    // ========================================= HELPERS =========================================

    /// @dev Sets a root with the standard CCIP leaves (approve WETH to the router + ccipSend WETH to Arbitrum paying
    ///      in WETH) and returns their proofs. Leaves are built once per test: the helper dedups approvals.
    function _buildWethToArbitrumTree() internal returns (bytes32[][] memory proofs) {
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, assets, assets);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        proofs = _getProofsUsingTree(leafs, manageTree);
    }

    function _sendWethToArbitrumAndCheck(bytes32[][] memory proofs, bytes memory extraArgs) internal {
        uint256 amount = 1e18;
        ERC20 weth = getERC20(sourceChain, "WETH");
        deal(address(weth), address(boringVault), weth.balanceOf(address(boringVault)) + 2e18);

        (address[] memory decoders, address[] memory targets, bytes[] memory targetData, uint256[] memory values) =
            _wethToArbitrumManageCall(extraArgs, amount);

        uint256 fee = ICCIPRouterView(getAddress(sourceChain, "ccipRouter"))
            .getFee(ccipArbitrumChainSelector, _wethMessage(amount, extraArgs));
        uint256 balanceBefore = weth.balanceOf(address(boringVault));
        manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);
        assertEq(weth.balanceOf(address(boringVault)), balanceBefore - amount - fee, "bridged amount plus fee");
    }

    function _wethMessage(uint256 amount, bytes memory extraArgs)
        internal
        view
        returns (DecoderCustomTypes.EVM2AnyMessage memory m)
    {
        m = _evmMessage(address(boringVault), getAddress(sourceChain, "WETH"), getAddress(sourceChain, "WETH"));
        m.tokenAmounts[0].amount = amount;
        m.extraArgs = extraArgs;
    }

    function _wethToArbitrumManageCall(bytes memory extraArgs, uint256 amount)
        internal
        view
        returns (
            address[] memory decoders,
            address[] memory targets,
            bytes[] memory targetData,
            uint256[] memory values
        )
    {
        address router = getAddress(sourceChain, "ccipRouter");
        targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = router;
        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", router, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))",
            ccipArbitrumChainSelector,
            _wethMessage(amount, extraArgs)
        );
        decoders = new address[](2);
        decoders[0] = rawDataDecoderAndSanitizer;
        decoders[1] = rawDataDecoderAndSanitizer;
        values = new uint256[](2);
    }
}
