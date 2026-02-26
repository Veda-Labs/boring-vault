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
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract KatanaOVaultIntegrationTest is Test, MerkleTreeHelper {
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
    uint256 katanaFork = vm.createFork(vm.envString("KATANA_RPC_URL"));

    function setUp() external {
        setSourceChainName("katana");
        vm.selectFork(katanaFork);

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

        // setup roles authority
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

        // grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

        // allow the boring vault to receive eth
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function test__BridgeKatanaToEthereum() external {
        deal(getAddress(sourceChain, "vbUSDC"), address(boringVault), 1000e6);
        vm.deal(address(boringVault), 0.1 ether);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addKatanaOVaultLeafs(
            leafs,
            getAddress(sourceChain, "vbUSDC"),
            getAddress(sourceChain, "vbUSDCShareOFT"),
            getAddress("mainnet", "OVaultComposerForvbUSDC")
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        (DecoderCustomTypes.SendParam memory sendParam, uint256 nativeFee) = _buildSendParam();

        _executeBridge(leafs, manageTree, sendParam, nativeFee);

        uint256 balanceAfter = getERC20(sourceChain, "vbUSDC").balanceOf(address(boringVault));

        require(balanceAfter < 1000e6, "bridge did not work");
    }

    function _getExpectedAssets(uint256 sharesToBridge, uint256 slippageBps)
        internal
        returns (uint256 expectedAssets, uint256 minAssets)
    {
        vm.selectFork(ethereumFork);

        address vault = 0x53E82ABbb12638F09d9e624578ccB666217a765e;
        (bool ok, bytes memory data) =
            vault.staticcall(abi.encodeWithSignature("previewRedeem(uint256)", sharesToBridge));
        require(ok, "previewRedeem failed");
        expectedAssets = abi.decode(data, (uint256));
        minAssets = expectedAssets * (1e4 - slippageBps) / 1e4;

        vm.selectFork(katanaFork);
    }

    function _buildSendParam() internal returns (DecoderCustomTypes.SendParam memory sendParam, uint256 nativeFee) {
        uint256 sharesToBridge = 100e6;
        uint256 slippageBps = 50;
        address recipient = address(boringVault);

        (uint256 expectedAssets, uint256 minAssets) = _getExpectedAssets(sharesToBridge, slippageBps);

        // build compose message
        DecoderCustomTypes.SendParam memory secondHopSendParam = DecoderCustomTypes.SendParam({
            dstEid: 30101, // lz etherem eid
            to: bytes32(uint256(uint160(recipient))),
            amountLD: expectedAssets,
            minAmountLD: minAssets,
            extraOptions: addExecutorLzReceiveOption(abi.encodePacked(uint16(3)), 100_000, 0),
            composeMsg: hex"",
            oftCmd: hex""
        });

        bytes memory composeMsg = abi.encode(secondHopSendParam, uint256(0));

        // build layerzero options
        uint256 composeGas = 800_000;
        bytes memory extraOptions =
            addExecutorLzComposeOption(abi.encodePacked(uint16(3)), uint16(0), uint128(composeGas), uint128(0));

        // build first hop SendParams
        uint256 minSharesFirstHop = sharesToBridge * (1e4 - slippageBps) / 1e4;

        sendParam = DecoderCustomTypes.SendParam({
            dstEid: 30101,
            to: bytes32(uint256(uint160(getAddress("mainnet", "OVaultComposerForvbUSDC")))),
            amountLD: sharesToBridge,
            minAmountLD: minSharesFirstHop,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: hex""
        });

        // quote layerzero fee
        (nativeFee,) = _quoteOFTSend(getAddress(sourceChain, "vbUSDCShareOFT"), sendParam);
        // DecoderCustomTypes.MessagingFee memory messagingFee =
        //     DecoderCustomTypes.MessagingFee({nativeFee: nativeFee, lzTokenFee: 0});
        console.log("LZ native fee:", nativeFee);
    }

    function _executeBridge(
        ManageLeaf[] memory leafs,
        bytes32[][] memory manageTree,
        DecoderCustomTypes.SendParam memory sendParam,
        uint256 nativeFee
    ) internal {
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "vbUSDC");
        targets[1] = getAddress(sourceChain, "vbUSDCShareOFT");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "vbUSDCShareOFT"), sendParam.amountLD
        );
        targetData[1] = abi.encodeWithSignature(
            "send((uint32,bytes32,uint256,uint256,bytes,bytes,bytes),(uint256,uint256),address)",
            sendParam,
            DecoderCustomTypes.MessagingFee({nativeFee: nativeFee, lzTokenFee: 0}),
            address(boringVault)
        );

        uint256[] memory values = new uint256[](2);
        values[1] = nativeFee;

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    uint8 internal constant WORKER_ID = 1;
    uint16 internal constant TYPE_3 = 3;
    uint8 internal constant OPTION_TYPE_LZRECEIVE = 1;
    uint8 internal constant OPTION_TYPE_LZCOMPOSE = 3;

    error InvalidOptionType(uint16 optionType);

    function toU16(bytes calldata _bytes, uint256 _start) internal pure returns (uint16) {
        unchecked {
            uint256 end = _start + 2;
            return uint16(bytes2(_bytes[_start:end]));
        }
    }

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
        bytes memory option = encodeLzReceiveOption(_gas, _value);
        return addExecutorOption(_options, OPTION_TYPE_LZRECEIVE, option);
    }

    function addExecutorLzComposeOption(bytes memory _options, uint16 _index, uint128 _gas, uint128 _value)
        internal
        pure
        onlyType3(_options)
        returns (bytes memory)
    {
        bytes memory option = encodeLzComposeOption(_index, _gas, _value);
        return addExecutorOption(_options, OPTION_TYPE_LZCOMPOSE, option);
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
