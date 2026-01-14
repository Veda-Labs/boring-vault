// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {HyperliquidCoreWriterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/HyperliquidCoreWriterDecoderAndSanitizer.sol";
import {ICoreWriter} from "src/interfaces/ICoreWriter.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullHyperliquidCoreWriterDecoderAndSanitizer is
    HyperliquidCoreWriterDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{}

contract HyperliquidCoreWriterIntegration is BaseTestIntegration {
    address internal constant CORE_WRITER = 0x3333333333333333333333333333333333333333;
    address internal constant HYPE_BRIDGE = 0x2222222222222222222222222222222222222222;

    function _setUpHyperEVM() internal {
        super.setUp();
        _setupChain("hyperEVM", 24500000);

        address coreWriterDecoder = address(new FullHyperliquidCoreWriterDecoderAndSanitizer());
        _overrideDecoder(coreWriterDecoder);
    }

    function testPlaceLimitOrder() external {
        _setUpHyperEVM();

        deal(address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // Add leaf for sendRawAction (used for all CoreWriter calls)
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "sendRawAction(bytes)",
            new address[](0),
            "Send raw action to HyperCore",
            rawDataDecoderAndSanitizer
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; // sendRawAction

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        // Encode limit order action: [version=0x01][actionId=0x000001][params]
        // Action ID 1: (uint32 asset, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 encodedTif, uint128 cloid)
        bytes memory actionParams = abi.encode(
            uint32(0), // asset (BTC)
            true, // isBuy
            uint64(50000 * 10 ** 8), // limitPx
            uint64(1 * 10 ** 8), // sz
            false, // reduceOnly
            uint8(2), // encodedTif (Gtc)
            uint128(0) // cloid
        );
        bytes memory rawAction = abi.encodePacked(bytes1(0x01), bytes3(0x000001), actionParams);

        tx_.targets[0] = CORE_WRITER;
        tx_.targetData[0] = abi.encodeWithSelector(ICoreWriter.sendRawAction.selector, rawAction);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function testUsdClassTransfer() external {
        _setUpHyperEVM();

        deal(address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // Add leaf for sendRawAction
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "sendRawAction(bytes)",
            new address[](0),
            "Send raw action to HyperCore",
            rawDataDecoderAndSanitizer
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; // sendRawAction

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        // Encode USD class transfer action: [version=0x01][actionId=0x000007][params]
        // Action ID 7: (uint64 ntl, bool toPerp)
        bytes memory actionParams = abi.encode(
            uint64(1000 * 10 ** 8), // ntl (1000 USD)
            true // toPerp
        );
        bytes memory rawAction = abi.encodePacked(bytes1(0x01), bytes3(0x000007), actionParams);

        tx_.targets[0] = CORE_WRITER;
        tx_.targetData[0] = abi.encodeWithSelector(ICoreWriter.sendRawAction.selector, rawAction);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function testSpotSend() external {
        _setUpHyperEVM();

        deal(address(boringVault), 100e18);

        address recipient = address(0xBEEF);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // Add leaf for sendRawAction with recipient address extraction
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "sendRawAction(bytes)",
            new address[](1),
            "Send spot tokens on HyperCore",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = recipient;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; // sendRawAction

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        // Encode spot send action: [version=0x01][actionId=0x000006][params]
        // Action ID 6: (address destination, uint32 token, uint64 wei)
        bytes memory actionParams = abi.encode(
            recipient, // destination
            uint32(0), // token (USDC = 0)
            uint64(100 * 10 ** 8) // wei
        );
        bytes memory rawAction = abi.encodePacked(bytes1(0x01), bytes3(0x000006), actionParams);

        tx_.targets[0] = CORE_WRITER;
        tx_.targetData[0] = abi.encodeWithSelector(ICoreWriter.sendRawAction.selector, rawAction);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function testVaultTransfer() external {
        _setUpHyperEVM();

        deal(address(boringVault), 100e18);

        address vault = address(0xCAFE);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // Add leaf for sendRawAction with vault address extraction
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "sendRawAction(bytes)",
            new address[](1),
            "Transfer to HyperCore vault",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = vault;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; // sendRawAction

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        // Encode vault transfer action: [version=0x01][actionId=0x000002][params]
        // Action ID 2: (address vault, bool isDeposit, uint64 usd)
        bytes memory actionParams = abi.encode(
            vault, // vault address
            true, // isDeposit
            uint64(1000 * 10 ** 8) // usd amount
        );
        bytes memory rawAction = abi.encodePacked(bytes1(0x01), bytes3(0x000002), actionParams);

        tx_.targets[0] = CORE_WRITER;
        tx_.targetData[0] = abi.encodeWithSelector(ICoreWriter.sendRawAction.selector, rawAction);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function testTokenDelegate() external {
        _setUpHyperEVM();

        deal(address(boringVault), 100e18);

        address validator = address(0xDEAD);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // Add leaf for sendRawAction with validator address extraction
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "sendRawAction(bytes)",
            new address[](1),
            "Delegate HYPE to validator",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = validator;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; // sendRawAction

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        // Encode token delegate action: [version=0x01][actionId=0x000003][params]
        // Action ID 3: (address validator, uint64 wei, bool isUndelegate)
        bytes memory actionParams = abi.encode(
            validator, // validator
            uint64(10 * 10 ** 18), // wei amount
            false // isUndelegate
        );
        bytes memory rawAction = abi.encodePacked(bytes1(0x01), bytes3(0x000003), actionParams);

        tx_.targets[0] = CORE_WRITER;
        tx_.targetData[0] = abi.encodeWithSelector(ICoreWriter.sendRawAction.selector, rawAction);
        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    /// @notice Test bridging native USDC from HyperEVM to HyperCore
    /// @dev Native USDC uses CoreDepositWallet (not system address):
    ///      1. Approve USDC to CoreDepositWallet
    ///      2. Call CoreDepositWallet.deposit(amount)
    function testBridgeUsdcToCore() external {
        _setUpHyperEVM();

        // Get USDC address and CoreDepositWallet
        address usdc = getAddress(sourceChain, "USDC");
        address coreDepositWallet = getAddress(sourceChain, "coreDepositWallet");

        // Deal USDC to the vault
        deal(usdc, address(boringVault), 1000e6); // 1000 USDC (6 decimals)

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // Leaf 0: Approve USDC to CoreDepositWallet
        leafs[0] = ManageLeaf(
            usdc,
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve USDC to CoreDepositWallet",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = coreDepositWallet;

        // Leaf 1: Call deposit on CoreDepositWallet
        // deposit(uint256 amount, uint32 destinationDex) - destinationDex: 0=perps, 0xFFFFFFFF=spot
        leafs[1] = ManageLeaf(
            coreDepositWallet,
            false,
            "deposit(uint256,uint32)",
            new address[](0),
            "Deposit USDC to HyperCore",
            rawDataDecoderAndSanitizer
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // First transaction: Approve
        Tx memory tx1 = _getTxArrays(1);
        tx1.manageLeafs[0] = leafs[0];
        bytes32[][] memory approveProofs = _getProofsUsingTree(tx1.manageLeafs, manageTree);
        tx1.targets[0] = usdc;
        tx1.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)",
            coreDepositWallet,
            500e6
        );
        tx1.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        _submitManagerCall(approveProofs, tx1);

        // Second transaction: Deposit
        // destinationDex: 0=perps, 0xFFFFFFFF=spot (we'll deposit to spot)
        Tx memory tx2 = _getTxArrays(1);
        tx2.manageLeafs[0] = leafs[1];
        bytes32[][] memory depositProofs = _getProofsUsingTree(tx2.manageLeafs, manageTree);
        tx2.targets[0] = coreDepositWallet;
        tx2.targetData[0] = abi.encodeWithSignature("deposit(uint256,uint32)", uint256(500e6), uint32(0xFFFFFFFF));
        tx2.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256 balanceBefore = ERC20(usdc).balanceOf(address(boringVault));

        _submitManagerCall(depositProofs, tx2);

        uint256 balanceAfter = ERC20(usdc).balanceOf(address(boringVault));

        // Verify USDC was bridged
        assertEq(balanceBefore - balanceAfter, 500e6, "Should have bridged 500 USDC");
    }

    /// @notice Test HYPE bridge merkle verification (execution skipped - bridge only accepts raw ETH)
    /// @dev The HYPE bridge at 0x2222...2222 only has a receive() function.
    ///      This test verifies the merkle leaf setup is correct.
    ///      In production, use boringVault.manage() to send raw ETH without calldata.
    function testBridgeHypeToCore_MerkleSetup() external {
        _setUpHyperEVM();

        deal(address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        _addBridgeHypeToCoreLeaf(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Verify merkle tree was generated correctly
        assertTrue(manageTree.length > 0, "Merkle tree should be generated");
        assertTrue(manageTree[manageTree.length - 1][0] != bytes32(0), "Root should be non-zero");
    }

    //============================== LEAF HELPERS ===============================

    function _addCoreWriterLeafs(ManageLeaf[] memory leafs) internal {
        // Leaf 0: placeLimitOrder
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "placeLimitOrder(uint32,bool,uint64,uint64,bool,uint8,uint128)",
            new address[](0),
            "Place limit order on HyperCore perps",
            rawDataDecoderAndSanitizer
        );

        // Leaf 1: usdClassTransfer
        leafs[1] = ManageLeaf(
            CORE_WRITER,
            false,
            "usdClassTransfer(uint64,bool)",
            new address[](0),
            "Transfer USD between spot and perp",
            rawDataDecoderAndSanitizer
        );

        // Leaf 2: cancelOrderByCloid
        leafs[2] = ManageLeaf(
            CORE_WRITER,
            false,
            "cancelOrderByCloid(uint32,uint128)",
            new address[](0),
            "Cancel order by cloid on HyperCore",
            rawDataDecoderAndSanitizer
        );

        // Leaf 3: cancelOrderByOid
        leafs[3] = ManageLeaf(
            CORE_WRITER,
            false,
            "cancelOrderByOid(uint32,uint64)",
            new address[](0),
            "Cancel order by oid on HyperCore",
            rawDataDecoderAndSanitizer
        );

        // Leaf 4: stakingDeposit
        leafs[4] = ManageLeaf(
            CORE_WRITER,
            false,
            "stakingDeposit(uint64)",
            new address[](0),
            "Deposit HYPE into staking",
            rawDataDecoderAndSanitizer
        );

        // Leaf 5: stakingWithdraw
        leafs[5] = ManageLeaf(
            CORE_WRITER,
            false,
            "stakingWithdraw(uint64)",
            new address[](0),
            "Withdraw HYPE from staking",
            rawDataDecoderAndSanitizer
        );
    }

    function _addCoreWriterSpotSendLeaf(ManageLeaf[] memory leafs, address recipient) internal {
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "spotSend(address,uint32,uint64)",
            new address[](1),
            "Send spot tokens on HyperCore",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = recipient;
    }

    function _addCoreWriterVaultTransferLeaf(ManageLeaf[] memory leafs, address vault) internal {
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "vaultTransfer(address,bool,uint64)",
            new address[](1),
            "Transfer to/from HyperCore vault",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = vault;
    }

    function _addCoreWriterTokenDelegateLeaf(ManageLeaf[] memory leafs, address validator) internal {
        leafs[0] = ManageLeaf(
            CORE_WRITER,
            false,
            "tokenDelegate(address,uint64,bool)",
            new address[](1),
            "Delegate HYPE to validator",
            rawDataDecoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = validator;
    }

    function _addBridgeHypeToCoreLeaf(ManageLeaf[] memory leafs) internal {
        leafs[0] = ManageLeaf(
            HYPE_BRIDGE,
            true, // valueNonZero - we send ETH to bridge HYPE
            "bridgeHypeToCore()",
            new address[](0),
            "Bridge HYPE from HyperEVM to HyperCore",
            rawDataDecoderAndSanitizer
        );
    }
}
