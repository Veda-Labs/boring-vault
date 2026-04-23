// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {SyUsdDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SyUsdDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract BridgeUsdtFromTacToEthereumScript is Script, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 private privateKey;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    address public rawDataDecoderAndSanitizerTacBuild = 0x0d24946Ba0a37D5e1d269Bb207286169fF5a3dbc;
    RolesAuthority internal rolesAuthority = RolesAuthority(0x1B77bB2d878d3CE1C55D5621CFFDF0C6ce62BB63);
    BoringVault internal boringVault = BoringVault(payable(0x2A9001e73811aEBad909aB14e453Fd0A91d7A31a));
    LayerZeroTeller internal teller = LayerZeroTeller(0x90F9101416b1eCF7297C918Aaf775E6EE6A77760);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x529DE000e4AdAA243aB42b83D2563E2E7A3B182e);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x4C937c0D0b6660a1F72263220c934F23d864495d);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0x67b1faa35e51fAE48e3f035cDAE6601B1CDeFB2D);
    BoringSolver internal solver = BoringSolver(0xbF3A130838C76Dd4Ec864d84BB4Df2DFb0D41CF3);

    function setUp() external {
        privateKey = vm.envUint("STRATEGIST");
        vm.createSelectFork("tacBuild");
        setSourceChainName("tacBuild");

        setAddress(true, tacBuild, "boringVault", address(boringVault));
        setAddress(true, tacBuild, "managerAddress", address(manager));
        setAddress(true, tacBuild, "manager", address(manager));
        setAddress(true, tacBuild, "accountantAddress", address(accountant));
        setAddress(true, tacBuild, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizerTacBuild);
    }

    function _addLeafs(ManageLeaf[] memory leafs) internal {
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDT0");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        string memory tvmTarget = "EQDPm7903CIxkWSUbzFrOSGEPnYUaHfJH4GO-diSHW-0_k1r";
        _addTacToTvmLeafs(
            leafs, getAddress(sourceChain, "USDT0"), getAddress(sourceChain, "CrossChainLayer"), tvmTarget
        );
    }

    function run() external {
        uint256 amountToBridge = 1.1e6;
        string memory tvmTarget = "EQDPm7903CIxkWSUbzFrOSGEPnYUaHfJH4GO-diSHW-0_k1r";
        string memory tvmExecutor = "EQB9Yo7kY7hlsVB6aei8ZkSpiI2OPC_kkbh5KAoUrKW04ZxW";
        // string memory tvmExecutor = "EQC2g0rkJP6wXNjZspGDZCBoBPXaGNsq4CPGK8PvX9nuXNFI";

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        _addLeafs(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        ManageLeaf[] memory used = new ManageLeaf[](2);
        used[0] = leafs[3];
        used[1] = leafs[4];
        bytes32[][] memory proofs = _getProofsUsingTree(used, manageTree);

        DecoderCustomTypes.TokenAmount[] memory toBridge = new DecoderCustomTypes.TokenAmount[](1);
        toBridge[0] =
            DecoderCustomTypes.TokenAmount({evmAddress: getAddress(tacBuild, "USDT0"), amount: amountToBridge});
        string[] memory validExecutors = new string[](1);
        validExecutors[0] = tvmExecutor;

        DecoderCustomTypes.OutMessageV1 memory outMsg = DecoderCustomTypes.OutMessageV1({
            shardsKey: uint64(uint256(keccak256(abi.encode(block.timestamp, amountToBridge)))),
            tvmTarget: tvmTarget,
            tvmPayload: "",
            tvmProtocolFee: 2e18,
            tvmExecutorFee: 60e18,
            tvmValidExecutors: validExecutors,
            toBridge: toBridge,
            toBridgeNFT: new DecoderCustomTypes.NFTAmount[](0)
        });

        address usdt0 = getAddress(tacBuild, "USDT0");
        address ccl = getAddress(tacBuild, "CrossChainLayer");

        address[] memory targets = new address[](2);
        targets[0] = usdt0;
        targets[1] = ccl;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", ccl, amountToBridge);
        targetData[1] = abi.encodeWithSignature("sendMessage(uint256,bytes)", uint256(1), abi.encode(outMsg));

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = outMsg.tvmProtocolFee + outMsg.tvmExecutorFee;

        address[] memory decoders = new address[](2);
        decoders[0] = rawDataDecoderAndSanitizerTacBuild;
        decoders[1] = rawDataDecoderAndSanitizerTacBuild;

        vm.startBroadcast(privateKey);
        manager.manageVaultWithMerkleVerification(proofs, decoders, targets, targetData, values);
        vm.stopBroadcast();
    }
}
