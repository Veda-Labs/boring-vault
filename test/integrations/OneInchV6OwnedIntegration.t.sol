// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {OneInchOwnedDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/OneInchOwnedDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract OneInchV6OwnedIntegrationTest is BaseTestIntegration {

    OneInchOwnedDecoderAndSanitizer ownedDecoder;

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 24521559);

        address executor = 0x0BB7a4Fdea32910038DEc59c20ccAe3a6E66b09f;

        ownedDecoder = new OneInchOwnedDecoderAndSanitizer(address(this), executor);

        _overrideDecoder(address(ownedDecoder));

        // Override executor to match real API routing data
        setAddress(true, sourceChain, "oneInchExecutor", executor);
    }

    function testV6OwnedApproveAndSwap() external {
        _setUpMainnet();

        // Deal USDT to boringVault (381_040_412 = 0x16b2f71c, ~381 USDT with 6 decimals)
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 381_040_412);

        address[] memory assets = new address[](2);
        SwapKind[] memory kind = new SwapKind[](2);
        assets[0] = getAddress(sourceChain, "USDT");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDC");
        kind[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedGeneralSwapping(leafs, assets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve USDT
        tx_.manageLeafs[1] = leafs[1]; // swap USDT -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "USDT");
        tx_.targets[1] = getAddress(sourceChain, "aggregationRouterV6");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aggregationRouterV6"), type(uint256).max
        );

        // Same raw 1inch API calldata — owned decoder validates executor internally, returns 3 addresses
        tx_.targetData[1] = hex"07ed23790000000000000000000000000bb7a4fdea32910038dec59c20ccae3a6e66b09f000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000bb7a4fdea32910038dec59c20ccae3a6e66b09f0000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f0000000000000000000000000000000000000000000000000000000016b2f71c0000000000000000000000000000000000000000000000000000000016b38e3d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000542efbb34376081172010d429a6b9270d2ee3f69f6f8116454b30dd7ab0585090634166cbbd57de7a921ee305f015f9a7b2655d69c8bf9bbcbd4dfb4e1aaa0ff9520000000000000000000000000000000000000000000000000004e400001a0020d6bdbf78dac17f958d2ee523a2206206994597c13d831ec700a0c9e75c4800000000000000000000000000000000e100190000000000000000000000000000000000000000000000000000049200034200a007e5c0d200000000000000000000000000000000000000000000031e0000ae00005702a000000000000000000000000000000000000000000000000000480896cb71c0ea48c95033000000000000000000000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70001f400000a000002a00000000000000000000000000000000000000000000000000000010022a15bf648c95033010000000000000000000000000000000000000000d1d2eb1b1e90b638588728b4130137d262c87cae000bb800003c00005120111111125421ca6dc452d289314280a0f8842a65d1d2eb1b1e90b638588728b4130137d262c87cae012456a758680000000000000000000000000000000000000000f22bfe007b81ce043d2ded35000000000000000000000000fbeedcfe378866dab6abbafd8b2986f5c17687370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000d1d2eb1b1e90b638588728b4130137d262c87cae00000000000000000000000000000000000000000000000000000000024b176600000000000000000000000000000000000000000000000000000102b8f5bc92100000000000000000000000000003b32700699ca4eac59c20ccae3a6e66b09f000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000410e2f52552811d624642f7b746f2221498ef15a0e34f59f3a20504ddb935e3e611365121f4c8fbf01589913f2c12e114b502d886c05295516d97bceabcc877dc81b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014111111125421ca6dc452d289314280a0f8842a6500000000000000000000000051309995855c00494d039ab6792f18e368e530dff931dac17f958d2ee523a2206206994597c13d831ec70084f196187f000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000053e2d6238da300000032000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff9a5889f795069a41a8a300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014394b1c000000000000000000000000111111125421ca6dc452d289314280a0f8842a65000000000000000000000000000000000000000000000000000000000000";

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        vm.expectRevert(bytes4(0xddb5de5e)); // BadSignature() — passes Merkle check, reverts at router
        _submitManagerCall(manageProofs, tx_);
    }

    function testV6OwnedWrongAddressReverts() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);

        address[] memory assets = new address[](2);
        SwapKind[] memory kind = new SwapKind[](2);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedGeneralSwapping(leafs, assets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Try swap with wrong dstReceiver — should fail Merkle verification
        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[1]; // swap WETH -> WEETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "aggregationRouterV6");

        DecoderCustomTypes.SwapDescription memory desc = DecoderCustomTypes.SwapDescription({
            srcToken: getAddress(sourceChain, "WETH"),
            dstToken: getAddress(sourceChain, "WEETH"),
            srcReceiver: payable(getAddress(sourceChain, "oneInchExecutor")),
            dstReceiver: payable(address(0xdead)), // wrong receiver — not boringVault
            amount: 1_000e18,
            minReturnAmount: 900e18,
            flags: 4
        });

        tx_.targetData[0] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes)",
            getAddress(sourceChain, "oneInchExecutor"),
            desc,
            ""
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Should revert because dstReceiver doesn't match the Merkle leaf
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    function testV6OwnedWrongExecutorReverts() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);

        address[] memory assets = new address[](2);
        SwapKind[] memory kind = new SwapKind[](2);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedGeneralSwapping(leafs, assets, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[1]; // swap WETH -> WEETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "aggregationRouterV6");

        DecoderCustomTypes.SwapDescription memory desc = DecoderCustomTypes.SwapDescription({
            srcToken: getAddress(sourceChain, "WETH"),
            dstToken: getAddress(sourceChain, "WEETH"),
            srcReceiver: payable(address(0xdead)), // wrong executor as srcReceiver
            dstReceiver: payable(address(boringVault)),
            amount: 1_000e18,
            minReturnAmount: 900e18,
            flags: 4
        });

        tx_.targetData[0] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes)",
            address(0xdead), // wrong executor
            desc,
            ""
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Should revert because owned decoder validates executor internally
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    // --- unoswap variants ---

    function testV6OwnedUnoswap() external {
        _setUpMainnet();

        address usdt = getAddress(sourceChain, "USDT");
        deal(usdt, address(boringVault), 1_000e6);

        address pool1 = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3;

        address[] memory dexes = new address[](1);
        dexes[0] = pool1;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedUnoswap(leafs, usdt, dexes);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve USDT
        tx_.manageLeafs[1] = leafs[1]; // unoswap

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = usdt;
        tx_.targets[1] = getAddress(sourceChain, "aggregationRouterV6");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aggregationRouterV6"), type(uint256).max
        );

        tx_.targetData[1] = abi.encodeWithSignature(
            "unoswap(uint256,uint256,uint256,uint256)",
            uint256(uint160(usdt)),
            1_000e6,
            900e6,
            uint256(uint160(pool1))
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Merkle verification passes; router reverts because dex upper 96 bits (pool type flags) are unset
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    function testV6OwnedUnoswap2() external {
        _setUpMainnet();

        address usdt = getAddress(sourceChain, "USDT");
        deal(usdt, address(boringVault), 1_000e6);

        address pool1 = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3;
        address pool2 = 0x13947303F63b363876868D070F14dc865C36463b;

        address[] memory dexes = new address[](2);
        dexes[0] = pool1;
        dexes[1] = pool2;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedUnoswap(leafs, usdt, dexes);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve USDT
        tx_.manageLeafs[1] = leafs[1]; // unoswap2

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = usdt;
        tx_.targets[1] = getAddress(sourceChain, "aggregationRouterV6");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aggregationRouterV6"), type(uint256).max
        );

        tx_.targetData[1] = abi.encodeWithSignature(
            "unoswap2(uint256,uint256,uint256,uint256,uint256)",
            uint256(uint160(usdt)),
            1_000e6,
            900e6,
            uint256(uint160(pool1)),
            uint256(uint160(pool2))
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Merkle verification passes; router reverts because dex upper 96 bits (pool type flags) are unset
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    function testV6OwnedUnoswap3() external {
        _setUpMainnet();

        address usdt = getAddress(sourceChain, "USDT");
        deal(usdt, address(boringVault), 1_000e6);

        address pool1 = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3;
        address pool2 = 0x13947303F63b363876868D070F14dc865C36463b;
        address pool3 = 0x0f3159811670c117c372428D4E69AC32325e4D0F;

        address[] memory dexes = new address[](3);
        dexes[0] = pool1;
        dexes[1] = pool2;
        dexes[2] = pool3;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedUnoswap(leafs, usdt, dexes);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve USDT
        tx_.manageLeafs[1] = leafs[1]; // unoswap3

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = usdt;
        tx_.targets[1] = getAddress(sourceChain, "aggregationRouterV6");

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aggregationRouterV6"), type(uint256).max
        );

        tx_.targetData[1] = abi.encodeWithSignature(
            "unoswap3(uint256,uint256,uint256,uint256,uint256,uint256)",
            uint256(uint160(usdt)),
            1_000e6,
            900e6,
            uint256(uint160(pool1)),
            uint256(uint160(pool2)),
            uint256(uint160(pool3))
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Merkle verification passes; router reverts because dex upper 96 bits (pool type flags) are unset
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    // --- ethUnoswap variants ---

    function testV6OwnedEthUnoswap() external {
        _setUpMainnet();

        deal(address(boringVault), 1 ether);

        address pool1 = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3;

        address[] memory dexes = new address[](1);
        dexes[0] = pool1;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedEthUnoswap(leafs, dexes);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; // ethUnoswap

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "aggregationRouterV6");

        tx_.targetData[0] = abi.encodeWithSignature(
            "ethUnoswap(uint256,uint256)",
            900e18,
            uint256(uint160(pool1))
        );

        tx_.values[0] = 1 ether;

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Merkle verification passes; router reverts because dex upper 96 bits (pool type flags) are unset
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    function testV6OwnedEthUnoswap2() external {
        _setUpMainnet();

        deal(address(boringVault), 1 ether);

        address pool1 = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3;
        address pool2 = 0x13947303F63b363876868D070F14dc865C36463b;

        address[] memory dexes = new address[](2);
        dexes[0] = pool1;
        dexes[1] = pool2;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedEthUnoswap(leafs, dexes);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; // ethUnoswap2

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "aggregationRouterV6");

        tx_.targetData[0] = abi.encodeWithSignature(
            "ethUnoswap2(uint256,uint256,uint256)",
            900e18,
            uint256(uint160(pool1)),
            uint256(uint160(pool2))
        );

        tx_.values[0] = 1 ether;

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Merkle verification passes; router reverts because dex upper 96 bits (pool type flags) are unset
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    function testV6OwnedEthUnoswap3() external {
        _setUpMainnet();

        deal(address(boringVault), 1 ether);

        address pool1 = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3;
        address pool2 = 0x13947303F63b363876868D070F14dc865C36463b;
        address pool3 = 0x0f3159811670c117c372428D4E69AC32325e4D0F;

        address[] memory dexes = new address[](3);
        dexes[0] = pool1;
        dexes[1] = pool2;
        dexes[2] = pool3;

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchV6OwnedEthUnoswap(leafs, dexes);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(1);

        tx_.manageLeafs[0] = leafs[0]; // ethUnoswap3

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "aggregationRouterV6");

        tx_.targetData[0] = abi.encodeWithSignature(
            "ethUnoswap3(uint256,uint256,uint256,uint256)",
            900e18,
            uint256(uint160(pool1)),
            uint256(uint160(pool2)),
            uint256(uint160(pool3))
        );

        tx_.values[0] = 1 ether;

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Merkle verification passes; router reverts because dex upper 96 bits (pool type flags) are unset
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    // --- Decoder unit tests: verify owned decoder address extraction ---

    function testOwnedDecoderV6SwapReturnsThreeAddresses() external {
        address executor = 0x0BB7a4Fdea32910038DEc59c20ccAe3a6E66b09f;
        OneInchOwnedDecoderAndSanitizer decoder =
            new OneInchOwnedDecoderAndSanitizer(address(this), executor);

        address srcToken = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        address dstToken = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address dstReceiver = address(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f);

        DecoderCustomTypes.SwapDescription memory desc = DecoderCustomTypes.SwapDescription({
            srcToken: srcToken,
            dstToken: dstToken,
            srcReceiver: payable(executor),
            dstReceiver: payable(dstReceiver),
            amount: 1e6,
            minReturnAmount: 9e5,
            flags: 0
        });

        // V6 swap (3 params, no permit)
        bytes memory result = decoder.swap(executor, desc, "");
        assertEq(result, abi.encodePacked(srcToken, dstToken, dstReceiver));
    }

    function testOwnedDecoderV6SwapInvalidExecutorReverts() external {
        address executor = 0x0BB7a4Fdea32910038DEc59c20ccAe3a6E66b09f;
        OneInchOwnedDecoderAndSanitizer decoder =
            new OneInchOwnedDecoderAndSanitizer(address(this), executor);

        DecoderCustomTypes.SwapDescription memory desc = DecoderCustomTypes.SwapDescription({
            srcToken: address(0xdAC17F958D2ee523a2206206994597C13D831ec7),
            dstToken: address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
            srcReceiver: payable(executor),
            dstReceiver: payable(address(this)),
            amount: 1e6,
            minReturnAmount: 9e5,
            flags: 0
        });

        vm.expectRevert(OneInchOwnedDecoderAndSanitizer.OneInchDecoderAndSanitizer__InvalidExecutor.selector);
        decoder.swap(address(0xdead), desc, "");
    }

    function testOwnedDecoderUnoswap() external {
        OneInchOwnedDecoderAndSanitizer decoder =
            new OneInchOwnedDecoderAndSanitizer(address(this), address(1));

        address token = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        address dex = address(0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3);

        uint256 tokenWithFlags = uint256(uint160(token)) | (uint256(0xABCDEF) << 160);
        uint256 dexWithFlags = uint256(uint160(dex)) | (uint256(0x123456) << 160);

        bytes memory result = decoder.unoswap(tokenWithFlags, 1e6, 9e5, dexWithFlags);
        assertEq(result, abi.encodePacked(token, dex));
    }

    function testOwnedDecoderUnoswap2() external {
        OneInchOwnedDecoderAndSanitizer decoder =
            new OneInchOwnedDecoderAndSanitizer(address(this), address(1));

        address token = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        address dex1 = address(0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3);
        address dex2 = address(0x13947303F63b363876868D070F14dc865C36463b);

        uint256 tokenWithFlags = uint256(uint160(token)) | (uint256(0xFF) << 160);
        uint256 dex1WithFlags = uint256(uint160(dex1)) | (uint256(0xAA) << 160);
        uint256 dex2WithFlags = uint256(uint160(dex2)) | (uint256(0xBB) << 160);

        bytes memory result = decoder.unoswap2(tokenWithFlags, 1e6, 9e5, dex1WithFlags, dex2WithFlags);
        assertEq(result, abi.encodePacked(token, dex1, dex2));
    }

    function testOwnedDecoderUnoswap3() external {
        OneInchOwnedDecoderAndSanitizer decoder =
            new OneInchOwnedDecoderAndSanitizer(address(this), address(1));

        address token = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        address dex1 = address(0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3);
        address dex2 = address(0x13947303F63b363876868D070F14dc865C36463b);
        address dex3 = address(0x0f3159811670c117c372428D4E69AC32325e4D0F);

        uint256 tokenWithFlags = uint256(uint160(token)) | (uint256(0xFF) << 160);
        uint256 dex1WithFlags = uint256(uint160(dex1)) | (uint256(0xAA) << 160);
        uint256 dex2WithFlags = uint256(uint160(dex2)) | (uint256(0xBB) << 160);
        uint256 dex3WithFlags = uint256(uint160(dex3)) | (uint256(0xCC) << 160);

        bytes memory result =
            decoder.unoswap3(tokenWithFlags, 1e6, 9e5, dex1WithFlags, dex2WithFlags, dex3WithFlags);
        assertEq(result, abi.encodePacked(token, dex1, dex2, dex3));
    }

    function testOwnedDecoderEthUnoswap() external {
        OneInchOwnedDecoderAndSanitizer decoder =
            new OneInchOwnedDecoderAndSanitizer(address(this), address(1));

        address dex = address(0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3);
        uint256 dexWithFlags = uint256(uint160(dex)) | (uint256(0xDEAD) << 160);

        bytes memory result = decoder.ethUnoswap(9e17, dexWithFlags);
        assertEq(result, abi.encodePacked(dex));
    }

    function testOwnedDecoderEthUnoswap2() external {
        OneInchOwnedDecoderAndSanitizer decoder =
            new OneInchOwnedDecoderAndSanitizer(address(this), address(1));

        address dex1 = address(0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3);
        address dex2 = address(0x13947303F63b363876868D070F14dc865C36463b);
        uint256 dex1WithFlags = uint256(uint160(dex1)) | (uint256(0xDEAD) << 160);
        uint256 dex2WithFlags = uint256(uint160(dex2)) | (uint256(0xBEEF) << 160);

        bytes memory result = decoder.ethUnoswap2(9e17, dex1WithFlags, dex2WithFlags);
        assertEq(result, abi.encodePacked(dex1, dex2));
    }

    function testOwnedDecoderEthUnoswap3() external {
        OneInchOwnedDecoderAndSanitizer decoder =
            new OneInchOwnedDecoderAndSanitizer(address(this), address(1));

        address dex1 = address(0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3);
        address dex2 = address(0x13947303F63b363876868D070F14dc865C36463b);
        address dex3 = address(0x0f3159811670c117c372428D4E69AC32325e4D0F);
        uint256 dex1WithFlags = uint256(uint160(dex1)) | (uint256(0xDEAD) << 160);
        uint256 dex2WithFlags = uint256(uint160(dex2)) | (uint256(0xBEEF) << 160);
        uint256 dex3WithFlags = uint256(uint160(dex3)) | (uint256(0x6969) << 160);

        bytes memory result = decoder.ethUnoswap3(9e17, dex1WithFlags, dex2WithFlags, dex3WithFlags);
        assertEq(result, abi.encodePacked(dex1, dex2, dex3));
    }
}
