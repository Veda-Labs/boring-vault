// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, stdStorage, StdStorage, stdError, console, Vm} from "../../lib/forge-std/src/Test.sol";
import {BoringVault, Auth} from "../../src/base/BoringVault.sol";
import {LayerZeroTeller} from "../../src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "../../src/base/Roles/AccountantWithRateProviders.sol";
import {ManagerWithMerkleVerification} from "../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {
    ChainlinkCCIPTeller,
    CrossChainTellerWithGenericBridge
} from "../../src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {Deployer} from "../../src/helper/Deployer.sol";
import {Pauser} from "../../src/base/Roles/Pauser.sol";
import {SafeTransferLib} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {IRateProvider} from "../../src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "../../lib/solmate/src/auth/authorities/RolesAuthority.sol";
import {MockLayerZeroEndPoint} from "../../src/helper/MockLayerZeroEndPoint.sol";
import {TellerWithMultiAssetSupport} from "../../src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "../../src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "../../src/base/Roles/BoringQueue/BoringSolver.sol";
import {GenericRateProvider} from "../../src/helper/GenericRateProvider.sol";
import {MerkleTreeHelper} from "../../test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AddressToBytes32Lib} from "../../src/helper/AddressToBytes32Lib.sol";
import {
    EtherFiLiquidDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer
} from "../../src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";

import {DecoderCustomTypes} from "../../src/interfaces/DecoderCustomTypes.sol";
import {console} from "../../lib/forge-std/src/Test.sol";
// struct ManageLeaf {
//     address target;
//     bool canSendValue;
//     string signature;
//     address[] argumentAddresses;
//     string description;
//     address decoderAndSanitizer;
// }

contract Univ3IntegTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;

    ERC20 public USDC;
    ERC20 public WETH;
    address public owner;
    address user01 = makeAddr("user01");
    address user02 = makeAddr("user02");
    RolesAuthority internal rolesAuthority = RolesAuthority(0xcd5E9EBC1E35f20Af809E9668810c55cCc15b28E);
    BoringVault internal boringVault = BoringVault(payable(0x7135CA5F74BC85a65EA1705C9461fF1A24e7F1b9));
    LayerZeroTeller internal teller = LayerZeroTeller(0xDD1ac7F702CD5dc91Dc841EBf7AEba8A2Ba00628);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x940fA048ee64e5845e8c2F320146A926AA0a8F43);
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0xd0E254df4387B9aD31a59eFBBf66db9f809BD91E);
    BoringOnChainQueue internal queue = BoringOnChainQueue(0x42cd69153758B1Fc055102136aB07BE8D37E6297);
    BoringSolver internal solver = BoringSolver(0xD08Fb6ad3413390331D56a5cCbF06Eeb2e7b0017);
    Deployer internal deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);
    Pauser internal pauser = Pauser(0x93856A90bCb1055C9FF5f806e4B6B162d2d01d54);
    address public rawDataDecoderAndSanitizer;
    address public uniswapV3NonFungiblePositionManager;

    /// roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant MANAGER_INTERNAL_ROLE = 4;
    uint8 public constant PAUSER_ROLE = 5;
    uint8 public constant SOLVER_ROLE = 12;
    uint8 public constant OWNER_ROLE = 8;
    uint8 public constant MULTISIG_ROLE = 9;
    uint8 public constant STRATEGIST_MULTISIG_ROLE = 10;
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 11;
    uint8 public constant GENERIC_PAUSER_ROLE = 14;
    uint8 public constant GENERIC_UNPAUSER_ROLE = 15;
    uint8 public constant PAUSE_ALL_ROLE = 16;
    uint8 public constant UNPAUSE_ALL_ROLE = 17;
    uint8 public constant SENDER_PAUSER_ROLE = 18;
    uint8 public constant SENDER_UNPAUSER_ROLE = 19;
    uint8 public constant CAN_SOLVE_ROLE = 31;
    uint8 public constant ONLY_QUEUE_ROLE = 32;
    uint8 public constant SOLVER_ORIGIN_ROLE = 33;

    struct DepositAsset {
        ERC20 asset;
        bool isPeggedToBase;
        address rateProvider;
        string genericRateProviderName;
        address target;
        bytes4 selector;
        bytes32[8] params;
    }

    struct AddressOrName {
        address address_;
        string name;
    }

    struct WithdrawAsset {
        AddressOrName addressOrName;
        uint16 maxDiscount;
        uint16 minDiscount;
        uint24 minimumSecondsToDeadline;
        uint96 minimumShares;
        uint24 secondsToMaturity;
    }

    DepositAsset[] public depositAssets;
    WithdrawAsset[] public withdrawAssets;

    function setUp() external {
        setSourceChainName("arbitrum");
        vm.createSelectFork(sourceChain);
        owner = 0x1b514df3413DA9931eB31f2Ab72e32c0A507Cad5;
        USDC = getERC20(sourceChain, "USDC");
        WETH = getERC20(sourceChain, "WETH");

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidDecoderAndSanitizer(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"))
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(accountant));
    }

    // One Inch Integration
    function test__univ3Integ() public {
        // give roles

        vm.startPrank(rolesAuthority.owner());
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(manager), manager.manageVaultWithMerkleVerification.selector, true
        );
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        vm.stopPrank();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_00e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_00e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        _addUniswapV3Leafs(leafs, token0, token1, false, false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        vm.prank(manager.owner());
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        for (uint256 i = 0; i < 32; i++) {
            console.log(leafs[i].description);
        }

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[2]; // Approve position manager to spend weth
        manageLeafs[1] = leafs[3]; // Approve position manager to spend usdc
        manageLeafs[2] = leafs[4]; // Call mint on the position manager

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "USDC");
        targets[2] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
        // targets[3] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
        // targets[4] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
        // targets[5] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");
        // targets[6] = getAddress(sourceChain, "uniswapV3NonFungiblePositionManager");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
            type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
            type(uint256).max
        );

        DecoderCustomTypes.MintParams memory mintParams = DecoderCustomTypes.MintParams(
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "USDC"),
            uint24(500),
            int24(-193010), // lower tick
            int24(-191660), // upper tick
            1e18,
            1000e6,
            0,
            0,
            address(boringVault),
            block.timestamp
        );

        targetData[2] = abi.encodeWithSignature(
            "mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams
        );
        // uint256 expectedTokenId = 719588;
        // DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
        //     DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        // targetData[5] = abi.encodeWithSignature(
        //     "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        // );
        // uint128 expectedLiquidity = 14916033704815587156930 + 14916033704815587156930;
        // DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
        //     DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        // targetData[6] = abi.encodeWithSignature(
        //     "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        // );

        // DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
        //     expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        // );
        // targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
        // targetData[8] = abi.encodeWithSignature("burn(uint256)", expectedTokenId);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](3)
        );
    }
}
