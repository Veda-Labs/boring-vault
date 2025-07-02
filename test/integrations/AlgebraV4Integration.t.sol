// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    AlgebraV4DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/AlgebraV4DecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FullAlgebraDecoderAndSanitizer is BaseDecoderAndSanitizer, AlgebraV4DecoderAndSanitizer {
    constructor(address _nfp) AlgebraV4DecoderAndSanitizer(_nfp){}
}

contract AlgebraV3IntegrationTest is Test, MerkleTreeHelper {
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

    function setUp() external {
        setSourceChainName("arbitrum");
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 350382389;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer =
            address(new FullAlgebraDecoderAndSanitizer(getAddress(sourceChain, "algebraNonFungiblePositionManager")));

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

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
    }

    function testAlgebraV4Integration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "USDC");
        token1[1] = getAddress(sourceChain, "GRAIL");
        _addAlgebraV4Leafs(leafs, token0, token1, address(0));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[2];
        manageLeafs[1] = leafs[6];
        manageLeafs[2] = leafs[0];
        manageLeafs[3] = leafs[1];
        manageLeafs[4] = leafs[4];
        manageLeafs[5] = leafs[5];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "WETH"); //approve router
        targets[1] = getAddress(sourceChain, "algebraV4Router");
        targets[2] = getAddress(sourceChain, "WETH"); //approve nfpm
        targets[3] = getAddress(sourceChain, "USDC"); //approve nfpm
        targets[4] = getAddress(sourceChain, "algebraNonFungiblePositionManager");
        targets[5] = getAddress(sourceChain, "algebraNonFungiblePositionManager");

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "algebraV4Router"), type(uint256).max
        );
        DecoderCustomTypes.ExactInputParams memory exactInputParams = DecoderCustomTypes.ExactInputParams(
            abi.encodePacked(getAddress(sourceChain, "WETH"), address(0), getAddress(sourceChain, "USDC")),
            address(boringVault),
            block.timestamp,
            0.001e18,
            0
        );
        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "algebraNonFungiblePositionManager"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "algebraNonFungiblePositionManager"), type(uint256).max
        );

        DecoderCustomTypes.AlgebraMintParams memory mintParams = DecoderCustomTypes.AlgebraMintParams(
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "USDC"),
            address(0),
            int24(400), // lower tick
            int24(450), // upper tick
            45e18,
            45e18,
            0,
            0,
            address(boringVault),
            block.timestamp
        );
        targetData[4] = abi.encodeWithSignature(
            "mint((address,address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams
        );
        uint256 expectedTokenId = 120;
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
        targetData[5] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
        );

        //DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
        //    DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
        //targetData[6] = abi.encodeWithSignature(
        //    "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        //);

        //DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
        //    expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        //);
        //targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](6)
        );
    
        //positions
        (, , , , , , , uint128 liquidity,,,,) =
            AlgebraNonFungiblePositionManager(0x368435A76B1a855D054D3CDf4c20f5E0B2bABBC8).positions(expectedTokenId);

        manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[14]; //decrease
        manageLeafs[1] = leafs[15]; //collect
        manageLeafs[2] = leafs[16]; //burn

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](3);
        targets[0] = getAddress(sourceChain, "algebraNonFungiblePositionManager");
        targets[1] = getAddress(sourceChain, "algebraNonFungiblePositionManager");
        targets[2] = getAddress(sourceChain, "algebraNonFungiblePositionManager");

        targetData = new bytes[](3);
        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, liquidity, 0, 0, block.timestamp);
        targetData[0] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
        );

        DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
        );
        targetData[1] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
        targetData[2] = abi.encodeWithSignature("burn(uint256)", expectedTokenId);

        decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](3)
        );

        

    }

//    function testCamelotV3IntegrationReverts() external {
//        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 1_000e18);
//        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 1_000e18);
//
//        ManageLeaf[] memory leafs = new ManageLeaf[](32);
//        address[] memory token0 = new address[](2);
//        token0[0] = getAddress(sourceChain, "WETH");
//        token0[1] = getAddress(sourceChain, "WETH");
//        address[] memory token1 = new address[](2);
//        token1[0] = getAddress(sourceChain, "WSTETH");
//        token1[1] = getAddress(sourceChain, "WEETH");
//        _addCamelotV3Leafs(leafs, token0, token1);
//
//        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
//
//        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
//
//        ManageLeaf[] memory manageLeafs = new ManageLeaf[](9);
//        manageLeafs[0] = leafs[2];
//        manageLeafs[1] = leafs[6];
//        manageLeafs[2] = leafs[1];
//        manageLeafs[3] = leafs[8];
//        manageLeafs[4] = leafs[10];
//        manageLeafs[5] = leafs[11];
//        manageLeafs[6] = leafs[14];
//        manageLeafs[7] = leafs[15];
//        manageLeafs[8] = leafs[16];
//        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
//
//        address[] memory targets = new address[](9);
//        targets[0] = getAddress(sourceChain, "WSTETH");
//        targets[1] = getAddress(sourceChain, "camelotRouterV3");
//        targets[2] = getAddress(sourceChain, "WETH");
//        targets[3] = getAddress(sourceChain, "WEETH");
//        targets[4] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
//        targets[5] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
//        targets[6] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
//        targets[7] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
//        targets[8] = getAddress(sourceChain, "camelotNonFungiblePositionManager");
//        bytes[] memory targetData = new bytes[](9);
//        targetData[0] = abi.encodeWithSignature(
//            "approve(address,uint256)", getAddress(sourceChain, "camelotRouterV3"), type(uint256).max
//        );
//        DecoderCustomTypes.ExactInputParams memory exactInputParams = DecoderCustomTypes.ExactInputParams(
//            abi.encodePacked(getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "WETH")),
//            address(boringVault),
//            block.timestamp,
//            100e18,
//            0
//        );
//        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);
//        targetData[2] = abi.encodeWithSignature(
//            "approve(address,uint256)", getAddress(sourceChain, "camelotNonFungiblePositionManager"), type(uint256).max
//        );
//        targetData[3] = abi.encodeWithSignature(
//            "approve(address,uint256)", getAddress(sourceChain, "camelotNonFungiblePositionManager"), type(uint256).max
//        );
//
//        DecoderCustomTypes.CamelotMintParams memory mintParams = DecoderCustomTypes.CamelotMintParams(
//            getAddress(sourceChain, "WEETH"),
//            getAddress(sourceChain, "WETH"),
//            int24(400), // lower tick
//            int24(450), // upper tick
//            45e18,
//            45e18,
//            0,
//            0,
//            address(boringVault),
//            block.timestamp
//        );
//        targetData[4] = abi.encodeWithSignature(
//            "mint((address,address,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams
//        );
//        uint256 expectedTokenId = 119901;
//        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
//            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
//        targetData[5] = abi.encodeWithSignature(
//            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
//        );
//        uint128 expectedLiquidity = 35024744166363799012869 + 35024744166363799012869;
//        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
//            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
//        targetData[6] = abi.encodeWithSignature(
//            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
//        );
//
//        DecoderCustomTypes.CollectParams memory collectParams = DecoderCustomTypes.CollectParams(
//            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
//        );
//        targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
//        targetData[8] = abi.encodeWithSignature("burn(uint256)", expectedTokenId);
//
//        address[] memory decodersAndSanitizers = new address[](9);
//        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
//        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
//        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
//        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
//        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
//        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
//        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
//        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
//        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
//
//        // Make swap path data malformed.
//        exactInputParams = DecoderCustomTypes.ExactInputParams(
//            abi.encodePacked(getAddress(sourceChain, "WSTETH"), uint24(100), getAddress(sourceChain, "WETH")),
//            address(boringVault),
//            block.timestamp,
//            100e18,
//            0
//        );
//        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);
//
//        vm.expectRevert(
//            abi.encodeWithSelector(CamelotDecoderAndSanitizer.CamelotDecoderAndSanitizer__BadPathFormat.selector)
//        );
//        manager.manageVaultWithMerkleVerification(
//            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
//        );
//
//        // Fix swap path data.
//        exactInputParams = DecoderCustomTypes.ExactInputParams(
//            abi.encodePacked(getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "WETH")),
//            address(boringVault),
//            block.timestamp,
//            100e18,
//            0
//        );
//        targetData[1] = abi.encodeWithSignature("exactInput((bytes,address,uint256,uint256,uint256))", exactInputParams);
//
//        // Try adding liquidity to a token not owned by the boring vault.
//        increaseLiquidityParams =
//            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId - 1, 45e18, 45e18, 0, 0, block.timestamp);
//        targetData[5] = abi.encodeWithSignature(
//            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
//        );
//
//        vm.expectRevert(
//            abi.encodeWithSelector(
//                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
//                targets[5],
//                targetData[5],
//                0
//            )
//        );
//        manager.manageVaultWithMerkleVerification(
//            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
//        );
//
//        // Fix increase liquidity, but change decreaseLiquidity tokenId.
//        increaseLiquidityParams =
//            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 45e18, 45e18, 0, 0, block.timestamp);
//        targetData[5] = abi.encodeWithSignature(
//            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", increaseLiquidityParams
//        );
//
//        decreaseLiquidityParams =
//            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId - 1, expectedLiquidity, 0, 0, block.timestamp);
//        targetData[6] = abi.encodeWithSignature(
//            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
//        );
//
//        vm.expectRevert(
//            abi.encodeWithSelector(
//                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
//                targets[6],
//                targetData[6],
//                0
//            )
//        );
//        manager.manageVaultWithMerkleVerification(
//            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
//        );
//
//        // Fix decrease liquidity but change collect tokenId.
//        decreaseLiquidityParams =
//            DecoderCustomTypes.DecreaseLiquidityParams(expectedTokenId, expectedLiquidity, 0, 0, block.timestamp);
//        targetData[6] = abi.encodeWithSignature(
//            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", decreaseLiquidityParams
//        );
//
//        collectParams = DecoderCustomTypes.CollectParams(
//            expectedTokenId - 1, address(boringVault), type(uint128).max, type(uint128).max
//        );
//        targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
//
//        vm.expectRevert(
//            abi.encodeWithSelector(
//                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
//                targets[7],
//                targetData[7],
//                0
//            )
//        );
//        manager.manageVaultWithMerkleVerification(
//            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
//        );
//
//        // Fix collect tokenId.
//        collectParams = DecoderCustomTypes.CollectParams(
//            expectedTokenId, address(boringVault), type(uint128).max, type(uint128).max
//        );
//        targetData[7] = abi.encodeWithSignature("collect((uint256,address,uint128,uint128))", collectParams);
//
//        // Call now works.
//        manager.manageVaultWithMerkleVerification(
//            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](9)
//        );
//    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}


interface AlgebraNonFungiblePositionManager {
    function ownerOf(uint256 tokenId) external view returns (address);
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            address deployer,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}
