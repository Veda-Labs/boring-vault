// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {BridgingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
// import {
//     EthereumUsdStrategyDecoderAndSanitizer
// } from "src/base/DecoderAndSanitizers/EthereumUsdStrategyDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

/**
 * @title  KatanaOVaultIntegrationTest
 * @notice Integration test for the Ethereum → Katana OVault bridge flow via LayerZero.
 *
 * Key contracts (Ethereum Mainnet):
 *   USDC             0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
 *   OVault Composer  0x8A35897fda9E024d2aC20a937193e099679eC477
 *   USDC Vault Bridge (vbUSDC ERC-4626) 0x53E82ABbb12638F09d9e624578ccB666217a765e
 *   Share OFT Adapter (used for quoteSend) 0xb5bADA33542a05395d504a25885e02503A957Bb3
 *
 * Key contracts (Katana):
 *   vbUSDC (Share OFT) 0x807275727Dd3E640c5F2b5DE7d1eC72B4Dd293C0
 *
 * LayerZero EIDs:
 *   Ethereum  30101
 *   Katana    30375
 *
 * Flow (2 txns on Ethereum):
 *   1. approve(USDC, OVaultComposer, amount)
 *   2. OVaultComposer.depositAndSend(amount, sendParam, refundAddress) + { value: nativeFee }
 *      └─ Composer deposits USDC → vbUSDC ERC-4626 vault
 *      └─ Bridges minted shares to Katana recipient via LZ OFT
 */
contract KatanaOVaultIntegrationTest is Test, MerkleTreeHelper {
    using SafeCast for uint256;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    // ─── Contracts under test ───────────────────────────────────────────────
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    // ─── Role constants ──────────────────────────────────────────────────────
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    // ─── Forks ───────────────────────────────────────────────────────────────
    uint256 ethereumFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
    uint256 katanaFork = vm.createFork(vm.envString("KATANA_RPC_URL"));

    // ─── Ethereum Mainnet addresses ──────────────────────────────────────────
    // Source: https://docs.katana.network/katana/how-to/bridge-to-katana-with-layerzero/
    address constant USDC_MAINNET = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant OVAULT_COMPOSER = 0x8A35897fda9E024d2aC20a937193e099679eC477;
    address constant VBUSDC_VAULT_BRIDGE = 0x53E82ABbb12638F09d9e624578ccB666217a765e; // ERC-4626 vault
    address constant SHARE_OFT_ADAPTER = 0xb5bADA33542a05395d504a25885e02503A957Bb3; // used for quoteSend

    // ─── Katana addresses ────────────────────────────────────────────────────
    // Source: https://docs.katana.network/katana/technical-reference/contract-addresses/
    address constant VBUSDC_KATANA = 0x807275727Dd3E640c5F2b5DE7d1eC72B4Dd293C0; // Share OFT on Katana

    // ─── LayerZero EIDs ──────────────────────────────────────────────────────
    uint32 constant LZ_EID_KATANA = 30375;

    // ─── LZ Options constants ────────────────────────────────────────────────
    uint8 internal constant WORKER_ID = 1;
    uint16 internal constant TYPE_3 = 3;
    uint8 internal constant OPTION_TYPE_LZRECEIVE = 1;
    uint8 internal constant OPTION_TYPE_LZCOMPOSE = 3;

    error InvalidOptionType(uint16 optionType);

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
            getAddress(sourceChain, "vault") // Balancer vault for flash-loan role
        );

        // rawDataDecoderAndSanitizer = address(new BridgingDecoderAndSanitizer());
        rawDataDecoderAndSanitizer = address(0xA6f838C875EA8c0BB7B342556fc9Ec816166d566);

        // Register addresses in the MerkleTreeHelper address book
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(manager));

        setAddress(false, sourceChain, "OVaultComposer", OVAULT_COMPOSER);
        setAddress(false, sourceChain, "ShareOFTAdapter", SHARE_OFT_ADAPTER);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // ── Capabilities ────────────────────────────────────────────────────
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

        // ── Role assignments ─────────────────────────────────────────────────
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

        // Allow the vault to receive ETH (for LZ fee payment)
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    // ────────────────────────────────────────────────────────────────────────
    //  test__BridgeEthereumToKatana
    // ────────────────────────────────────────────────────────────────────────
    function test__BridgeEthereumToKatana() external {
        // Fund the vault with USDC and enough ETH to cover the LZ fee
        deal(USDC_MAINNET, address(boringVault), 1000e6);
        vm.deal(address(boringVault), 0.1 ether);

        // ── Build Merkle leafs (index starts at -1; helpers pre-increment) ──
        // FIX: leafIndex must be reset to type(uint256).max so that the first
        //      unchecked{ leafIndex++ } wraps to 0, matching leafs[0].

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addEthereumOVaultLeafsForDepositAndSend(leafs, USDC_MAINNET, OVAULT_COMPOSER);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // ── Build the sendParam and quote the LZ fee ─────────────────────────
        (DecoderCustomTypes.SendParam memory sendParam, uint256 nativeFee, uint256 amountToDeposit) = _buildSendParam();

        // ── Execute approve + depositAndSend through the BoringVault ─────────
        _executeBridge(leafs, manageTree, sendParam, nativeFee, amountToDeposit);

        uint256 balanceAfter = getERC20(sourceChain, "USDC").balanceOf(address(boringVault));

        console.log("balance after bridge:", balanceAfter);
        require(balanceAfter < 1000e6, "bridge did not work");
    }

    // ────────────────────────────────────────────────────────────────────────
    //  _buildSendParam
    //  FIX 1: quoteSend is called on the ShareOFTAdapter, not USDCOFTAdapter.
    //  FIX 2: SendParam.amountLD = expectedShares (shares to bridge), which is
    //          correct — but we must make sure amountToDeposit stays as raw USDC.
    // ────────────────────────────────────────────────────────────────────────
    function _buildSendParam()
        internal
        returns (DecoderCustomTypes.SendParam memory sendParam, uint256 nativeFee, uint256 amountToDeposit)
    {
        amountToDeposit = 100e6; // 100 USDC (6 decimals)
        uint256 slippageBps = 50; // 0.5 %
        address recipient = address(boringVault);

        // Preview how many vault shares we will receive for amountToDeposit USDC
        (uint256 expectedShares, uint256 minShares) = _previewVaultDeposit(amountToDeposit, slippageBps);

        console.log("amountToDeposit (USDC 6dp):", amountToDeposit);
        console.log("expectedShares:", expectedShares);
        console.log("minShares:", minShares);

        // Build the OFT SendParam — this describes the share transfer on Katana
        sendParam = DecoderCustomTypes.SendParam({
            dstEid: LZ_EID_KATANA,
            to: bytes32(uint256(uint160(OVAULT_COMPOSER))),
            amountLD: expectedShares, // shares to bridge
            minAmountLD: minShares, // slippage floor
            extraOptions: addExecutorLzReceiveOption(
                abi.encodePacked(uint16(3)), // TYPE_3 prefix
                100_000, // gas on destination
                0 // no extra ETH drop
            ),
            composeMsg: hex"",
            oftCmd: hex""
        });

        // FIX: quote against the Share OFT Adapter (bridges vbUSDC shares),
        //      NOT the USDC OFT adapter.
        (nativeFee,) = _quoteOFTSend(SHARE_OFT_ADAPTER, sendParam);
        console.log("LZ native fee (wei):", nativeFee);
    }

    // ────────────────────────────────────────────────────────────────────────
    //  _previewVaultDeposit
    //  Switched from ethereumFork re-selection to staying on current fork.
    //  Uses the official vbUSDC ERC-4626 vault address.
    // ────────────────────────────────────────────────────────────────────────
    function _previewVaultDeposit(uint256 assetsToDeposit, uint256 slippageBps)
        internal
        view
        returns (uint256 expectedShares, uint256 minShares)
    {
        (bool ok, bytes memory data) =
            VBUSDC_VAULT_BRIDGE.staticcall(abi.encodeWithSignature("previewDeposit(uint256)", assetsToDeposit));
        require(ok, "previewDeposit failed");
        expectedShares = abi.decode(data, (uint256));
        minShares = (expectedShares * (1e4 - slippageBps)) / 1e4;
    }

    // ────────────────────────────────────────────────────────────────────────
    //  _executeBridge — submits the two-step manage call through the vault
    // ────────────────────────────────────────────────────────────────────────
    function _executeBridge(
        ManageLeaf[] memory leafs,
        bytes32[][] memory manageTree,
        DecoderCustomTypes.SendParam memory sendParam,
        uint256 nativeFee,
        uint256 amountToDeposit
    ) internal {
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; // approve
        manageLeafs[1] = leafs[1]; // depositAndSend

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = USDC_MAINNET;
        targets[1] = OVAULT_COMPOSER;

        bytes[] memory targetData = new bytes[](2);

        // TX 1: approve OVaultComposer to spend USDC
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", OVAULT_COMPOSER, amountToDeposit);

        // TX 2: deposit USDC into vault and bridge shares to Katana
        // FIX: first argument is the raw USDC amount (amountToDeposit),
        //      not expectedShares. The composer handles the vault deposit internally.
        //      Third argument is the refund address for excess ETH.
        targetData[1] = abi.encodeWithSignature(
            "depositAndSend(uint256,(uint32,bytes32,uint256,uint256,bytes,bytes,bytes),address)",
            amountToDeposit, // raw USDC to deposit
            sendParam, // OFT send parameters (shares + LZ routing)
            address(boringVault) // refund address
        );

        uint256[] memory values = new uint256[](2);
        values[0] = 0; // approve is not payable
        values[1] = nativeFee; // ETH forwarded for LZ fee

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ────────────────────────────────────────────────────────────────────────
    //  LZ Options helpers
    // ────────────────────────────────────────────────────────────────────────

    function toUint16(bytes memory _bytes, uint256 _start) internal pure returns (uint16) {
        require(_bytes.length >= _start + 2, "toUint16_outOfBounds");
        uint16 tempUint;
        assembly {
            tempUint := mload(add(add(_bytes, 0x2), _start))
        }
        return tempUint;
    }

    modifier onlyType3(bytes memory _options) {
        if (toUint16(_options, 0) != TYPE_3) revert InvalidOptionType(toUint16(_options, 0));
        _;
    }

    function addExecutorOption(bytes memory _options, uint8 _optionType, bytes memory _option)
        internal
        pure
        onlyType3(_options)
        returns (bytes memory)
    {
        return abi.encodePacked(_options, WORKER_ID, _option.length.toUint16() + 1, _optionType, _option);
    }

    function encodeLzReceiveOption(uint128 _gas, uint128 _value) internal pure returns (bytes memory) {
        return _value == 0 ? abi.encodePacked(_gas) : abi.encodePacked(_gas, _value);
    }

    function encodeLzComposeOption(uint16 _index, uint128 _gas, uint128 _value) internal pure returns (bytes memory) {
        return _value == 0 ? abi.encodePacked(_index, _gas) : abi.encodePacked(_index, _gas, _value);
    }

    function addExecutorLzReceiveOption(bytes memory _options, uint128 _gas, uint128 _value)
        internal
        pure
        onlyType3(_options)
        returns (bytes memory)
    {
        return addExecutorOption(_options, OPTION_TYPE_LZRECEIVE, encodeLzReceiveOption(_gas, _value));
    }

    function addExecutorLzComposeOption(bytes memory _options, uint16 _index, uint128 _gas, uint128 _value)
        internal
        pure
        onlyType3(_options)
        returns (bytes memory)
    {
        return addExecutorOption(_options, OPTION_TYPE_LZCOMPOSE, encodeLzComposeOption(_index, _gas, _value));
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
