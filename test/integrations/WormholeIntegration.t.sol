// SPDX-License-Identifier: SEL-1.0
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WormholeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/WormholeDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullWormholeDecoderAndSanitizer is WormholeDecoderAndSanitizer, BaseDecoderAndSanitizer {}

contract WormholeIntegrationTest is BaseTestIntegration {
    address internal multiTokenExecutor;
    address internal multiTokenNtt;

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 25124511);

        address wormholeDecoder = address(new FullWormholeDecoderAndSanitizer());
        _overrideDecoder(wormholeDecoder);

        multiTokenExecutor = getAddress(sourceChain, "wormholeMultiTokenExecutor");
        multiTokenNtt = getAddress(sourceChain, "wormholeMultiTokenNtt");
    }

    function _vaultBytes32() internal view returns (bytes32) {
        return bytes32(uint256(uint160(address(boringVault))));
    }

    function _vaultExecutorArgs(uint256 value) internal view returns (DecoderCustomTypes.WormholeExecutorArgs memory) {
        return DecoderCustomTypes.WormholeExecutorArgs({
            value: value,
            refundAddress: address(boringVault),
            signedQuote: hex"",
            instructions: hex""
        });
    }

    function _vaultFeeArgs() internal view returns (DecoderCustomTypes.WormholeFeeArgs memory) {
        return DecoderCustomTypes.WormholeFeeArgs({
            dbps: 0,
            payee: getAddress(sourceChain, "wormholeMultiTokenExecutorPayee")
        });
    }

    function testBridgeWETHToMonad() external {
        _setUpMainnet();

        // Parameters mirror a real bridge tx from EOA 0xDb83...B0A2, with the EOA
        // replaced by the boring vault wherever the EOA appeared.
        uint256 bridgeAmount = 10_000_000_000_000_000; // 0.01 WETH
        uint256 nativeFee = 31_140_016_176_718;
        address executorPayee = 0x7D73bE2ac3edDc8C5c0A1418b410b9710d4AF40D;

        deal(getAddress(sourceChain, "WETH"), address(boringVault), bridgeAmount);
        deal(address(boringVault), 1e18); // headroom for native fee

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addWormholeNTTExecutorMultiTokenBridgeLeafs(
            leafs,
            multiTokenExecutor,
            multiTokenNtt,
            getERC20(sourceChain, "WETH"),
            uint16(wormholeMonadChainId)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateLeafs("WormholeBridgeWETHToMonad.json", leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve WETH
        tx_.manageLeafs[1] = leafs[1]; // transfer

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = multiTokenExecutor;

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", multiTokenExecutor, type(uint256).max
        );

        bytes memory transceiverInstructions =
            hex"0200010101200000000000000000000000000000000000000000000000000000103a378c202e";
        bytes memory signedQuote =
            hex"45513031a54008017941ece968623a0dd8ee907e2b1335960000000000000000000000006a8bfc410a3cc7306d52872f116afb12f1cec6c600020030000000006a0b8598000000000003978800000017bfac7c00000013516a7f3400000000000ffbabf8956e4189a1ba168390e7b3b2eb3f1c4abd951586961f213b76c77b7277826a2d1d5b71ed0463afb44b55ee91b38d9725d7d3f7da9ba68444bb0017c0b11466bb1c";
        // Executor instructions end with a refund address; swap the EOA for the boring vault.
        bytes memory executorInstructions = abi.encodePacked(
            hex"01000000000000000000000000000f42400000000000000000000000000000000002000000000000000006f05b59d3b20000000000000000000000000000",
            address(boringVault)
        );

        DecoderCustomTypes.WormholeExecutorArgs memory executorArgs = DecoderCustomTypes.WormholeExecutorArgs({
            value: nativeFee,
            refundAddress: address(boringVault),
            signedQuote: signedQuote,
            instructions: executorInstructions
        });

        DecoderCustomTypes.WormholeFeeArgs memory feeArgs =
            DecoderCustomTypes.WormholeFeeArgs({dbps: 0, payee: executorPayee});

        tx_.targetData[1] = abi.encodeWithSignature(
            "transfer(address,address,uint256,uint16,bytes32,bytes32,bytes,(uint256,address,bytes,bytes),(uint16,address))",
            multiTokenNtt,
            getAddress(sourceChain, "WETH"),
            bridgeAmount,
            uint16(wormholeMonadChainId),
            _vaultBytes32(),
            _vaultBytes32(),
            transceiverInstructions,
            executorArgs,
            feeArgs
        );

        tx_.values[1] = 0.00004898224225446 ether; // native fee paid alongside transfer

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }
}
