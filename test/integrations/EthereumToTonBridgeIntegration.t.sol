// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BridgingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {SyUsdtEthereumDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdtEthereumDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, console} from "@forge-std/Test.sol";

/**
 * @title EthereumToTonBridgeIntegrationTest
 * @notice Integration test for the Ethereum → TON USDT bridge flow as used by
 *         Tether's Legacy Mesh / USDT0 (USDT is escrowed on Ethereum via the
 *         USDT→TON OFT adapter, received by a TON relayer, which then mints
 *         USDT0 on the user's EVM address on TAC).
 *
 * Reference on-chain tx (Ethereum mainnet):
 *   https://layerzeroscan.com/tx/0x2db99ed86ca3ae5f2668a83d96d3cbaefcd55edeaa75a8438e721fb98820990f
 *
 * Source tx calls LayerZero's `LZMultiCall.execute((Call[]),bytes32)` at
 *   0xAcdDAC6C77318B615f7F6fB9bb67c6833e9c05f1
 * with four inner calls:
 *   [0] TransferHelper.delegateTransferFrom(USDT, user, LZMultiCall, amount)
 *   [1] USDT.approve(TON_OFT_ADAPTER, amount)
 *   [2] TON_OFT_ADAPTER.send(SendParam, MessagingFee, refund) { value: nativeFee }
 *   [3] LZMultiCall.sweep([USDT, 0x0], user)
 *
 * The BoringVault pre-approves LZMultiCall to spend USDT (so Call[0]'s
 * transferFrom works when LZMultiCall is msg.sender via the TransferHelper).
 */
contract EthereumToTonBridgeIntegrationTest is Test, MerkleTreeHelper {
    using SafeCast for uint256;
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

    uint256 ethereumFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));

    address constant USDT_MAINNET = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant LZ_MULTICALL = 0xAcdDAC6C77318B615f7F6fB9bb67c6833e9c05f1;
    address constant LZ_TRANSFER_HELPER = 0x72fAEbF58A62e33C044c37D8D973a961633ea294;
    address constant TON_OFT_ADAPTER = 0x1F748c76dE468e9D11bd340fA9D5CBADf315dFB0;

    uint32 constant LZ_EID_TON = 30343;

    // bytes32 constant TON_RELAYER = 0x3dce25b7cd92c3b60c1fbd1d2b7ca3e64508dd54ab5148da3c2e7d0f05ac22fb;
    bytes32 constant TON_RELAYER = 0x28b190f3f209e085d279f90c4898c3fa9c6792d0ef0ab1ed941277c3d906a33a;

    // The quoteId pinned by LZMultiCall. The 2-arg execute overload does not
    // verify signatures, so this is informational for reproduction.
    bytes32 constant QUOTE_ID = 0x00000000000000000000000000000000019db5f5bd5472cb95798761f9eda6fa;

    bytes4 constant SEL_DELEGATE_TRANSFER_FROM = 0xeac6f3fe; // delegateTransferFrom(address,address,address,uint256)
    bytes4 constant SEL_SWEEP = 0xd20c88bd; // sweep(address[],address)

    // ────────────────────────────────────────────────────────────────────────
    //  setUp
    // ────────────────────────────────────────────────────────────────────────
    function setUp() external {
        setSourceChainName("mainnet");
        vm.selectFork(ethereumFork);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(
            address(this),
            address(boringVault),
            getAddress(sourceChain, "vault") // Balancer vault (flash-loan role)
        );

        rawDataDecoderAndSanitizer =
            address(new SyUsdtEthereumDecoderAndSanitizer(getAddress(sourceChain, "magpieRouterV3")));

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

    function test__BridgeEthereumToTon() external {
        uint256 initialUsdt = 1_000e6;
        uint256 amountToBridge = 100e6;

        deal(USDT_MAINNET, address(boringVault), initialUsdt);
        vm.deal(address(boringVault), 0.5 ether);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addEthereumToTonViaLZMultiCallLeafs(
            leafs, USDT_MAINNET, LZ_MULTICALL, LZ_TRANSFER_HELPER, TON_OFT_ADAPTER, TON_RELAYER
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        uint256 slippageBps = 50;
        uint256 minAmount = (amountToBridge * (1e4 - slippageBps)) / 1e4;

        DecoderCustomTypes.SendParam memory sendParam = DecoderCustomTypes.SendParam({
            dstEid: LZ_EID_TON,
            to: TON_RELAYER,
            amountLD: amountToBridge,
            minAmountLD: minAmount,
            extraOptions: hex"0003",
            composeMsg: hex"",
            oftCmd: hex""
        });

        (uint256 nativeFee,) = _quoteOFTSend(TON_OFT_ADAPTER, sendParam);
        console.log("LZ native fee (wei):", nativeFee);

        DecoderCustomTypes.MessagingFee memory fee =
            DecoderCustomTypes.MessagingFee({nativeFee: nativeFee, lzTokenFee: 0});

        DecoderCustomTypes.LZCall[] memory calls = new DecoderCustomTypes.LZCall[](4);

        calls[0] = DecoderCustomTypes.LZCall({
            target: LZ_TRANSFER_HELPER,
            value: 0,
            data: abi.encodeWithSelector(
                SEL_DELEGATE_TRANSFER_FROM, USDT_MAINNET, address(boringVault), LZ_MULTICALL, amountToBridge
            )
        });

        calls[1] = DecoderCustomTypes.LZCall({
            target: USDT_MAINNET,
            value: 0,
            data: abi.encodeWithSignature("approve(address,uint256)", TON_OFT_ADAPTER, amountToBridge)
        });

        calls[2] = DecoderCustomTypes.LZCall({
            target: TON_OFT_ADAPTER,
            value: nativeFee,
            data: abi.encodeWithSignature(
                "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
                sendParam,
                fee,
                LZ_MULTICALL
            )
        });

        address[] memory sweepTokens = new address[](2);
        sweepTokens[0] = USDT_MAINNET;
        sweepTokens[1] = address(0); // native ETH
        calls[3] = DecoderCustomTypes.LZCall({
            target: LZ_MULTICALL, value: 0, data: abi.encodeWithSelector(SEL_SWEEP, sweepTokens, address(boringVault))
        });

        _executeBridge(leafs, manageTree, calls, nativeFee, amountToBridge);

        uint256 balanceAfter = ERC20(USDT_MAINNET).balanceOf(address(boringVault));
        console.log("vault USDT balance after bridge:", balanceAfter);
        require(balanceAfter <= initialUsdt - amountToBridge, "bridge did not move USDT");
    }

    function _executeBridge(
        ManageLeaf[] memory leafs,
        bytes32[][] memory manageTree,
        DecoderCustomTypes.LZCall[] memory calls,
        uint256 nativeFee,
        uint256 amountToBridge
    ) internal {
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = USDT_MAINNET;
        targets[1] = LZ_MULTICALL;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", LZ_TRANSFER_HELPER, amountToBridge);
        targetData[1] = abi.encodeWithSignature("execute((address,uint256,bytes)[],bytes32)", calls, QUOTE_ID);

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = nativeFee;

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function _quoteOFTSend(address oft, DecoderCustomTypes.SendParam memory sendParam)
        internal
        view
        returns (uint256 nativeFee, uint256 lzTokenFee)
    {
        (bool ok, bytes memory data) = oft.staticcall(
            abi.encodeWithSignature(
                "quoteSend((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),bool)", sendParam, false
            )
        );
        require(ok, "quoteSend failed");
        (nativeFee, lzTokenFee) = abi.decode(data, (uint256, uint256));
    }
}
