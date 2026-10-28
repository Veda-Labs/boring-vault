// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BridgingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {MPortalDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MPortalDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, Vm} from "@forge-std/Test.sol";

// Bridges mUSD between mainnet and Monad through M Portal V2 using the Wormhole bridge adapter
// (sendToken 8-arg overload, bridgeAdapterArgs = Wormhole Executor signed quote).
// Tests build quotes locally with the fee/price fields and signature copied from a real M0 quote
// (mainnet tx 0xb0e04cd23315bf75be92bc662a8c9584c529d0fd7dbbd3e9f6d4f2f8f3c364a4).
abstract contract MPortalWormholeIntegrationBase is Test, MerkleTreeHelper {
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;

    uint256 internal constant AMOUNT = 10e6;

    bytes32 internal constant TOKEN_SENT_TOPIC = keccak256("TokenSent(address,uint32,bytes32,address,bytes32,uint256,uint128,address,bytes32)");
    bytes32 internal constant LOG_MESSAGE_PUBLISHED_TOPIC = keccak256("LogMessagePublished(address,uint64,uint32,bytes,uint8)");
    bytes32 internal constant REQUEST_FOR_EXECUTION_TOPIC = keccak256("RequestForExecution(address,uint256,uint16,bytes32,address,bytes,bytes,bytes)");

    // baseFee | dstGasPrice | srcPrice | dstPrice and the signature of a real M0 quote.
    bytes32 internal constant QUOTE_FEES_AND_PRICES = 0x000000000003464500000017bfac7c0000001530d075e20000000000145b3c2c;
    bytes internal constant QUOTE_SIGNATURE =
        hex"95f5c8aba630f0f0b12524fa6658cce2cb524961798036ac9a8b201c5681e3a008cc216e16b6dc0dec6ad19ef73b96ea122b4ced9fd6de97a75e98024f3de0121c";

    ERC20 internal mUSD;
    address internal mportalProxy;
    bytes32 internal vaultAsBytes32;
    bytes32 internal destinationToken;

    function _chainName() internal pure virtual returns (string memory);
    function _rpcKey() internal pure virtual returns (string memory);
    function _blockNumber() internal pure virtual returns (uint256);
    function _destinationChainId() internal pure virtual returns (uint32);
    function _srcWormholeChain() internal pure virtual returns (uint16);
    function _dstWormholeChain() internal pure virtual returns (uint16);
    // Executor fee in native token, in line with real M0 quotes on this route.
    function _executorFee() internal pure virtual returns (uint256);
    // bridgeAdapterArgs of a real M0 Wormhole mUSD transfer from this chain, byte for byte.
    function _realQuote() internal pure virtual returns (bytes memory);

    function setUp() external {
        setSourceChainName(_chainName());
        vm.selectFork(vm.createFork(vm.envString(_rpcKey()), _blockNumber()));

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 6);
        // Flash loans are not used; the Balancer vault is only a constructor argument.
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress("mainnet", "vault"));
        rawDataDecoderAndSanitizer = address(new BridgingDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))), true);
        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))), true);
        rolesAuthority.setRoleCapability(STRATEGIST_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);
        rolesAuthority.setRoleCapability(MANGER_INTERNAL_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true);

        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);

        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);

        mUSD = getERC20(sourceChain, "mUSD");
        mportalProxy = getAddress(sourceChain, "mportalProxy");
        vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        destinationToken = bytes32(uint256(uint160(address(mUSD))));

        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 10 * _executorFee());
    }

    // ========================================= POSITIVE =========================================

    function testMPortalWormholeBridgeMUSD() external {
        _setWormholeRoot();
        address payee = getAddress(sourceChain, "wormholeExecutorPayee");
        uint256 fee = _executorFee();

        uint256 vaultBefore = mUSD.balanceOf(address(boringVault));
        uint256 supplyBefore = mUSD.totalSupply();
        uint256 payeeBefore = payee.balance;

        vm.recordLogs();
        _manage(getAddress(sourceChain, "mportalWormholeAdapter"), _validQuote(), fee);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(mUSD.balanceOf(address(boringVault)), vaultBefore - AMOUNT, "vault mUSD");
        // mUSD is unwrapped to M on both chains (Hub locks M, Spoke burns it).
        assertEq(mUSD.totalSupply(), supplyBefore - AMOUNT, "mUSD supply");
        assertEq(payee.balance, payeeBefore + fee, "Executor pays the whole msg.value to the payee");
        _assertWormholeLogs(logs, fee);
    }

    // Unmodified bridgeAdapterArgs from a real M0 Wormhole transfer on this chain decode to the pinned quoter and payee.
    function testMPortalWormholeDecodesRealQuote() external view {
        bytes memory realQuote = _realQuote();
        assertEq(realQuote.length, 165);
        bytes memory found = MPortalDecoderAndSanitizer(rawDataDecoderAndSanitizer)
            .sendToken(
                AMOUNT,
                address(mUSD),
                _destinationChainId(),
                destinationToken,
                vaultAsBytes32,
                vaultAsBytes32,
                getAddress(sourceChain, "mportalWormholeAdapter"),
                realQuote
            );
        assertEq(found.length, 11 * 20, "11 addresses");
        assertEq(_addressAt(found, 8), getAddress(sourceChain, "mportalWormholeAdapter"));
        assertEq(_addressAt(found, 9), getAddress(sourceChain, "wormholeExecutorQuoter"));
        assertEq(_addressAt(found, 10), getAddress(sourceChain, "wormholeExecutorPayee"));
    }

    // ========================================= MERKLE PINNING =========================================

    function testMPortalWormholeRevertsWrongPayee() external {
        _setWormholeRoot();
        bytes memory quote = _quote(getAddress(sourceChain, "wormholeExecutorQuoter"), address(0xdEaD), uint64(block.timestamp + 1 hours));
        _expectProofFailure(getAddress(sourceChain, "mportalWormholeAdapter"), quote);
    }

    function testMPortalWormholeRevertsWrongQuoter() external {
        _setWormholeRoot();
        bytes memory quote = _quote(address(0xBEEF), getAddress(sourceChain, "wormholeExecutorPayee"), uint64(block.timestamp + 1 hours));
        _expectProofFailure(getAddress(sourceChain, "mportalWormholeAdapter"), quote);
    }

    function testMPortalWormholeRevertsOtherAdapter() external {
        _setWormholeRoot();
        _expectProofFailure(getAddress(sourceChain, "mportalHyperlaneAdapter"), _validQuote());
    }

    // A Wormhole leaf has 11 slots, empty args decode to 9.
    function testMPortalWormholeRevertsEmptyArgs() external {
        _setWormholeRoot();
        _expectProofFailure(getAddress(sourceChain, "mportalWormholeAdapter"), bytes(""));
    }

    // A 9-slot custom-adapter leaf (built for args-free adapters) cannot carry a quote, even for the Wormhole adapter.
    function testMPortalWormholeRevertsQuoteUnderArgsFreeLeaf() external {
        useArgsFreeLeaf = true;
        _setWormholeRoot();
        _expectProofFailure(getAddress(sourceChain, "mportalWormholeAdapter"), _validQuote());
    }

    function testMPortalWormholeRevertsWrongRecipient() external {
        _setWormholeRoot();
        (bytes32[][] memory proofs, address[] memory targets, bytes[] memory data, uint256[] memory values) =
            _buildManageCall(getAddress(sourceChain, "mportalWormholeAdapter"), _validQuote(), _executorFee());
        data[1] = _sendTokenCalldata(bytes32(uint256(uint160(address(0xBAD)))), getAddress(sourceChain, "mportalWormholeAdapter"), _validQuote());
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, mportalProxy, data[1], values[1]
            )
        );
        manager.manageVaultWithMerkleVerification(proofs, _decoders(), targets, data, values);
    }

    // ========================================= QUOTE SHAPE =========================================

    function testMPortalWormholeRevertsShortQuote() external {
        _setWormholeRoot();
        bytes memory q = _validQuote();
        assembly {
            mstore(q, 164)
        }
        _expectInvalidQuote(q);
    }

    function testMPortalWormholeRevertsLongQuote() external {
        _setWormholeRoot();
        _expectInvalidQuote(abi.encodePacked(_validQuote(), bytes1(0)));
    }

    function testMPortalWormholeRevertsWrongPrefix() external {
        _setWormholeRoot();
        bytes memory q = _validQuote();
        q[3] = 0x32; // "EQ02"
        _expectInvalidQuote(q);
    }

    function testMPortalWormholeRevertsDirtyPayeeUpperBytes() external {
        _setWormholeRoot();
        for (uint256 i = 24; i < 36; ++i) {
            bytes memory q = _validQuote();
            q[i] = 0x01;
            _expectInvalidQuote(q);
        }
    }

    // Expiry is not pinned; the Executor enforces it.
    function testMPortalWormholeExpiredQuoteRevertsInExecutor() external {
        _setWormholeRoot();
        bytes memory quote =
            _quote(getAddress(sourceChain, "wormholeExecutorQuoter"), getAddress(sourceChain, "wormholeExecutorPayee"), uint64(block.timestamp));
        (bytes32[][] memory proofs, address[] memory targets, bytes[] memory data, uint256[] memory values) =
            _buildManageCall(getAddress(sourceChain, "mportalWormholeAdapter"), quote, _executorFee());
        vm.expectRevert(abi.encodeWithSignature("QuoteExpired(uint64)", uint64(block.timestamp)));
        manager.manageVaultWithMerkleVerification(proofs, _decoders(), targets, data, values);
    }

    // Quote chains are not in the leaf; the Executor checks them against the chain it runs on and the
    // Wormhole chain the adapter maps the M Portal destination to.
    function testMPortalWormholeQuoteDstMismatchRevertsInExecutor() external {
        _setWormholeRoot();
        uint16 otherChain = 30; // Base
        bytes memory quote = _quote(
            getAddress(sourceChain, "wormholeExecutorQuoter"),
            getAddress(sourceChain, "wormholeExecutorPayee"),
            _srcWormholeChain(),
            otherChain,
            uint64(block.timestamp + 1 hours)
        );
        (bytes32[][] memory proofs, address[] memory targets, bytes[] memory data, uint256[] memory values) =
            _buildManageCall(getAddress(sourceChain, "mportalWormholeAdapter"), quote, _executorFee());
        vm.expectRevert(abi.encodeWithSignature("QuoteDstChainMismatch(uint16,uint16)", otherChain, _dstWormholeChain()));
        manager.manageVaultWithMerkleVerification(proofs, _decoders(), targets, data, values);
    }

    function testMPortalWormholeQuoteSrcMismatchRevertsInExecutor() external {
        _setWormholeRoot();
        uint16 otherChain = 30; // Base
        bytes memory quote = _quote(
            getAddress(sourceChain, "wormholeExecutorQuoter"),
            getAddress(sourceChain, "wormholeExecutorPayee"),
            otherChain,
            _dstWormholeChain(),
            uint64(block.timestamp + 1 hours)
        );
        (bytes32[][] memory proofs, address[] memory targets, bytes[] memory data, uint256[] memory values) =
            _buildManageCall(getAddress(sourceChain, "mportalWormholeAdapter"), quote, _executorFee());
        vm.expectRevert(abi.encodeWithSignature("QuoteSrcChainMismatch(uint16,uint16)", otherChain, _srcWormholeChain()));
        manager.manageVaultWithMerkleVerification(proofs, _decoders(), targets, data, values);
    }

    // ========================================= HELPERS =========================================

    // Root is either the Wormhole leaves or, when set, the args-free custom-adapter leaves pinned to the Wormhole adapter.
    bool internal useArgsFreeLeaf;

    function _setWormholeRoot() internal {
        bytes32[][] memory tree = _generateMerkleTree(_leafs());
        manager.setManageRoot(address(this), tree[tree.length - 1][0]);
    }

    function _leafs() internal returns (ManageLeaf[] memory leafs) {
        leafIndex = type(uint256).max;
        leafs = new ManageLeaf[](2);
        if (useArgsFreeLeaf) {
            _addMPortalLeafs(
                leafs,
                mportalProxy,
                mUSD,
                _destinationChainId(),
                destinationToken,
                vaultAsBytes32,
                vaultAsBytes32,
                getAddress(sourceChain, "mportalWormholeAdapter")
            );
        } else {
            _addMPortalWormholeLeafs(leafs, mportalProxy, mUSD, _destinationChainId(), destinationToken, vaultAsBytes32, vaultAsBytes32);
        }
    }

    function _validQuote() internal view returns (bytes memory) {
        return _quote(getAddress(sourceChain, "wormholeExecutorQuoter"), getAddress(sourceChain, "wormholeExecutorPayee"), uint64(block.timestamp + 1 hours));
    }

    function _quote(address quoter, address payee, uint64 expiry) internal pure returns (bytes memory) {
        return _quote(quoter, payee, _srcWormholeChain(), _dstWormholeChain(), expiry);
    }

    function _quote(address quoter, address payee, uint16 srcChain, uint16 dstChain, uint64 expiry) internal pure returns (bytes memory) {
        return
            abi.encodePacked(bytes4(0x45513031), quoter, bytes32(uint256(uint160(payee))), srcChain, dstChain, expiry, QUOTE_FEES_AND_PRICES, QUOTE_SIGNATURE);
    }

    function _sendTokenCalldata(bytes32 recipient, address adapter, bytes memory args) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            "sendToken(uint256,address,uint32,bytes32,bytes32,bytes32,address,bytes)",
            AMOUNT,
            address(mUSD),
            _destinationChainId(),
            destinationToken,
            recipient,
            vaultAsBytes32,
            adapter,
            args
        );
    }

    function _buildManageCall(address adapter, bytes memory args, uint256 fee)
        internal
        returns (bytes32[][] memory proofs, address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        ManageLeaf[] memory leafs = _leafs();
        proofs = _getProofsUsingTree(leafs, _generateMerkleTree(leafs));

        targets = new address[](2);
        targets[0] = address(mUSD);
        targets[1] = mportalProxy;

        data = new bytes[](2);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", mportalProxy, type(uint256).max);
        data[1] = _sendTokenCalldata(vaultAsBytes32, adapter, args);

        values = new uint256[](2);
        values[1] = fee;
    }

    function _manage(address adapter, bytes memory args, uint256 fee) internal {
        (bytes32[][] memory proofs, address[] memory targets, bytes[] memory data, uint256[] memory values) = _buildManageCall(adapter, args, fee);
        manager.manageVaultWithMerkleVerification(proofs, _decoders(), targets, data, values);
    }

    function _expectProofFailure(address adapter, bytes memory args) internal {
        (bytes32[][] memory proofs, address[] memory targets, bytes[] memory data, uint256[] memory values) = _buildManageCall(adapter, args, _executorFee());
        uint256 vaultBefore = mUSD.balanceOf(address(boringVault));
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, mportalProxy, data[1], values[1]
            )
        );
        manager.manageVaultWithMerkleVerification(proofs, _decoders(), targets, data, values);
        assertEq(mUSD.balanceOf(address(boringVault)), vaultBefore, "mUSD must not leave the vault");
    }

    function _expectInvalidQuote(bytes memory args) internal {
        (bytes32[][] memory proofs, address[] memory targets, bytes[] memory data, uint256[] memory values) =
            _buildManageCall(getAddress(sourceChain, "mportalWormholeAdapter"), args, _executorFee());
        vm.expectRevert(MPortalDecoderAndSanitizer.MPortalDecoderAndSanitizer__InvalidSignedQuote.selector);
        manager.manageVaultWithMerkleVerification(proofs, _decoders(), targets, data, values);
    }

    function _assertWormholeLogs(Vm.Log[] memory logs, uint256 fee) internal view {
        address adapter = getAddress(sourceChain, "mportalWormholeAdapter");
        bool tokenSent;
        bool published;
        bool requested;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.emitter == mportalProxy && log.topics[0] == TOKEN_SENT_TOPIC) {
                (,,,, address bridgeAdapter,) = abi.decode(log.data, (uint32, bytes32, uint256, uint128, address, bytes32));
                assertEq(bridgeAdapter, adapter, "TokenSent adapter");
                tokenSent = true;
            } else if (log.emitter == getAddress(sourceChain, "wormholeCoreBridge") && log.topics[0] == LOG_MESSAGE_PUBLISHED_TOPIC) {
                assertEq(address(uint160(uint256(log.topics[1]))), adapter, "Core Bridge message sender");
                published = true;
            } else if (log.emitter == getAddress(sourceChain, "wormholeExecutor") && log.topics[0] == REQUEST_FOR_EXECUTION_TOPIC) {
                assertEq(address(uint160(uint256(log.topics[1]))), getAddress(sourceChain, "wormholeExecutorQuoter"), "quoter");
                (uint256 amtPaid, uint16 dstChain,, address refundAddr) = abi.decode(log.data, (uint256, uint16, bytes32, address));
                assertEq(amtPaid, fee, "Executor amount paid");
                assertEq(dstChain, _dstWormholeChain(), "Executor destination chain");
                assertEq(refundAddr, address(boringVault), "Executor refund address");
                requested = true;
            }
        }
        assertTrue(tokenSent, "TokenSent not emitted");
        assertTrue(published, "LogMessagePublished not emitted");
        assertTrue(requested, "RequestForExecution not emitted");
    }

    function _decoders() internal view returns (address[] memory d) {
        d = new address[](2);
        d[0] = rawDataDecoderAndSanitizer;
        d[1] = rawDataDecoderAndSanitizer;
    }

    function _addressAt(bytes memory packed, uint256 i) internal pure returns (address a) {
        assembly {
            a := shr(96, mload(add(add(packed, 32), mul(i, 20))))
        }
    }
}

// forge test --match-path "test/integrations/MPortalWormholeIntegration.t.sol" -vvv
contract MPortalWormholeIntegrationTest is MPortalWormholeIntegrationBase {
    function _chainName() internal pure override returns (string memory) {
        return "mainnet";
    }

    function _rpcKey() internal pure override returns (string memory) {
        return "MAINNET_RPC_URL";
    }

    // After the M Portal V2 upgrade to 0xf1c63a35b68a5513b97e05fa2e111d7cc55beaee (block 25900402).
    function _blockNumber() internal pure override returns (uint256) {
        return 26_085_931;
    }

    function _destinationChainId() internal pure override returns (uint32) {
        return 143;
    }

    function _srcWormholeChain() internal pure override returns (uint16) {
        return 2;
    }

    function _dstWormholeChain() internal pure override returns (uint16) {
        return 48;
    }

    // Real mainnet->Monad mUSD fee (tx 0xb0e04cd23315bf75be92bc662a8c9584c529d0fd7dbbd3e9f6d4f2f8f3c364a4).
    function _executorFee() internal pure override returns (uint256) {
        return 25_047_987_801_402;
    }

    // Mainnet->Monad mUSD tx 0xb0e04cd23315bf75be92bc662a8c9584c529d0fd7dbbd3e9f6d4f2f8f3c364a4.
    function _realQuote() internal pure override returns (bytes memory) {
        return hex"45513031a54008017941ece968623a0dd8ee907e2b1335960000000000000000000000006a8bfc410a3cc7306d52872f116afb12f1cec6c6000200300000000069e13dad000000000003464500000017bfac7c0000001530d075e20000000000145b3c2c95f5c8aba630f0f0b12524fa6658cce2cb524961798036ac9a8b201c5681e3a008cc216e16b6dc0dec6ad19ef73b96ea122b4ced9fd6de97a75e98024f3de0121c";
    }
}
