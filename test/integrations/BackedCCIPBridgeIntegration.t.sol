// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {BridgingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {BackedCCIPDecoderAndSanitizer, BACKED_CCIP_SOLANA_CHAIN_SELECTOR, BACKED_CCIP_MAX_SVM_ACCOUNTS} from
    "src/base/DecodersAndSanitizers/Protocols/BackedCCIPDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

interface IBackedCCIPReceiver {
    function custodyWallet() external view returns (address);
    function chainInfos(uint64 destinationChainSelector) external view returns (uint8 variant, uint256 defaultGasLimit);
    function allowlistedDestinationChains(uint64 destinationChainSelector) external view returns (bytes32 receiver);
    function getDeliveryFeeCost(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        uint256 amount,
        bytes calldata chainSpecificArgs
    ) external view returns (uint256);
}

contract LengthInferredBackedCCIPDecoder is BaseDecoderAndSanitizer {
    function send(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        uint256,
        bytes calldata chainSpecificArgs
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(
            address(uint160(destinationChainSelector)),
            address(bytes20(bytes16(tokenReceiver))),
            address(bytes20(bytes16(tokenReceiver << 128))),
            token
        );

        if (chainSpecificArgs.length > 0) {
            (uint64 accountIsWritableBitmap, bytes32[] memory accounts) =
                abi.decode(chainSpecificArgs, (uint64, bytes32[]));
            addressesFound = abi.encodePacked(addressesFound, address(uint160(accountIsWritableBitmap)));
            for (uint256 i; i < accounts.length; ++i) {
                addressesFound = abi.encodePacked(
                    addressesFound,
                    address(bytes20(bytes16(accounts[i]))),
                    address(bytes20(bytes16(accounts[i] << 128)))
                );
            }
        }
    }
}

contract SendOnlyBackedCCIPDecoder is BackedCCIPDecoderAndSanitizer {}

contract BackedCCIPBridgeIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    // CCIP chain selectors.
    uint64 internal constant SOLANA_CHAIN_SELECTOR = BACKED_CCIP_SOLANA_CHAIN_SELECTOR;
    uint64 internal constant ARBITRUM_CHAIN_SELECTOR = 4949039107694359620;

    // MSTRx whale, sender of the example bridging tx.
    address internal constant MSTRX_WHALE = 0x2a9428cb48DFD919254C8c7792d77fFF58b9A096;
    uint256 internal constant BRIDGE_AMOUNT = 11.99e18;

    // Solana side values from the example bridging tx.
    bytes32 internal constant SOLANA_TOKEN_RECEIVER = 0xa74c1e480b93da7f85d42c89796981300f42d99723a41de1ddca196df293f14d;
    uint64 internal constant ACCOUNT_IS_WRITABLE_BITMAP = 772;
    bytes32 internal constant DRONE_TARGET_FLAG = 0x3e4620193929cbc3d9d6e48812033a2439d3c505d118da7e25b1c3241695f5b1;

    ERC20 internal mstrx;
    address internal backedCCIPBridge;
    address internal custodyWallet;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        // One block before the example tx so its sender still holds the MSTRx being bridged.
        uint256 blockNumber = 25434123;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new BridgingDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
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
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);

        mstrx = getERC20(sourceChain, "MSTRx");
        backedCCIPBridge = getAddress(sourceChain, "backedCCIPBridge");
        custodyWallet = IBackedCCIPReceiver(backedCCIPBridge).custodyWallet();

        // Fund the vault with MSTRx and ETH for the CCIP fee.
        vm.prank(MSTRX_WHALE);
        mstrx.transfer(address(boringVault), BRIDGE_AMOUNT);
        deal(address(boringVault), 1e18);
    }

    // ========================================= HAPPY PATHS =========================================

    function testBackedCCIPBridgeToSolana() external {
        (
            bytes32[][] memory manageProofs,
            address[] memory targets,
            bytes[] memory targetData,
            uint256[] memory values,
            address[] memory decodersAndSanitizers
        ) = _buildSolanaBridgeCalls(_solanaChainSpecificArgs());

        uint256 custodyBalanceBefore = mstrx.balanceOf(custodyWallet);
        uint256 vaultEthBefore = address(boringVault).balance;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(mstrx.balanceOf(address(boringVault)), 0, "MSTRx should have left the vault");
        assertEq(
            mstrx.balanceOf(custodyWallet), custodyBalanceBefore + BRIDGE_AMOUNT, "custody wallet should hold MSTRx"
        );
        assertEq(address(boringVault).balance, vaultEthBefore - values[1], "vault should only spend the CCIP fee");
    }

    function testBackedCCIPBridgeToArbitrum() external {
        // EVM destination: chainSpecificArgs must be empty bytes.
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addBackedCCIPBridgeLeafs(
            leafs,
            backedCCIPBridge,
            ARBITRUM_CHAIN_SELECTOR,
            bytes32(uint256(uint160(address(boringVault)))),
            mstrx,
            0,
            new bytes32[](0)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        bytes32[][] memory manageProofs = _getProofsUsingTree(leafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(mstrx);
        targets[1] = backedCCIPBridge;

        bytes memory emptyArgs;
        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", backedCCIPBridge, BRIDGE_AMOUNT);
        targetData[1] = abi.encodeWithSignature(
            "send(uint64,bytes32,address,uint256,bytes)",
            ARBITRUM_CHAIN_SELECTOR,
            bytes32(uint256(uint160(address(boringVault)))),
            address(mstrx),
            BRIDGE_AMOUNT,
            emptyArgs
        );

        uint256[] memory values = new uint256[](2);
        values[1] = IBackedCCIPReceiver(backedCCIPBridge).getDeliveryFeeCost(
            ARBITRUM_CHAIN_SELECTOR,
            bytes32(uint256(uint160(address(boringVault)))),
            address(mstrx),
            BRIDGE_AMOUNT,
            emptyArgs
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertEq(mstrx.balanceOf(address(boringVault)), 0, "MSTRx should have left the vault");
    }

    function testBackedCCIPBridgeReverts__TrailingGarbageInChainSpecificArgs() external {
        // The leaf helper always produces abi.encode(bitmap, accounts), so alternative encodings
        // are rejected even when they decode to the same values.
        bytes memory paddedArgs = abi.encodePacked(_solanaChainSpecificArgs(), bytes32(type(uint256).max));

        (
            bytes32[][] memory manageProofs,
            address[] memory targets,
            bytes[] memory targetData,
            uint256[] memory values,
            address[] memory decodersAndSanitizers
        ) = _buildSolanaBridgeCalls(paddedArgs);

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBackedCCIPBridgeReverts__OffsetAliasedChainSpecificArgs() external {
        // Non-canonical inner encoding: the array offset points past a gap word (0x60 instead of 0x40).
        bytes32[] memory accounts = _solanaAccounts();
        bytes memory aliased = abi.encodePacked(
            uint256(ACCOUNT_IS_WRITABLE_BITMAP), // head word 0: bitmap
            uint256(0x60), // head word 1: offset to array data
            uint256(0xDEAD), // gap word skipped by the offset
            uint256(accounts.length)
        );
        for (uint256 i; i < accounts.length; ++i) {
            aliased = abi.encodePacked(aliased, accounts[i]);
        }

        (
            bytes32[][] memory manageProofs,
            address[] memory targets,
            bytes[] memory targetData,
            uint256[] memory values,
            address[] memory decodersAndSanitizers
        ) = _buildSolanaBridgeCalls(aliased);

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= MALICIOUS STRATEGIST =========================================

    function testBackedCCIPBridgeReverts__TamperedSolanaAccount() external {
        // Swap a writable account (index 8 is writable per bitmap 0b1100000100) for an attacker one.
        bytes32[] memory accounts = _solanaAccounts();
        accounts[8] = bytes32(uint256(0xBAD));
        _assertSendFailsProofVerification(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            abi.encode(ACCOUNT_IS_WRITABLE_BITMAP, accounts)
        );
    }

    function testBackedCCIPBridgeReverts__TamperedSolanaAccountLowHalf() external {
        // Flip a single bit in the LOW 16 bytes of an account, so the high-half pseudo address is unchanged.
        bytes32[] memory accounts = _solanaAccounts();
        accounts[0] = accounts[0] ^ bytes32(uint256(1));
        _assertSendFailsProofVerification(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            abi.encode(ACCOUNT_IS_WRITABLE_BITMAP, accounts)
        );
    }

    function testBackedCCIPBridgeReverts__ReorderedSolanaAccounts() external {
        // Same set of accounts, different order.
        bytes32[] memory accounts = _solanaAccounts();
        (accounts[0], accounts[1]) = (accounts[1], accounts[0]);
        _assertSendFailsProofVerification(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            abi.encode(ACCOUNT_IS_WRITABLE_BITMAP, accounts)
        );
    }

    function testBackedCCIPBridgeReverts__ExtraSolanaAccount() external {
        bytes32[] memory accounts = _solanaAccounts();
        bytes32[] memory extended = new bytes32[](accounts.length + 1);
        for (uint256 i; i < accounts.length; ++i) {
            extended[i] = accounts[i];
        }
        extended[accounts.length] = bytes32(uint256(0xBAD));
        _assertSendFailsProofVerification(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            abi.encode(ACCOUNT_IS_WRITABLE_BITMAP, extended)
        );
    }

    function testBackedCCIPBridgeReverts__TamperedWritableBitmap() external {
        _assertSendFailsProofVerification(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            abi.encode(ACCOUNT_IS_WRITABLE_BITMAP ^ uint64(1), _solanaAccounts())
        );
    }

    function testBackedCCIPBridgeReverts__WritableBitmapExceedsAccountList() external {
        _assertSendFailsDecoderValidation(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            abi.encode(uint64(uint256(1) << _solanaAccounts().length), _solanaAccounts())
        );
    }

    function testBackedCCIPBridgeReverts__EmptyChainSpecificArgs() external {
        bytes memory emptyArgs;
        _assertSendFailsDecoderValidation(SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), emptyArgs);
    }

    function testBackedCCIPBridgeReverts__TamperedTokenReceiver() external {
        _assertSendFailsProofVerification(
            SOLANA_CHAIN_SELECTOR, bytes32(uint256(0xBAD)), address(mstrx), _solanaChainSpecificArgs()
        );
    }

    function testBackedCCIPBridgeReverts__TamperedTokenReceiverLowHalf() external {
        _assertSendFailsProofVerification(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER ^ bytes32(uint256(1)),
            address(mstrx),
            _solanaChainSpecificArgs()
        );
    }

    function testBackedCCIPBridgeReverts__TamperedToken() external {
        _assertSendFailsProofVerification(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, getAddress(sourceChain, "WETH"), _solanaChainSpecificArgs()
        );
    }

    function testBackedCCIPBridgeReverts__TamperedDestinationChain() external {
        // A Solana-shaped call cannot be reinterpreted as an EVM call by changing the selector.
        _assertSendFailsDecoderValidation(
            ARBITRUM_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), _solanaChainSpecificArgs()
        );
    }

    function testBackedCCIPBridgeReverts__NonEmptyChainSpecificArgsOnEvmLeaf() external {
        _assertEvmSendFailsDecoderValidation(_solanaChainSpecificArgs());
    }

    function testBackedCCIPBridgeReverts__EmptyAccountsEncodingOnEvmLeaf() external {
        _assertEvmSendFailsDecoderValidation(abi.encode(uint64(0), new bytes32[](0)));
    }

    function testBackedCCIPBridgeReverts__EmptyAccountsArrayEncoding() external {
        _assertSendFailsDecoderValidation(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            abi.encode(ACCOUNT_IS_WRITABLE_BITMAP, new bytes32[](0))
        );
    }

    function testSolanaLeafCannotAuthorizeValidEvmShape() external {
        bytes32 receiver = bytes32(uint256(uint160(address(boringVault))));
        ManageLeaf[] memory leafs = _solanaLeafs(receiver);
        bytes memory emptyArgs;

        _assertCallWithLeafReverts(
            leafs, ARBITRUM_CHAIN_SELECTOR, receiver, address(mstrx), emptyArgs, false
        );
    }

    function testEvmLeafRejectsSolanaSelectorWithEmptyArgsAtDecoder() external {
        bytes32 receiver = bytes32(uint256(uint160(address(boringVault))));
        ManageLeaf[] memory leafs = _evmLeafs(ARBITRUM_CHAIN_SELECTOR, receiver);
        bytes memory emptyArgs;

        _assertCallWithLeafReverts(leafs, SOLANA_CHAIN_SELECTOR, receiver, address(mstrx), emptyArgs, true);
    }

    function testEvmLeafCannotAuthorizeValidSolanaShape() external {
        bytes32 receiver = bytes32(uint256(uint160(address(boringVault))));
        ManageLeaf[] memory leafs = _evmLeafs(ARBITRUM_CHAIN_SELECTOR, receiver);

        _assertCallWithLeafReverts(
            leafs, SOLANA_CHAIN_SELECTOR, receiver, address(mstrx), _solanaChainSpecificArgs(), false
        );
    }

    // ========================================= LEAF HELPER GUARDS =========================================

    /// @dev External wrapper so vm.expectRevert can observe the internal helper's requires.
    function exposed_addBackedCCIPBridgeLeafs(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        uint64 accountIsWritableBitmap,
        bytes32[] calldata solanaAccounts
    ) external {
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addBackedCCIPBridgeLeafs(
            leafs,
            backedCCIPBridge,
            destinationChainSelector,
            tokenReceiver,
            mstrx,
            accountIsWritableBitmap,
            solanaAccounts
        );
    }

    function testLeafHelperReverts__ZeroTokenReceiver() external {
        vm.expectRevert("Token receiver cannot be zero");
        this.exposed_addBackedCCIPBridgeLeafs(
            SOLANA_CHAIN_SELECTOR, bytes32(0), ACCOUNT_IS_WRITABLE_BITMAP, _solanaAccounts()
        );
    }

    function testLeafHelperReverts__ZeroEvmTokenReceiver() external {
        vm.expectRevert("Token receiver cannot be zero");
        this.exposed_addBackedCCIPBridgeLeafs(ARBITRUM_CHAIN_SELECTOR, bytes32(0), 0, new bytes32[](0));
    }

    function testLeafHelperReverts__NonCanonicalEvmTokenReceiver() external {
        vm.expectRevert("EVM token receiver must be canonical");
        this.exposed_addBackedCCIPBridgeLeafs(
            ARBITRUM_CHAIN_SELECTOR, bytes32((uint256(1) << 160) | uint160(address(boringVault))), 0, new bytes32[](0)
        );
    }

    function testLeafHelperReverts__BitmapWithoutAccounts() external {
        vm.expectRevert("Solana accounts cannot be empty");
        this.exposed_addBackedCCIPBridgeLeafs(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, ACCOUNT_IS_WRITABLE_BITMAP, new bytes32[](0)
        );
    }

    function testLeafHelperReverts__SolanaWithoutAccountsAndZeroBitmap() external {
        vm.expectRevert("Solana accounts cannot be empty");
        this.exposed_addBackedCCIPBridgeLeafs(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, 0, new bytes32[](0)
        );
    }

    function testLeafHelperReverts__EvmWithSolanaAccounts() external {
        vm.expectRevert("EVM destination cannot include Solana accounts");
        this.exposed_addBackedCCIPBridgeLeafs(
            ARBITRUM_CHAIN_SELECTOR,
            bytes32(uint256(uint160(address(boringVault)))),
            0,
            _solanaAccounts()
        );
    }

    function testLeafHelperReverts__EvmWithWritableBitmap() external {
        vm.expectRevert("EVM writable bitmap must be zero");
        this.exposed_addBackedCCIPBridgeLeafs(
            ARBITRUM_CHAIN_SELECTOR,
            bytes32(uint256(uint160(address(boringVault)))),
            1,
            new bytes32[](0)
        );
    }

    function testLeafHelperReverts__TooManySolanaAccounts() external {
        bytes32[] memory accounts = new bytes32[](BACKED_CCIP_MAX_SVM_ACCOUNTS + 1);
        vm.expectRevert("Too many Solana accounts");
        this.exposed_addBackedCCIPBridgeLeafs(SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, 0, accounts);
    }

    function testLeafHelperReverts__WritableBitmapExceedsAccountList() external {
        bytes32[] memory accounts = new bytes32[](1);
        vm.expectRevert("Writable bitmap exceeds account list");
        this.exposed_addBackedCCIPBridgeLeafs(SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, 2, accounts);
    }

    function testLeafHelperReverts__FinalSolanaAccountIsDroneTargetFlag() external {
        bytes32[] memory accounts = new bytes32[](1);
        accounts[0] = DRONE_TARGET_FLAG;

        vm.expectRevert("Final Solana account is Drone target flag");
        this.exposed_addBackedCCIPBridgeLeafs(SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, 0, accounts);
    }

    function testLeafHelperTreatsUnknownSelectorAsEvm() external {
        uint64 unknownSelector = SOLANA_CHAIN_SELECTOR ^ uint64(1);
        bytes32 receiver = bytes32(uint256(uint160(address(boringVault))));

        vm.expectRevert("EVM destination cannot include Solana accounts");
        this.exposed_addBackedCCIPBridgeLeafs(unknownSelector, receiver, 0, _solanaAccounts());
    }

    function testLeafHelperReverts__ConfiguredLengthInferredDecoder() external {
        address lengthInferredDecoder = address(new LengthInferredBackedCCIPDecoder());
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", lengthInferredDecoder);

        vm.expectRevert(
            abi.encodeWithSelector(
                MerkleTreeHelper.MerkleTreeHelper__BackedCCIPDecoderLeafMismatch.selector, lengthInferredDecoder
            )
        );
        this.exposed_addBackedCCIPBridgeLeafs(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, ACCOUNT_IS_WRITABLE_BITMAP, _solanaAccounts()
        );
    }

    function testLeafHelperReverts__ConfiguredDecoderMissingApproval() external {
        address sendOnlyDecoder = address(new SendOnlyBackedCCIPDecoder());
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", sendOnlyDecoder);

        vm.expectRevert(
            abi.encodeWithSelector(
                MerkleTreeHelper.MerkleTreeHelper__BackedCCIPDecoderLeafMismatch.selector, sendOnlyDecoder
            )
        );
        this.exposed_addBackedCCIPBridgeLeafs(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, ACCOUNT_IS_WRITABLE_BITMAP, _solanaAccounts()
        );
    }

    // ========================================= DECODER UNIT CHECKS =========================================

    function testDecoderSendOutput() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);

        bytes32[] memory accounts = new bytes32[](1);
        accounts[0] = SOLANA_TOKEN_RECEIVER;
        uint64 bitmap = 1;

        bytes memory addressesFound = decoder.send(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            BRIDGE_AMOUNT,
            abi.encode(bitmap, accounts)
        );

        bytes memory expected = abi.encodePacked(
            address(uint160(SOLANA_CHAIN_SELECTOR)),
            address(bytes20(bytes16(SOLANA_TOKEN_RECEIVER))),
            address(bytes20(bytes16(SOLANA_TOKEN_RECEIVER << 128))),
            address(mstrx),
            address(uint160(bitmap)),
            address(bytes20(bytes16(SOLANA_TOKEN_RECEIVER))),
            address(bytes20(bytes16(SOLANA_TOKEN_RECEIVER << 128)))
        );
        assertEq(addressesFound, expected, "packed sensitive arguments mismatch");

        bytes memory emptyArgs;
        addressesFound =
            decoder.send(ARBITRUM_CHAIN_SELECTOR, bytes32(uint256(0xABCD)), address(mstrx), BRIDGE_AMOUNT, emptyArgs);
        expected = abi.encodePacked(
            address(uint160(ARBITRUM_CHAIN_SELECTOR)),
            address(bytes20(bytes16(bytes32(uint256(0xABCD))))),
            address(bytes20(bytes16(bytes32(uint256(0xABCD)) << 128))),
            address(mstrx)
        );
        assertEq(addressesFound, expected, "packed sensitive arguments mismatch for empty args");
    }

    function testDecoderRevertsOnMalformedChainSpecificArgs() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);

        // Nonempty but not decodable as (uint64, bytes32[]).
        vm.expectRevert();
        decoder.send(SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), BRIDGE_AMOUNT, hex"deadbeef");
    }

    function testDecoderRevertsOnInRangePayloadWithOversizedArrayLength() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes memory malformed = abi.encodePacked(
            uint256(0), // bitmap
            uint256(0x40), // canonical array offset
            type(uint256).max, // impossible array length
            bytes32(0) // keeps total byte length inside the decoder's accepted range
        );

        vm.expectRevert();
        decoder.send(SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), BRIDGE_AMOUNT, malformed);
    }

    function testDecoderRevertsOnEmptySolanaChainSpecificArgs() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes memory emptyArgs;

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(
            SOLANA_CHAIN_SELECTOR,
            bytes32(uint256(uint160(address(boringVault)))),
            address(mstrx),
            BRIDGE_AMOUNT,
            emptyArgs
        );
    }

    function testDecoderRevertsOnNonEmptyEvmChainSpecificArgs() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(
            ARBITRUM_CHAIN_SELECTOR,
            bytes32(uint256(uint160(address(boringVault)))),
            address(mstrx),
            BRIDGE_AMOUNT,
            _solanaChainSpecificArgs()
        );
    }

    function testDecoderRevertsOnCanonicalEmptySolanaAccounts() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            BRIDGE_AMOUNT,
            abi.encode(uint64(0), new bytes32[](0))
        );
    }

    function testDecoderRevertsOnTooManySolanaAccounts() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes32[] memory accounts = new bytes32[](BACKED_CCIP_MAX_SVM_ACCOUNTS + 1);

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), BRIDGE_AMOUNT, abi.encode(uint64(0), accounts)
        );
    }

    function testDecoderRevertsOnWritableBitmapExceedingAccountList() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes32[] memory accounts = new bytes32[](1);

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), BRIDGE_AMOUNT, abi.encode(uint64(2), accounts)
        );
    }

    function testDecoderRevertsOnFinalSolanaAccountDroneTargetFlag() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes32[] memory accounts = new bytes32[](1);
        accounts[0] = DRONE_TARGET_FLAG;

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), BRIDGE_AMOUNT, abi.encode(uint64(0), accounts)
        );
    }

    function testDecoderRevertsOnNonCanonicalSolanaEncoding() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes memory paddedArgs = abi.encodePacked(_solanaChainSpecificArgs(), bytes32(type(uint256).max));

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), BRIDGE_AMOUNT, paddedArgs);
    }

    function testDecoderRevertsOnZeroTokenReceiver() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);

        vm.expectRevert(BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidTokenReceiver.selector);
        decoder.send(SOLANA_CHAIN_SELECTOR, bytes32(0), address(mstrx), BRIDGE_AMOUNT, _solanaChainSpecificArgs());

        bytes memory emptyArgs;
        vm.expectRevert(BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidTokenReceiver.selector);
        decoder.send(ARBITRUM_CHAIN_SELECTOR, bytes32(0), address(mstrx), BRIDGE_AMOUNT, emptyArgs);
    }

    function testDecoderRevertsOnNonCanonicalEvmTokenReceiver() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes memory emptyArgs;
        bytes32 nonCanonicalReceiver = bytes32((uint256(1) << 160) | uint160(address(boringVault)));

        vm.expectRevert(BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidTokenReceiver.selector);
        decoder.send(ARBITRUM_CHAIN_SELECTOR, nonCanonicalReceiver, address(mstrx), BRIDGE_AMOUNT, emptyArgs);
    }

    function testKnownSolanaSelectorConstant() external pure {
        assertEq(BACKED_CCIP_SOLANA_CHAIN_SELECTOR, uint64(124615329519749607));
    }

    function testKnownSelectorsMatchDeployedBridgeVariants() external view {
        (uint8 solanaVariant,) = IBackedCCIPReceiver(backedCCIPBridge).chainInfos(SOLANA_CHAIN_SELECTOR);
        (uint8 arbitrumVariant,) = IBackedCCIPReceiver(backedCCIPBridge).chainInfos(ARBITRUM_CHAIN_SELECTOR);

        assertEq(solanaVariant, 1, "configured Solana selector is not SVM on deployed bridge");
        assertEq(arbitrumVariant, 0, "configured Arbitrum selector is not EVM on deployed bridge");
        assertTrue(
            IBackedCCIPReceiver(backedCCIPBridge).allowlistedDestinationChains(SOLANA_CHAIN_SELECTOR) != bytes32(0),
            "configured Solana selector is not allowlisted"
        );
    }

    function testDecoderTreatsUnknownSelectorAsEvm() external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        uint64 unknownSelector = SOLANA_CHAIN_SELECTOR ^ uint64(1);
        bytes32 receiver = bytes32(uint256(uint160(address(boringVault))));
        bytes memory emptyArgs;

        bytes memory addressesFound = decoder.send(unknownSelector, receiver, address(mstrx), BRIDGE_AMOUNT, emptyArgs);
        assertEq(addressesFound.length, 80, "unknown selector must use EVM shape");

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(unknownSelector, receiver, address(mstrx), BRIDGE_AMOUNT, _solanaChainSpecificArgs());
    }

    function testSolanaLeafHelperMatchesDecoderOutput() external {
        ManageLeaf[] memory leafs = _solanaLeafs();
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);

        bytes memory decoderOutput = decoder.send(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            BRIDGE_AMOUNT,
            _solanaChainSpecificArgs()
        );
        assertEq(_packLeafArguments(leafs[1]), decoderOutput, "Solana leaf and decoder output diverge");
    }

    function testEvmLeafHelperMatchesDecoderOutput() external {
        bytes32 receiver = bytes32(uint256(uint160(address(boringVault))));
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addBackedCCIPBridgeLeafs(
            leafs, backedCCIPBridge, ARBITRUM_CHAIN_SELECTOR, receiver, mstrx, 0, new bytes32[](0)
        );
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes memory emptyArgs;

        bytes memory decoderOutput =
            decoder.send(ARBITRUM_CHAIN_SELECTOR, receiver, address(mstrx), BRIDGE_AMOUNT, emptyArgs);
        assertEq(_packLeafArguments(leafs[1]), decoderOutput, "EVM leaf and decoder output diverge");
    }

    function testMaxSolanaAccountsLeafHelperMatchesDecoderOutput() external {
        bytes32[] memory accounts = new bytes32[](BACKED_CCIP_MAX_SVM_ACCOUNTS);
        for (uint256 i; i < accounts.length; ++i) {
            accounts[i] = keccak256(abi.encode(i));
        }

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addBackedCCIPBridgeLeafs(
            leafs,
            backedCCIPBridge,
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            mstrx,
            type(uint64).max,
            accounts
        );
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        bytes memory decoderOutput = decoder.send(
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            BRIDGE_AMOUNT,
            abi.encode(type(uint64).max, accounts)
        );

        assertEq(_packLeafArguments(leafs[1]), decoderOutput, "64-account leaf and decoder output diverge");
    }

    // ========================================= DECODER FUZZ CHECKS =========================================

    /// @dev Inverse oracle for the selector-gated Solana shape. Inputs are normalized only to the
    ///      domain accepted by both the decoder and leaf helper.
    function testFuzz_DecoderPinsEverySolanaValue(
        bytes32 tokenReceiver,
        address token,
        uint256 amount,
        uint64 accountIsWritableBitmap,
        bytes32[] memory accountSeed
    ) external view {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        if (tokenReceiver == bytes32(0)) tokenReceiver = bytes32(uint256(1));
        bytes32[] memory accounts = _normalizeSolanaAccounts(accountSeed);
        accountIsWritableBitmap = _maskBitmap(accountIsWritableBitmap, accounts.length);

        bytes memory addressesFound = decoder.send(
            SOLANA_CHAIN_SELECTOR, tokenReceiver, token, amount, abi.encode(accountIsWritableBitmap, accounts)
        );

        assertEq(addressesFound.length, 20 * (5 + 2 * accounts.length), "packed length pins account count");
        assertEq(
            address(bytes20(_unit(addressesFound, 0))),
            address(uint160(SOLANA_CHAIN_SELECTOR)),
            "Solana selector not pinned"
        );
        assertEq(_reassembleBytes32(addressesFound, 1), tokenReceiver, "token receiver not pinned");
        assertEq(address(bytes20(_unit(addressesFound, 3))), token, "token not pinned");
        assertEq(
            address(bytes20(_unit(addressesFound, 4))),
            address(uint160(accountIsWritableBitmap)),
            "writable bitmap not pinned"
        );
        for (uint256 i; i < accounts.length; ++i) {
            assertEq(_reassembleBytes32(addressesFound, 5 + 2 * i), accounts[i], "Solana account not pinned");
        }
    }

    function testFuzz_DecoderPinsEveryEvmValue(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        uint256 amount
    ) external view {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        destinationChainSelector = _asEvmSelector(destinationChainSelector);
        tokenReceiver = _asEvmReceiver(tokenReceiver);

        bytes memory emptyArgs;
        bytes memory addressesFound = decoder.send(destinationChainSelector, tokenReceiver, token, amount, emptyArgs);

        assertEq(addressesFound.length, 80, "EVM shape is exactly 4 addresses");
        assertEq(
            address(bytes20(_unit(addressesFound, 0))),
            address(uint160(destinationChainSelector)),
            "chain selector not pinned"
        );
        assertEq(_reassembleBytes32(addressesFound, 1), tokenReceiver, "token receiver not pinned");
        assertEq(address(bytes20(_unit(addressesFound, 3))), token, "token not pinned");
    }

    /// @dev Every one-bit change to a value accepted by the Solana branch changes its packed output.
    function testFuzz_SolanaOutputChangesOnAnyPinnedBitFlip(
        bytes32 tokenReceiver,
        address token,
        uint64 accountIsWritableBitmap,
        bytes32[] memory accountSeed,
        uint256 mode,
        uint256 accountIndex,
        uint8 bitIndex
    ) external view {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        if (tokenReceiver == bytes32(0)) tokenReceiver = bytes32(uint256(1));
        bytes32[] memory accounts = _normalizeSolanaAccounts(accountSeed);
        accountIsWritableBitmap = _maskBitmap(accountIsWritableBitmap, accounts.length);
        mode = bound(mode, 0, 3);

        bytes memory packedBefore = decoder.send(
            SOLANA_CHAIN_SELECTOR, tokenReceiver, token, 0, abi.encode(accountIsWritableBitmap, accounts)
        );

        if (mode == 0) {
            bytes32 receiverDelta = bytes32(uint256(1) << bitIndex);
            vm.assume(tokenReceiver ^ receiverDelta != bytes32(0));
            tokenReceiver ^= receiverDelta;
        } else if (mode == 1) {
            token = address(uint160(token) ^ (uint160(1) << (bitIndex % 160)));
        } else if (mode == 2) {
            accountIsWritableBitmap ^= uint64(uint256(1) << (uint256(bitIndex) % accounts.length));
        } else {
            accountIndex = bound(accountIndex, 0, accounts.length - 1);
            accounts[accountIndex] ^= bytes32(uint256(1) << bitIndex);
            vm.assume(accounts[accounts.length - 1] != DRONE_TARGET_FLAG);
        }

        bytes memory packedAfter = decoder.send(
            SOLANA_CHAIN_SELECTOR, tokenReceiver, token, 0, abi.encode(accountIsWritableBitmap, accounts)
        );

        assertTrue(keccak256(packedBefore) != keccak256(packedAfter), "Solana bit flip did not change output");
    }

    function testFuzz_SolanaSelectorBitFlipRejectsSolanaArgs(
        bytes32 tokenReceiver,
        address token,
        uint64 accountIsWritableBitmap,
        bytes32[] memory accountSeed,
        uint8 bitIndex
    ) external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        if (tokenReceiver == bytes32(0)) tokenReceiver = bytes32(uint256(1));
        bytes32[] memory accounts = _normalizeSolanaAccounts(accountSeed);
        accountIsWritableBitmap = _maskBitmap(accountIsWritableBitmap, accounts.length);
        uint64 changedSelector = SOLANA_CHAIN_SELECTOR ^ (uint64(1) << (bitIndex % 64));

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(
            changedSelector, tokenReceiver, token, 0, abi.encode(accountIsWritableBitmap, accounts)
        );
    }

    function testFuzz_NonSolanaSelectorRejectsAnyNonEmptyArgs(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        bytes memory chainSpecificArgs
    ) external {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        destinationChainSelector = _asEvmSelector(destinationChainSelector);
        tokenReceiver = _asEvmReceiver(tokenReceiver);
        if (chainSpecificArgs.length == 0) chainSpecificArgs = hex"01";

        vm.expectRevert(
            BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
        );
        decoder.send(destinationChainSelector, tokenReceiver, token, 0, chainSpecificArgs);
    }

    function testFuzz_AmountDoesNotAffectPacking(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        uint256 amountA,
        uint256 amountB,
        uint64 accountIsWritableBitmap,
        bytes32[] memory accountSeed
    ) external view {
        vm.assume(amountA != amountB);
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        destinationChainSelector = _asEvmSelector(destinationChainSelector);
        tokenReceiver = _asEvmReceiver(tokenReceiver);
        bytes32[] memory accounts = _normalizeSolanaAccounts(accountSeed);
        accountIsWritableBitmap = _maskBitmap(accountIsWritableBitmap, accounts.length);

        bytes memory svmArgs = abi.encode(accountIsWritableBitmap, accounts);
        assertEq(
            keccak256(decoder.send(SOLANA_CHAIN_SELECTOR, tokenReceiver, token, amountA, svmArgs)),
            keccak256(decoder.send(SOLANA_CHAIN_SELECTOR, tokenReceiver, token, amountB, svmArgs)),
            "amount must not affect Solana packing"
        );

        bytes memory emptyArgs;
        assertEq(
            keccak256(decoder.send(destinationChainSelector, tokenReceiver, token, amountA, emptyArgs)),
            keccak256(decoder.send(destinationChainSelector, tokenReceiver, token, amountB, emptyArgs)),
            "amount must not affect EVM packing"
        );
    }

    function testFuzz_EvmOutputChangesOnAnyPinnedBitFlip(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        uint256 mode,
        uint8 bitIndex
    ) external view {
        BackedCCIPDecoderAndSanitizer decoder = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer);
        mode = bound(mode, 0, 2);
        destinationChainSelector = _asEvmSelector(destinationChainSelector);
        tokenReceiver = _asEvmReceiver(tokenReceiver);
        bytes memory emptyArgs;

        bytes memory packedBefore = decoder.send(destinationChainSelector, tokenReceiver, token, 0, emptyArgs);

        if (mode == 0) {
            destinationChainSelector ^= uint64(1) << (bitIndex % 64);
            vm.assume(destinationChainSelector != SOLANA_CHAIN_SELECTOR);
        } else if (mode == 1) {
            bytes32 receiverDelta = bytes32(uint256(1) << (bitIndex % 160));
            vm.assume(tokenReceiver ^ receiverDelta != bytes32(0));
            tokenReceiver ^= receiverDelta;
        } else {
            token = address(uint160(token) ^ (uint160(1) << (bitIndex % 160)));
        }

        bytes memory packedAfter = decoder.send(destinationChainSelector, tokenReceiver, token, 0, emptyArgs);
        assertTrue(keccak256(packedBefore) != keccak256(packedAfter), "EVM bit flip did not change output");
    }

    function testFuzz_SolanaLeafHelperMatchesDecoder(
        bytes32 tokenReceiver,
        uint64 accountIsWritableBitmap,
        bytes32[] memory accountSeed
    ) external {
        if (tokenReceiver == bytes32(0)) tokenReceiver = bytes32(uint256(1));
        bytes32[] memory accounts = _normalizeSolanaAccounts(accountSeed);
        accountIsWritableBitmap = _maskBitmap(accountIsWritableBitmap, accounts.length);
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addBackedCCIPBridgeLeafs(
            leafs,
            backedCCIPBridge,
            SOLANA_CHAIN_SELECTOR,
            tokenReceiver,
            mstrx,
            accountIsWritableBitmap,
            accounts
        );

        bytes memory decoderOutput = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer).send(
            SOLANA_CHAIN_SELECTOR,
            tokenReceiver,
            address(mstrx),
            BRIDGE_AMOUNT,
            abi.encode(accountIsWritableBitmap, accounts)
        );
        assertEq(_packLeafArguments(leafs[1]), decoderOutput, "fuzzed Solana helper/decoder mismatch");
    }

    function testFuzz_EvmLeafHelperMatchesDecoder(uint64 destinationChainSelector, bytes32 tokenReceiver) external {
        destinationChainSelector = _asEvmSelector(destinationChainSelector);
        tokenReceiver = _asEvmReceiver(tokenReceiver);
        ManageLeaf[] memory leafs = _evmLeafs(destinationChainSelector, tokenReceiver);
        bytes memory emptyArgs;

        bytes memory decoderOutput = BackedCCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer).send(
            destinationChainSelector, tokenReceiver, address(mstrx), BRIDGE_AMOUNT, emptyArgs
        );
        assertEq(_packLeafArguments(leafs[1]), decoderOutput, "fuzzed EVM helper/decoder mismatch");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _asEvmSelector(uint64 destinationChainSelector) internal pure returns (uint64) {
        return destinationChainSelector == SOLANA_CHAIN_SELECTOR
            ? destinationChainSelector ^ uint64(1)
            : destinationChainSelector;
    }

    function _asEvmReceiver(bytes32 tokenReceiver) internal pure returns (bytes32) {
        tokenReceiver = bytes32(uint256(uint160(uint256(tokenReceiver))));
        return tokenReceiver == bytes32(0) ? bytes32(uint256(1)) : tokenReceiver;
    }

    function _normalizeSolanaAccounts(bytes32[] memory seed) internal pure returns (bytes32[] memory accounts) {
        uint256 accountCount = seed.length;
        if (accountCount == 0) {
            accountCount = 1;
        } else if (accountCount > BACKED_CCIP_MAX_SVM_ACCOUNTS) {
            accountCount = (accountCount - 1) % BACKED_CCIP_MAX_SVM_ACCOUNTS + 1;
        }

        accounts = new bytes32[](accountCount);
        for (uint256 i; i < accountCount; ++i) {
            accounts[i] = i < seed.length ? seed[i] : bytes32(uint256(i + 1));
        }
        if (accounts[accountCount - 1] == DRONE_TARGET_FLAG) {
            accounts[accountCount - 1] ^= bytes32(uint256(1));
        }
    }

    function _maskBitmap(uint64 bitmap, uint256 accountCount) internal pure returns (uint64) {
        if (accountCount == BACKED_CCIP_MAX_SVM_ACCOUNTS) return bitmap;
        return bitmap & uint64((uint256(1) << accountCount) - 1);
    }

    function _packLeafArguments(ManageLeaf memory leaf) internal pure returns (bytes memory packed) {
        for (uint256 i; i < leaf.argumentAddresses.length; ++i) {
            packed = abi.encodePacked(packed, leaf.argumentAddresses[i]);
        }
    }

    function _solanaAccounts() internal pure returns (bytes32[] memory accounts) {
        // Accounts list from the example bridging tx (CCIP SVMExtraArgsV1.accounts).
        accounts = new bytes32[](11);
        accounts[0] = 0x4b662b2cb13c54da7db33181385169df183c3515ce0278793f39dba34ed50542;
        accounts[1] = 0x24f9d357338f06eefc29dcf41f60aa7cd65bb17247609fc03b2b24f5306a7182;
        accounts[2] = 0xb9a619e5382c52b6623edfeca646b74160292146d171a698f74f842fee17dadd;
        accounts[3] = 0x51956418821a040b82ec633c023b3481aa8b1565c0983e44cfbe29c0178f59a3;
        accounts[4] = 0x07f6079153b4cb42e1cbad143245efbca9c3d22263d5d5721bbbbfbc0d7e6a18;
        accounts[5] = 0x07e86403af8ffb86bfe34788f5c443da364b477c0c25116e65bc630c3011c824;
        accounts[6] = 0x06ddf6e1ee758fde18425dbce46ccddab61afc4d83b90d27febdf928d8a18bfc;
        accounts[7] = 0x74dcc5bd02f4f20d7b2729d1eb996b5e1a8c1aabd30f23c216479f7484da0405;
        accounts[8] = 0x88429d3223b3dabb497c53f505442d3b095a4c7090fb2cff5a8f22c2a4b94da9;
        accounts[9] = 0x28c9efc31340fe87d19343f08b2c149a00c75e8dcb6949c862a0e1c3ec4a6109;
        accounts[10] = SOLANA_TOKEN_RECEIVER;
    }

    function _solanaChainSpecificArgs() internal pure returns (bytes memory) {
        return abi.encode(ACCOUNT_IS_WRITABLE_BITMAP, _solanaAccounts());
    }

    function _solanaLeafs() internal returns (ManageLeaf[] memory leafs) {
        return _solanaLeafs(SOLANA_TOKEN_RECEIVER);
    }

    function _solanaLeafs(bytes32 tokenReceiver) internal returns (ManageLeaf[] memory leafs) {
        leafs = new ManageLeaf[](2);
        _addBackedCCIPBridgeLeafs(
            leafs,
            backedCCIPBridge,
            SOLANA_CHAIN_SELECTOR,
            tokenReceiver,
            mstrx,
            ACCOUNT_IS_WRITABLE_BITMAP,
            _solanaAccounts()
        );
    }

    function _evmLeafs(uint64 destinationChainSelector, bytes32 tokenReceiver)
        internal
        returns (ManageLeaf[] memory leafs)
    {
        leafs = new ManageLeaf[](2);
        _addBackedCCIPBridgeLeafs(
            leafs,
            backedCCIPBridge,
            destinationChainSelector,
            tokenReceiver,
            mstrx,
            0,
            new bytes32[](0)
        );
    }

    function _buildSolanaBridgeCalls(bytes memory chainSpecificArgs)
        internal
        returns (
            bytes32[][] memory manageProofs,
            address[] memory targets,
            bytes[] memory targetData,
            uint256[] memory values,
            address[] memory decodersAndSanitizers
        )
    {
        ManageLeaf[] memory leafs = _solanaLeafs();
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        manageProofs = _getProofsUsingTree(leafs, manageTree);

        targets = new address[](2);
        targets[0] = address(mstrx);
        targets[1] = backedCCIPBridge;

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", backedCCIPBridge, BRIDGE_AMOUNT);
        targetData[1] = abi.encodeWithSignature(
            "send(uint64,bytes32,address,uint256,bytes)",
            SOLANA_CHAIN_SELECTOR,
            SOLANA_TOKEN_RECEIVER,
            address(mstrx),
            BRIDGE_AMOUNT,
            chainSpecificArgs
        );

        values = new uint256[](2);
        values[1] = IBackedCCIPReceiver(backedCCIPBridge).getDeliveryFeeCost(
            SOLANA_CHAIN_SELECTOR, SOLANA_TOKEN_RECEIVER, address(mstrx), BRIDGE_AMOUNT, chainSpecificArgs
        );

        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
    }

    /// @dev Builds the merkle tree for the canonical Solana leaf, then submits a send with the given
    ///      (tampered) arguments and asserts it fails proof verification.
    function _assertSendFailsProofVerification(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        bytes memory chainSpecificArgs
    ) internal {
        _assertSendReverts(destinationChainSelector, tokenReceiver, token, chainSpecificArgs, false);
    }

    function _assertSendFailsDecoderValidation(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        bytes memory chainSpecificArgs
    ) internal {
        _assertSendReverts(destinationChainSelector, tokenReceiver, token, chainSpecificArgs, true);
    }

    function _assertSendReverts(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        bytes memory chainSpecificArgs,
        bool failsDecoderValidation
    ) internal {
        ManageLeaf[] memory leafs = _solanaLeafs();
        _assertCallWithLeafReverts(
            leafs, destinationChainSelector, tokenReceiver, token, chainSpecificArgs, failsDecoderValidation
        );
    }

    function _assertCallWithLeafReverts(
        ManageLeaf[] memory leafs,
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        bytes memory chainSpecificArgs,
        bool failsDecoderValidation
    ) internal {
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        bytes32[][] memory manageProofs = new bytes32[][](1);
        manageProofs[0] = _getProofsUsingTree(leafs, manageTree)[1];

        address[] memory targets = new address[](1);
        targets[0] = backedCCIPBridge;

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "send(uint64,bytes32,address,uint256,bytes)",
            destinationChainSelector,
            tokenReceiver,
            token,
            BRIDGE_AMOUNT,
            chainSpecificArgs
        );

        uint256[] memory values = new uint256[](1);
        values[0] = 0.001e18;

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        if (failsDecoderValidation) {
            vm.expectRevert(
                BackedCCIPDecoderAndSanitizer.BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs.selector
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                    targets[0],
                    targetData[0],
                    values[0]
                )
            );
        }
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    /// @dev An EVM leaf can only be called with empty chain-specific arguments.
    function _assertEvmSendFailsDecoderValidation(bytes memory chainSpecificArgs) internal {
        bytes32 receiver = bytes32(uint256(uint160(address(boringVault))));
        ManageLeaf[] memory leafs = _evmLeafs(ARBITRUM_CHAIN_SELECTOR, receiver);
        _assertCallWithLeafReverts(
            leafs,
            ARBITRUM_CHAIN_SELECTOR,
            receiver,
            address(mstrx),
            chainSpecificArgs,
            true
        );
    }

    /// @dev Reads the 20 byte pseudo address unit at `unitIndex` from packed decoder output.
    function _unit(bytes memory data, uint256 unitIndex) internal pure returns (bytes20 unit) {
        assembly {
            unit := mload(add(add(data, 32), mul(unitIndex, 20)))
        }
    }

    /// @dev Rebuilds a bytes32 from the two consecutive 16-bytes-in-20 units starting at `unitIndex`.
    ///      Also asserts the 4 trailing pad bytes of each half unit are zero, so a decoder packing
    ///      20 real value bytes per unit cannot slip past the fuzz oracle.
    function _reassembleBytes32(bytes memory data, uint256 unitIndex) internal pure returns (bytes32) {
        bytes20 hi = _unit(data, unitIndex);
        bytes20 lo = _unit(data, unitIndex + 1);
        require(uint160(hi) & 0xffffffff == 0 && uint160(lo) & 0xffffffff == 0, "half unit padding not zero");
        return bytes32(bytes16(hi)) | (bytes32(bytes16(lo)) >> 128);
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
