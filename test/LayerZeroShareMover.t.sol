// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {LayerZeroShareMoverHarness} from "test/mocks/LayerZeroShareMoverHarness.sol";
import {MockVault} from "test/mocks/MockVault.sol";
import {LayerZeroShareMover} from "src/base/Roles/CrossChain/ShareMover/LayerZeroShareMover.sol";
import {MockEndpoint} from "test/mocks/MockEndpoint.sol";

contract LayerZeroShareMoverHelperTest is Test {
    LayerZeroShareMoverHarness harness;
    MockVault vault;

    function setUp() external {
        vault = new MockVault(18);
        MockEndpoint endpoint = new MockEndpoint();
        harness = new LayerZeroShareMoverHarness(address(vault), address(0x1234), address(endpoint));

        // Add EVM and SOLANA chains via owner (address(this)) since harness owner is itself
        uint32 eidEvm = 101;
        uint32 eidSol = 102;
        bytes32 peer = bytes32(uint256(uint160(address(0xAA))));
        harness.addChain(eidEvm, true, true, peer, 500_000, 18, LayerZeroShareMover.ChainType.EVM);
        harness.addChain(eidSol, true, true, peer, 500_000, 9, LayerZeroShareMover.ChainType.SOLANA);
    }

    function testSanitizeRecipientEvmValid() external view {
        bytes32 padded = bytes32(uint256(uint160(address(0xBEEF))));
        bytes32 out = harness.exposedSanitize(padded, 101);
        assertEq(out, padded);
    }

    function testSanitizeRecipientEvmInvalidReverts() external {
        // first byte non-zero
        bytes32 bad = bytes32(uint256(uint160(address(0xBEEF))) + (1 << 248));
        vm.expectRevert();
        harness.exposedSanitize(bad, 101);
    }

    function testSanitizeRecipientSolanaAccepts32Bytes() external view {
        bytes32 solanaAddr = bytes32(hex"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
        bytes32 out = harness.exposedSanitize(solanaAddr, 102);
        assertEq(out, solanaAddr);
    }

    function testDecodeBridgeParams() external view {
        uint32 chainId = 999;
        address feeToken = address(0xDEAD);
        uint256 maxFee = 123 ether;
        bytes memory data = abi.encode(chainId, feeToken, maxFee);

        (uint32 eid, address token, uint256 fee) = harness.exposedDecode(data);
        assertEq(eid, chainId);
        assertEq(token, feeToken);
        assertEq(fee, maxFee);
    }

    function testDecodeBridgeParamsInvalidReverts() external {
        bytes memory bad = hex"deadbeef"; // too short
        vm.expectRevert();
        harness.exposedDecode(bad);
    }
} 