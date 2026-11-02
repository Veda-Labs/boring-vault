// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";
import {CCTPDecoderAndSanitizerSingleton} from "src/base/DecodersAndSanitizers/CCTPDecoderAndSanitizerSingleton.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullCCTPDecoderAndSanitizer is CCTPDecoderAndSanitizer {
    constructor() CCTPDecoderAndSanitizer(5) {}
}

contract CCTPSolanaIntegrationTest is BaseTestIntegration {
    // USDC ATA address of the boring-vault-svm sub-account-0 PDA, with nonzero high bytes
    // (BZkSGrbJuJKroUkKtjEoVLyr6tuVnnt7yBofBJ4auAQh). The burn side never validates existence, so any
    // 32 byte value works here. A production root must only commit an ATA that exists on Solana.
    bytes32 internal constant SOLANA_MINT_RECIPIENT = 0x9cf8916fadf6ce69906286a52f99b23ddc5459f045fa94dabf42db612b0c68f2;

    uint32 internal constant SOLANA_DOMAIN = 5;

    function _setUpMainnet() internal {
        super.setUp();
        // Block must be after Circle registered the Solana remote token messenger on TokenMessengerV2.
        // remoteTokenMessengers(5) is still zero at CCTPIntegration's block 22618690.
        _setupChain("mainnet", 25289000);

        address cctpDecoder = address(new FullCCTPDecoderAndSanitizer());

        _overrideDecoder(cctpDecoder);
    }

    function _depositForBurnCalldata(bytes32 mintRecipient, bytes32 destinationCaller) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            "depositForBurn(uint256,uint32,bytes32,address,bytes32,uint256,uint32)",
            100e6,
            SOLANA_DOMAIN,
            mintRecipient,
            getAddress(sourceChain, "USDC"),
            destinationCaller,
            0, // maxFee for a standard transfer
            2000 // minFinalityThreshold for a standard transfer, which never expires
        );
    }

    function _setUpSolanaTree() internal returns (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) {
        leafs = new ManageLeaf[](4);
        _addCCTPBridgeToSolanaLeafs(leafs, SOLANA_MINT_RECIPIENT);

        manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
    }

    function testBridgeUSDCToSolana() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setUpSolanaTree();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //depositForBurn(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDC");
        tx_.targets[1] = getAddress(sourceChain, "usdcTokenMessengerV2");

        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "usdcTokenMessengerV2"), type(uint256).max);
        tx_.targetData[1] = _depositForBurnCalldata(SOLANA_MINT_RECIPIENT, bytes32(0));

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);

        // The full 100e6 was burned by the token messenger.
        assertEq(getERC20(sourceChain, "USDC").balanceOf(address(boringVault)), 0, "USDC should be burned");
    }

    function testBridgeUSDCToSolanaTamperedCalldataReverts() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100e6);

        (ManageLeaf[] memory leafs, bytes32[][] memory manageTree) = _setUpSolanaTree();

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; //approve USDC
        tx_.manageLeafs[1] = leafs[1]; //depositForBurn(USDC)

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDC");
        tx_.targets[1] = getAddress(sourceChain, "usdcTokenMessengerV2");

        tx_.targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "usdcTokenMessengerV2"), type(uint256).max);

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Flip one bit in the high 12 bytes of mintRecipient, the bytes a 20 byte truncating decoder
        // would leave unverified. The proof must fail.
        bytes32 tamperedHigh = SOLANA_MINT_RECIPIENT ^ bytes32(uint256(1) << 200);
        tx_.targetData[1] = _depositForBurnCalldata(tamperedHigh, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, tx_.targets[1], tx_.targetData[1], 0
            )
        );
        _submitManagerCall(manageProofs, tx_);

        // Flip one bit in the low 20 bytes of mintRecipient.
        bytes32 tamperedLow = SOLANA_MINT_RECIPIENT ^ bytes32(uint256(1));
        tx_.targetData[1] = _depositForBurnCalldata(tamperedLow, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, tx_.targets[1], tx_.targetData[1], 0
            )
        );
        _submitManagerCall(manageProofs, tx_);

        // destinationCaller is pinned to bytes32(0). Any nonzero caller must fail.
        tx_.targetData[1] = _depositForBurnCalldata(SOLANA_MINT_RECIPIENT, bytes32(uint256(1) << 250));
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, tx_.targets[1], tx_.targetData[1], 0
            )
        );
        _submitManagerCall(manageProofs, tx_);
    }

    function testFuzz_SolanaRecipientAndCallerFullyCommitted(bytes32 mintRecipient, bytes32 destinationCaller) external {
        // Pure property over the decoder's return bytes. No fork or vault needed, and forking inside
        // a fuzz body would recreate the fork on every run.
        CCTPDecoderAndSanitizer decoder = new FullCCTPDecoderAndSanitizer();
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // mainnet USDC

        // The decoder must commit the domain, both halves of both 32 byte values, and the burn token.
        bytes memory sensitive = decoder.depositForBurn(100e6, SOLANA_DOMAIN, mintRecipient, usdc, destinationCaller, 0, 2000);

        // Derive the expected slots with arithmetic shifts and masks, independent of the decoder's
        // bytes20(bytes16(...)) expression, so a shared slicing bug cannot hide behind a mirror.
        // The high 16 bytes occupy the top of slot 0 and the low 16 bytes the top of slot 1.
        address recipient0 = address(uint160((uint256(mintRecipient) >> 128) << 32));
        address recipient1 = address(uint160((uint256(mintRecipient) & type(uint128).max) << 32));
        address caller0 = address(uint160((uint256(destinationCaller) >> 128) << 32));
        address caller1 = address(uint160((uint256(destinationCaller) & type(uint128).max) << 32));
        assertEq(
            sensitive,
            abi.encodePacked(address(uint160(SOLANA_DOMAIN)), recipient0, recipient1, usdc, caller0, caller1),
            "decoder must commit domain + both halves of recipient and caller + burn token"
        );

        // Recombine the committed slots and assert they reproduce the full values, so no two distinct
        // recipients or callers can collide onto the same leaf.
        uint256 recoveredRecipient = ((uint256(uint160(recipient0)) >> 32) << 128) | (uint256(uint160(recipient1)) >> 32);
        assertEq(bytes32(recoveredRecipient), mintRecipient, "recipient split must be lossless / injective");
        uint256 recoveredCaller = ((uint256(uint160(caller0)) >> 32) << 128) | (uint256(uint160(caller1)) >> 32);
        assertEq(bytes32(recoveredCaller), destinationCaller, "caller split must be lossless / injective");
    }

    function testEvmDestinationPackingUnchanged() external {
        _setUpMainnet();

        // Non-Solana domains must keep the exact previous 4-slot packing so every existing EVM CCTP
        // leaf still verifies against a redeployed decoder.
        address usdc = getAddress(sourceChain, "USDC");
        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes memory sensitive =
            CCTPDecoderAndSanitizer(rawDataDecoderAndSanitizer).depositForBurn(100e6, 13, vaultAsBytes32, usdc, vaultAsBytes32, 50_000, 500);
        assertEq(
            sensitive,
            abi.encodePacked(address(uint160(13)), address(boringVault), usdc, address(boringVault)),
            "EVM branch packing must be byte-identical to the pre-Solana decoder"
        );

        // The EVM branch still rejects nonzero high bytes.
        vm.expectRevert(CCTPDecoderAndSanitizer.CCTPDecoderAndSanitizer__InvalidAddress.selector);
        CCTPDecoderAndSanitizer(rawDataDecoderAndSanitizer).depositForBurn(100e6, 13, SOLANA_MINT_RECIPIENT, usdc, bytes32(0), 0, 500);
    }

    function testFuzz_MaxFeeCapBoundary(uint256 amount, uint256 maxFee) external {
        // The decoder must accept maxFee up to exactly 5 bps of amount and revert above it.
        amount = bound(amount, 1, type(uint128).max);
        maxFee = bound(maxFee, 0, type(uint128).max);
        CCTPDecoderAndSanitizer decoder = new FullCCTPDecoderAndSanitizer();
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        if (maxFee * 10_000 > amount * 5) {
            vm.expectRevert(CCTPDecoderAndSanitizer.CCTPDecoderAndSanitizer__FeeTooHigh.selector);
        }
        decoder.depositForBurn(amount, SOLANA_DOMAIN, SOLANA_MINT_RECIPIENT, usdc, bytes32(0), maxFee, 2000);
    }

    function testMaxFeeBpsConstructorBounds() external {
        new CCTPDecoderAndSanitizerSingleton(50);
        vm.expectRevert(CCTPDecoderAndSanitizer.CCTPDecoderAndSanitizer__InvalidMaxFeeBps.selector);
        new CCTPDecoderAndSanitizerSingleton(51);
    }

    function testAddCCTPBridgeLeafsRejectsSolanaDomain() external {
        _setUpMainnet();

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        vm.expectRevert(bytes("CCTP: use _addCCTPBridgeToSolanaLeafs for Solana"));
        this.addCCTPBridgeLeafsExternal(leafs, SOLANA_DOMAIN);

        vm.expectRevert(bytes("solanaMintRecipient cannot be zero"));
        this.addCCTPBridgeToSolanaLeafsExternal(leafs, bytes32(0));
    }

    // expectRevert needs an external call frame for internal helpers.
    function addCCTPBridgeLeafsExternal(ManageLeaf[] memory leafs, uint32 toChain) external {
        _addCCTPBridgeLeafs(leafs, toChain);
    }

    function addCCTPBridgeToSolanaLeafsExternal(ManageLeaf[] memory leafs, bytes32 mintRecipient) external {
        _addCCTPBridgeToSolanaLeafs(leafs, mintRecipient);
    }
}
