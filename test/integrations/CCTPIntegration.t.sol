// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullCCTPDecoderAndSanitizer is CCTPDecoderAndSanitizer {}

contract CCTPIntegrationTest is BaseTestIntegration {
    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 22618690);

        address cctpDecoder = address(new FullCCTPDecoderAndSanitizer());

        _overrideDecoder(cctpDecoder);
    }

    function testBridgeUSDC() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);
        deal(address(boringVault), 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);

        uint32 toChain = uint32(13); //SONIC
        _addCCTPBridgeLeafs(leafs, toChain);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //depositForBurn(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDC"); //approve
        tx_.targets[1] = getAddress(sourceChain, "usdcTokenMessengerV2");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "usdcTokenMessengerV2"), type(uint256).max
        );
        tx_.targetData[1] = abi.encodeWithSignature(
            "depositForBurn(uint256,uint32,bytes32,address,bytes32,uint256,uint32)",
            100e6,
            uint32(13),
            getBytes32(sourceChain, "boringVault"),
            getAddress(sourceChain, "USDC"),
            getBytes32(sourceChain, "boringVault"),
            50e6,
            500 //FAST
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function testReceiveUSDC() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);
        deal(address(boringVault), 1e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);

        uint32 toChain = uint32(13); //SONIC
        _addCCTPBridgeLeafs(leafs, toChain);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[2]; //accept USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "usdcMessageTransmitterV2"); //approve

        bytes memory message =
            hex"000000010000000d000000008ff4da6122b0ade2ba931ea230b5c865503246de01dd069baa90901457e9ce3000000000000000000000000028b5a0e9c621a5badaa536219b3a228c8168cf5d00000000000000000000000028b5a0e9c621a5badaa536219b3a228c8168cf5d0000000000000000000000000000000000000000000000000000000000000000000003e8000007d00000000100000000000000000000000029219dd400f2bf60e5a23d13be72b486d403889400000000000000000000000037829fe9b8e67b8267c2058b9459f524b9e3ca5d000000000000000000000000000000000000000000000000000000204f86393000000000000000000000000037829fe9b8e67b8267c2058b9459f524b9e3ca5d00000000000000000000000000000000000000000000000000000000295b8d1600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        bytes memory attestation =
            hex"f84c71add84ca960bc21bedabe2565c1f128e8d3fe037ca2a2c135f7863ebdfe64d525190e2ffe6b8f48a08b7a783c1f4867fafb45792d10b4d0e642b351866a1c64495d38083f47886aebd2b536e1ca8220548cbe68673d409c30bc55fee6c70e32bc7a2bb700a7ab90445af554fe19dd22cbfa1a5f16b95317c25771636feb6f1c";

        tx_.targetData[0] = abi.encodeWithSignature("receiveMessage(bytes,bytes)", message, attestation);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        address receiver = 0x37829FE9b8e67B8267C2058b9459f524b9E3ca5d;
        uint256 usdcBalanceBefore = getERC20(sourceChain, "USDC").balanceOf(receiver);

        _submitManagerCall(manageProofs, tx_);

        uint256 usdcBalanceAfter = getERC20(sourceChain, "USDC").balanceOf(receiver);
        assertGt(usdcBalanceAfter, usdcBalanceBefore);
    }
}

