// SPDX-License-Identifier: SEL-1.0
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WormholeNTTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/WormholeNTTDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullWormholeNTTDecoderAndSanitizer is WormholeNTTDecoderAndSanitizer, BaseDecoderAndSanitizer {}

// forge test --match-path "test/integrations/WormholeIntegration.t.sol" -vvv
contract WormholeIntegrationTest is BaseTestIntegration {
    address internal multiTokenExecutor;
    address internal multiTokenNtt;

    // Parameters mirror mainnet tx 0x0b3c3ca717bfe9f9c5eac241a6f1f84751c6f1649e9cacf0cc629f9a74f48d05 (block 25124512) from
    // EOA 0xDb8345450b0E4d28514A1C18EE1110C417b5B0A2, with the EOA replaced by the boring vault.
    uint256 internal constant BRIDGE_AMOUNT = 10_000_000_000_000_000; // 0.01 WETH
    uint256 internal constant EXECUTOR_FEE = 31_140_016_176_718; // executorArgs.value, paid to the quote payee
    uint256 internal constant TOTAL_NATIVE_FEE = 48_982_242_254_460; // executor fee + NTT delivery price

    bytes internal constant TRANSCEIVER_INSTRUCTIONS = hex"0200010101200000000000000000000000000000000000000000000000000000103a378c202e";
    bytes internal constant SIGNED_QUOTE =
        hex"45513031a54008017941ece968623a0dd8ee907e2b1335960000000000000000000000006a8bfc410a3cc7306d52872f116afb12f1cec6c600020030000000006a0b8598000000000003978800000017bfac7c00000013516a7f3400000000000ffbabf8956e4189a1ba168390e7b3b2eb3f1c4abd951586961f213b76c77b7277826a2d1d5b71ed0463afb44b55ee91b38d9725d7d3f7da9ba68444bb0017c0b11466bb1c";

    string internal constant TRANSFER_SIG = "transfer(address,address,uint256,uint16,bytes32,bytes32,bytes,(uint256,address,bytes,bytes),(uint16,address))";
    string internal constant TRANSFER_ETH_SIG = "transferETH(address,uint256,uint16,bytes32,bytes32,bytes,(uint256,address,bytes,bytes),(uint16,address))";

    function setUp() public override {
        super.setUp();
        _setupChain("mainnet", 25124511);

        _overrideDecoder(address(new FullWormholeNTTDecoderAndSanitizer()));

        multiTokenExecutor = getAddress(sourceChain, "wormholeMultiTokenExecutor");
        multiTokenNtt = getAddress(sourceChain, "wormholeMultiTokenNtt");

        deal(getAddress(sourceChain, "WETH"), address(boringVault), BRIDGE_AMOUNT);
        deal(address(boringVault), 1e18); // headroom for native fee

        ManageLeaf[] memory leafs = _leafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
    }

    // ========================================= POSITIVE =========================================

    function testBridgeWETHToMonad() external {
        address quotePayee = getAddress(sourceChain, "wormholeExecutorPayee");
        uint256 payeeBefore = quotePayee.balance;

        _submit(false, _transferCalldata(SIGNED_QUOTE, _feeArgs(0)), TOTAL_NATIVE_FEE);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(boringVault)), 0, "WETH should have left the vault");
        assertEq(quotePayee.balance, payeeBefore + EXECUTOR_FEE, "Executor pays executorArgs.value to the quote payee");
    }

    function testBridgeETHToMonad() external {
        address quotePayee = getAddress(sourceChain, "wormholeExecutorPayee");
        uint256 payeeBefore = quotePayee.balance;
        uint256 vaultBefore = address(boringVault).balance;

        _submit(true, _transferETHCalldata(SIGNED_QUOTE, _feeArgs(0)), BRIDGE_AMOUNT + TOTAL_NATIVE_FEE);

        assertEq(address(boringVault).balance, vaultBefore - BRIDGE_AMOUNT - TOTAL_NATIVE_FEE, "vault ETH");
        assertEq(quotePayee.balance, payeeBefore + EXECUTOR_FEE, "Executor pays executorArgs.value to the quote payee");
    }

    // ========================================= SIGNED QUOTE =========================================

    function testRevertsWrongQuotePayee() external {
        bytes memory data = _transferCalldata(_withPayee(SIGNED_QUOTE, address(0xdEaD)), _feeArgs(0));
        _expectProofFailure(false, data, TOTAL_NATIVE_FEE);
    }

    function testRevertsWrongQuotePayeeETH() external {
        bytes memory data = _transferETHCalldata(_withPayee(SIGNED_QUOTE, address(0xdEaD)), _feeArgs(0));
        _expectProofFailure(true, data, BRIDGE_AMOUNT + TOTAL_NATIVE_FEE);
    }

    function testRevertsWrongQuoter() external {
        bytes memory quote = SIGNED_QUOTE;
        quote[4] = 0x00;
        _expectProofFailure(false, _transferCalldata(quote, _feeArgs(0)), TOTAL_NATIVE_FEE);
    }

    function testRevertsInvalidSignedQuote() external {
        bytes memory short = SIGNED_QUOTE;
        assembly {
            mstore(short, 164)
        }
        _expectDecoderRevert(_transferCalldata(short, _feeArgs(0)), WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__InvalidSignedQuote.selector);
        _expectDecoderRevert(
            _transferCalldata(abi.encodePacked(SIGNED_QUOTE, bytes1(0)), _feeArgs(0)),
            WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__InvalidSignedQuote.selector
        );

        bytes memory prefix = SIGNED_QUOTE;
        prefix[3] = 0x32; // "EQ02"
        _expectDecoderRevert(_transferCalldata(prefix, _feeArgs(0)), WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__InvalidSignedQuote.selector);

        for (uint256 i = 24; i < 36; ++i) {
            bytes memory dirty = SIGNED_QUOTE;
            dirty[i] = 0x01;
            _expectDecoderRevert(
                _transferCalldata(dirty, _feeArgs(0)), WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__InvalidSignedQuote.selector
            );
        }
    }

    // ========================================= REFERRER FEE =========================================

    function testRevertsNonZeroReferrerFee() external {
        _expectDecoderRevert(
            _transferCalldata(SIGNED_QUOTE, _feeArgs(1)), WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__NonZeroReferrerFee.selector
        );
        _expectDecoderRevert(
            _transferCalldata(SIGNED_QUOTE, _feeArgs(type(uint16).max)),
            WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__NonZeroReferrerFee.selector
        );
    }

    function testRevertsNonZeroReferrerFeeETH() external {
        tx_isEth = true;
        _expectDecoderRevert(
            _transferETHCalldata(SIGNED_QUOTE, _feeArgs(type(uint16).max)),
            WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__NonZeroReferrerFee.selector
        );
    }

    function testRevertsWrongReferrerPayee() external {
        DecoderCustomTypes.WormholeFeeArgs memory feeArgs = DecoderCustomTypes.WormholeFeeArgs({dbps: 0, payee: address(0xBEEF)});
        _expectProofFailure(false, _transferCalldata(SIGNED_QUOTE, feeArgs), TOTAL_NATIVE_FEE);
    }

    // ========================================= RELAY INSTRUCTIONS =========================================

    function testRevertsWrongDropOffRecipient() external {
        bytes memory data = _transferCalldataWithInstructions(SIGNED_QUOTE, _executorInstructions(address(0xBEEF)));
        _expectProofFailure(false, data, TOTAL_NATIVE_FEE);
    }

    function testRevertsUnknownRelayInstruction() external {
        bytes memory data = _transferCalldataWithInstructions(SIGNED_QUOTE, hex"03");
        _expectDecoderRevert(
            data, abi.encodeWithSelector(WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__UnknownRelayInstruction.selector, uint8(3))
        );
    }

    function testRevertsTruncatedGasInstruction() external {
        bytes memory instructions = abi.encodePacked(_executorInstructions(address(boringVault)), hex"01");
        _expectDecoderRevert(
            _transferCalldataWithInstructions(SIGNED_QUOTE, instructions),
            WormholeNTTDecoderAndSanitizer.WormholeNTTDecoderAndSanitizer__TruncatedRelayInstruction.selector
        );
    }

    // ========================================= HELPERS =========================================

    bool internal tx_isEth;

    function _leafs() internal returns (ManageLeaf[] memory leafs) {
        leafIndex = type(uint256).max;
        leafs = new ManageLeaf[](4);
        _addWormholeNTTExecutorMultiTokenBridgeLeafs(leafs, multiTokenExecutor, multiTokenNtt, getERC20(sourceChain, "WETH"), uint16(wormholeMonadChainId));
    }

    function _vaultBytes32() internal view returns (bytes32) {
        return bytes32(uint256(uint160(address(boringVault))));
    }

    function _feeArgs(uint16 dbps) internal view returns (DecoderCustomTypes.WormholeFeeArgs memory) {
        return DecoderCustomTypes.WormholeFeeArgs({dbps: dbps, payee: getAddress(sourceChain, "wormholeMultiTokenExecutorPayee")});
    }

    // Gas instruction + drop-off to `dropOffRecipient` (real tx instructions, refund EOA swapped for the vault).
    function _executorInstructions(address dropOffRecipient) internal pure returns (bytes memory) {
        return abi.encodePacked(
            hex"01000000000000000000000000000f42400000000000000000000000000000000002000000000000000006f05b59d3b20000000000000000000000000000", dropOffRecipient
        );
    }

    function _executorArgs(bytes memory signedQuote, bytes memory instructions) internal view returns (DecoderCustomTypes.WormholeExecutorArgs memory) {
        return DecoderCustomTypes.WormholeExecutorArgs({
            value: EXECUTOR_FEE, refundAddress: address(boringVault), signedQuote: signedQuote, instructions: instructions
        });
    }

    function _transferCalldata(bytes memory signedQuote, DecoderCustomTypes.WormholeFeeArgs memory feeArgs) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            TRANSFER_SIG,
            multiTokenNtt,
            getAddress(sourceChain, "WETH"),
            BRIDGE_AMOUNT,
            uint16(wormholeMonadChainId),
            _vaultBytes32(),
            _vaultBytes32(),
            TRANSCEIVER_INSTRUCTIONS,
            _executorArgs(signedQuote, _executorInstructions(address(boringVault))),
            feeArgs
        );
    }

    function _transferCalldataWithInstructions(bytes memory signedQuote, bytes memory instructions) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            TRANSFER_SIG,
            multiTokenNtt,
            getAddress(sourceChain, "WETH"),
            BRIDGE_AMOUNT,
            uint16(wormholeMonadChainId),
            _vaultBytes32(),
            _vaultBytes32(),
            TRANSCEIVER_INSTRUCTIONS,
            _executorArgs(signedQuote, instructions),
            _feeArgs(0)
        );
    }

    function _transferETHCalldata(bytes memory signedQuote, DecoderCustomTypes.WormholeFeeArgs memory feeArgs) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            TRANSFER_ETH_SIG,
            multiTokenNtt,
            BRIDGE_AMOUNT,
            uint16(wormholeMonadChainId),
            _vaultBytes32(),
            _vaultBytes32(),
            TRANSCEIVER_INSTRUCTIONS,
            _executorArgs(signedQuote, _executorInstructions(address(boringVault))),
            feeArgs
        );
    }

    function _withPayee(bytes memory quote, address payee) internal pure returns (bytes memory q) {
        q = quote;
        bytes20 p = bytes20(payee);
        for (uint256 i; i < 20; ++i) {
            q[36 + i] = p[i];
        }
    }

    // leafs[1] = WETH transfer, leafs[2] = transferETH. ETH calls need no approve, so they run as a single call.
    function _buildTx(bool eth, bytes memory data, uint256 value) internal returns (bytes32[][] memory proofs, Tx memory tx_) {
        ManageLeaf[] memory leafs = _leafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        if (eth) {
            tx_ = _getTxArrays(1);
            tx_.manageLeafs[0] = leafs[2];
            tx_.targets[0] = multiTokenExecutor;
            tx_.targetData[0] = data;
            tx_.values[0] = value;
            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        } else {
            tx_ = _getTxArrays(2);
            tx_.manageLeafs[0] = leafs[0];
            tx_.manageLeafs[1] = leafs[1];
            tx_.targets[0] = getAddress(sourceChain, "WETH");
            tx_.targets[1] = multiTokenExecutor;
            tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", multiTokenExecutor, type(uint256).max);
            tx_.targetData[1] = data;
            tx_.values[1] = value;
            tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
            tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        }
        proofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);
    }

    function _submit(bool eth, bytes memory data, uint256 value) internal {
        (bytes32[][] memory proofs, Tx memory tx_) = _buildTx(eth, data, value);
        _submitManagerCall(proofs, tx_);
    }

    function _expectProofFailure(bool eth, bytes memory data, uint256 value) internal {
        (bytes32[][] memory proofs, Tx memory tx_) = _buildTx(eth, data, value);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, multiTokenExecutor, data, value
            )
        );
        _submitManagerCall(proofs, tx_);
    }

    function _expectDecoderRevert(bytes memory data, bytes4 selector) internal {
        _expectDecoderRevert(data, abi.encodePacked(selector));
    }

    function _expectDecoderRevert(bytes memory data, bytes memory revertData) internal {
        (bytes32[][] memory proofs, Tx memory tx_) = _buildTx(tx_isEth, data, tx_isEth ? BRIDGE_AMOUNT + TOTAL_NATIVE_FEE : TOTAL_NATIVE_FEE);
        vm.expectRevert(revertData);
        _submitManagerCall(proofs, tx_);
    }
}
