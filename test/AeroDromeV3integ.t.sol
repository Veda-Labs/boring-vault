// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, stdStorage, StdStorage, stdError, console, Vm} from "@forge-std/Test.sol";
import {BoringVault, Auth} from "src/base/BoringVault.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {
    ChainlinkCCIPTeller,
    CrossChainTellerWithGenericBridge
} from "src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {Pauser} from "src/base/Roles/Pauser.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MockLayerZeroEndPoint} from "src/helper/MockLayerZeroEndPoint.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {
    EtherFiLiquidDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {
    AerodromeDecoderAndSanitizer,
    VelodromeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/AerodromeDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

// struct ManageLeaf {
//     address target;
//     bool canSendValue;
//     string signature;
//     address[] argumentAddresses;
//     string description;
//     address decoderAndSanitizer;
// }

contract AeroV3IntegTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;

    ERC20 public USDC;
    ERC20 public WETH;
    address public owner;
    address user01 = makeAddr("user01");
    address user02 = makeAddr("user02");

    BoringOnChainQueue internal queue = BoringOnChainQueue(0x89C281ea01dCB992E2e40AE01D0CFF3f428723a3);
    BoringSolver internal solver = BoringSolver(0x352C06BCf83fb614c7cB6FA4D0891F03EF01532F);

    LayerZeroTeller internal teller = LayerZeroTeller(0xC586C775bcc2Fa5f787Ef288B333af9Ea332BAAe);
    RolesAuthority internal rolesAuthority = RolesAuthority(0x24f7B70331bCeddb1bd5000b61941582cf3f15A8);
    BoringVault internal boringVault = BoringVault(payable(0x8645756d4DF86Ff81419Bd50B936774452bbF313));
    AccountantWithRateProviders internal accountant =
        AccountantWithRateProviders(0x49C1df396FfeD48d821A425beFc1C021Af0D43fE);
    ManagerWithMerkleVerification internal manager =
        ManagerWithMerkleVerification(0x540511A761Aaa6E009748e3eD77b3053ABe52280);
    Deployer internal deployer = Deployer(0x5BD97A73333B6EC2e38B687bcED159566A14C5BA);
    Pauser internal pauser = Pauser(0x90dD03eab8b32e76094fcDb2e0f2CE444246e966);
    address public rawDataDecoderAndSanitizer;
    address public uniswapV3NonFungiblePositionManager;

    /// roles
    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

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
        setSourceChainName("base");
        string memory rpcKey = "BASE_RPC_URL";
        uint256 blockNumber = 39019331;

        _startFork(rpcKey, blockNumber);
        owner = 0x3Dd95962fC01EcEC5f867189A929d036D5aC12A6;
        USDC = getERC20(sourceChain, "USDC");
        WETH = getERC20(sourceChain, "WETH");

        rawDataDecoderAndSanitizer =
            address(new AerodromeDecoderAndSanitizer(getAddress(sourceChain, "aerodromeNonFungiblePositionManager")));

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

        // Grant roles
        rolesAuthority.setUserRole(address(owner), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(owner), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
        vm.stopPrank();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);

        vm.startBroadcast(owner);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory gauges = new address[](1);
        gauges[0] = getAddress(sourceChain, "aerodrome_Weth_Usdc_v3_1_gauge");
        _addVelodromeV3Leafs(
            leafs, token0, token1, getAddress(sourceChain, "aerodromeNonFungiblePositionManager"), gauges
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(owner), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        // manageLeafs[3] = leafs[3];
        // manageLeafs[4] = leafs[4];
        // manageLeafs[5] = leafs[8];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = getAddress(sourceChain, "USDC");
        targets[2] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        // targets[3] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        // targets[4] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        // targets[5] = gauges[0];
        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "aerodromeNonFungiblePositionManager"),
            type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)",
            getAddress(sourceChain, "aerodromeNonFungiblePositionManager"),
            type(uint256).max
        );

        DecoderCustomTypes.VelodromeMintParams memory mintParams = DecoderCustomTypes.VelodromeMintParams(
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "USDC"),
            int24(1),
            int24(-195563), // lower tick
            int24(-195463), // upper tick
            500e18,
            500e18,
            0,
            0,
            address(boringVault),
            block.timestamp,
            0
        );
        targetData[2] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256,uint160))",
            mintParams
        );
        // uint256 expectedTokenId = 33963276;
        // DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
        //     DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 500e18, 500e18, 0, 0, block.timestamp);
        // targetData[3] = abi.encodeWithSignature(
        //     "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        // );
        // targetData[4] = abi.encodeWithSignature("approve(address,uint256)", gauges[0], expectedTokenId);
        // targetData[5] = abi.encodeWithSignature("deposit(uint256)", expectedTokenId);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](3)
        );

        // // Let rewards accrue.
        // skip(7 days);

        // manageLeafs = new ManageLeaf[](5);
        // manageLeafs[0] = leafs[10];
        // manageLeafs[1] = leafs[9];
        // manageLeafs[2] = leafs[5];
        // manageLeafs[3] = leafs[6];
        // manageLeafs[4] = leafs[7];
        // manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // targets = new address[](5);
        // targets[0] = gauges[0];
        // targets[1] = gauges[0];
        // targets[2] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        // targets[3] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");
        // targets[4] = getAddress(sourceChain, "aerodromeNonFungiblePositionManager");

        // targetData = new bytes[](5);
        // targetData[0] = abi.encodeWithSignature("getReward(uint256)", expectedTokenId);
        // targetData[1] = abi.encodeWithSignature("withdraw(uint256)", expectedTokenId);
        // uint128 expectedLiquidity = 13997094079385443670261480;
        // DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
        //     DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        // targetData[2] = abi.encodeWithSignature(
        //     "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        // );

        // DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
        //     expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        // );
        // targetData[3] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
        // targetData[4] = abi.encodeWithSignature("burn(uint256)", expectedTokenId);

        // decodersAndSanitizers = new address[](5);
        // decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        // decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        // manager.manageVaultWithMerkleVerification(
        //     manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](5)
        // );

        vm.stopBroadcast();
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface VelodromV2Gauge {
    function stakingToken() external view returns (address);
}
