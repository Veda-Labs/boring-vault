// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {TacUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacUSDDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, console} from "@forge-std/Test.sol";

/**
 * @title TacToEthereumBridgeIntegrationTest
 * @notice Integration test for the TAC → Ethereum bridge flow via the TAC
 *         CrossChainLayer → TON relayer path (reverse of the Ethereum → TON
 *         Tether Legacy Mesh bridge).
 *
 * Reference on-chain tx (TAC mainnet):
 *   https://explorer.tac.build/tx/0x77b72026aa444813a1a27e80fa8a9b8cac5132fe3fc04cde2432aca4630888cc
 *
 * Source tx calls `CrossChainLayer.sendMessage(uint256 messageVersion, bytes encodedMessage)`
 * (selector 0xe289adcd) on the proxy at 0x9fee01e948353E0897968A3ea955815aaA49f58d
 * with messageVersion = 1 and an ABI-encoded `OutMessageV1` struct containing:
 *   - shardsKey
 *   - tvmTarget (TON relayer address as base64url string)
 *   - tvmPayload
 *   - tvmProtocolFee / tvmExecutorFee (TAC native paid via msg.value)
 *   - tvmValidExecutors (array of TON executor addresses)
 *   - toBridge: TokenAmount[] — (USDT0, amount)
 *   - toBridgeNFT: empty
 *
 * On-chain effects: USDT0 is transferred from the caller to the CrossChainLayer
 * and then burned; the TON relayer observes the message and mints USDT on the
 * user's Ethereum address.
 */
contract TacToEthereumBridgeIntegrationTest is Test, MerkleTreeHelper {
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

    uint256 tacFork = vm.createFork(vm.envString("TAC_RPC_URL"));

    // TVM routing strings taken from the reference tx.
    string constant TVM_TARGET = "UQA9ziW3zZLDtgwfvR0rfKPmRQjdVKtRSNo8Ln0PBawi-0JA";
    string constant TVM_EXECUTOR = "EQB9Yo7kY7hlsVB6aei8ZkSpiI2OPC_kkbh5KAoUrKW04ZxW";

    function setUp() external {
        setSourceChainName("tacBuild");
        vm.selectFork(tacFork);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new TacUSDDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(
            MANAGER_ROLE, address(boringVault), bytes4(keccak256("manage(address,bytes,uint256)")), true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE, address(boringVault), bytes4(keccak256("manage(address[],bytes[],uint256[])")), true
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

        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function test__BridgeTacToEthereum() external {
        address usdt0 = getAddress(sourceChain, "USDT0");
        address crossChainLayer = getAddress(sourceChain, "CrossChainLayer");

        uint256 amountToBridge = 1_069_026; // 1.069026 USDT0 (6 dp) — matches reference tx
        uint256 initialUsdt0 = 10_000_000; // 10 USDT0

        deal(usdt0, address(boringVault), initialUsdt0);
        vm.deal(address(boringVault), 100 ether); // plenty of native TAC for fees

        // ── Build Merkle leafs ───────────────────────────────────────────────
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addTacToTvmLeafs(leafs, usdt0, crossChainLayer, TVM_TARGET);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // ── Build the OutMessageV1 struct matching the reference tx ─────────
        DecoderCustomTypes.TokenAmount[] memory toBridge = new DecoderCustomTypes.TokenAmount[](1);
        toBridge[0] = DecoderCustomTypes.TokenAmount({evmAddress: usdt0, amount: amountToBridge});

        string[] memory validExecutors = new string[](1);
        validExecutors[0] = TVM_EXECUTOR;

        DecoderCustomTypes.OutMessageV1 memory outMsg = DecoderCustomTypes.OutMessageV1({
            shardsKey: 154629181562361600, // 0x02245427b0a18700 from reference tx
            tvmTarget: TVM_TARGET,
            tvmPayload: "",
            tvmProtocolFee: 2e18, // 2 TAC — matches reference
            tvmExecutorFee: 58.02e18, // ~58 TAC — matches reference closely
            tvmValidExecutors: validExecutors,
            toBridge: toBridge,
            toBridgeNFT: new DecoderCustomTypes.NFTAmount[](0)
        });

        bytes memory encodedMessage = abi.encode(outMsg);
        uint256 nativeValue = outMsg.tvmProtocolFee + outMsg.tvmExecutorFee;

        // ── Execute through the BoringVault manager ─────────────────────────
        _executeBridge(leafs, manageTree, usdt0, crossChainLayer, amountToBridge, encodedMessage, nativeValue);

        uint256 balanceAfter = ERC20(usdt0).balanceOf(address(boringVault));
        console.log("vault USDT0 balance after bridge:", balanceAfter);
        require(balanceAfter <= initialUsdt0 - amountToBridge, "bridge did not move USDT0");
    }

    function _executeBridge(
        ManageLeaf[] memory leafs,
        bytes32[][] memory manageTree,
        address usdt0,
        address crossChainLayer,
        uint256 amountToBridge,
        bytes memory encodedMessage,
        uint256 nativeValue
    ) internal {
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = usdt0;
        targets[1] = crossChainLayer;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", crossChainLayer, amountToBridge);
        targetData[1] = abi.encodeWithSignature("sendMessage(uint256,bytes)", uint256(1), encodedMessage);

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = nativeValue;

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }
}
