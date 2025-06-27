// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ShadowDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ShadowDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage} from "@forge-std/Test.sol";

// Concrete Shadow decoder implementation for testing
contract ShadowTestDecoderAndSanitizer is ShadowDecoderAndSanitizer {
    constructor(address _shadowNonFungiblePositionManager)
        ShadowDecoderAndSanitizer(_shadowNonFungiblePositionManager)
    {}
}

contract ShadowIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("sonicMainnet");
        // Setup forked environment.
        string memory rpcKey = "SONIC_MAINNET_RPC_URL";
        uint256 blockNumber = 36225635; // A recent block number

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(0));

        rawDataDecoderAndSanitizer = address(
            new ShadowTestDecoderAndSanitizer(getAddress(sourceChain, "shadowNonFungiblePositionManager"))
        );

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

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
    }

    function testShadowIntegration() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);

        // === PHASE 1: MINT OPERATION ===
        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDC");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "WETH");
        _addShadowLeafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        _generateTestLeafs(leafs, manageTree);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // First execute mint operation only
        ManageLeaf[] memory mintLeafs = new ManageLeaf[](3);
        mintLeafs[0] = leafs[0]; // approve USDC to Shadow
        mintLeafs[1] = leafs[1]; // approve WETH to Shadow
        mintLeafs[2] = leafs[2]; // mint Shadow position
        bytes32[][] memory mintProofs = _getProofsUsingTree(mintLeafs, manageTree);

        address[] memory mintTargets = new address[](3);
        mintTargets[0] = getAddress(sourceChain, "USDC");
        mintTargets[1] = getAddress(sourceChain, "WETH");
        mintTargets[2] = getAddress(sourceChain, "shadowNonFungiblePositionManager");

        bytes[] memory mintTargetData = new bytes[](3);
        mintTargetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            getAddress(sourceChain, "shadowNonFungiblePositionManager"), 
            type(uint256).max
        );
        mintTargetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            getAddress(sourceChain, "shadowNonFungiblePositionManager"), 
            type(uint256).max
        );

        DecoderCustomTypes.MintParamsShadow memory mintParams = DecoderCustomTypes.MintParamsShadow(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "WETH"),
            int24(100), // tickSpacing instead of fee
            int24(-100), // lower tick
            int24(100), // upper tick
            1000e6, // amount0Desired
            1e18, // amount1Desired
            0, // amount0Min
            0, // amount1Min
            address(boringVault),
            block.timestamp
        );

        mintTargetData[2] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", 
            mintParams
        );

        address[] memory mintDecodersAndSanitizers = new address[](3);
        mintDecodersAndSanitizers[0] = rawDataDecoderAndSanitizer; // ERC20 approve
        mintDecodersAndSanitizers[1] = rawDataDecoderAndSanitizer; // ERC20 approve  
        mintDecodersAndSanitizers[2] = rawDataDecoderAndSanitizer; // Shadow mint

        // Execute mint operation
        manager.manageVaultWithMerkleVerification(
            mintProofs, mintDecodersAndSanitizers, mintTargets, mintTargetData, new uint256[](3)
        );

        // === PHASE 2: INCREASE/DECREASE LIQUIDITY OPERATIONS ===
        uint256 newTokenId = 643; // This is the actual tokenId generated by the mint operation

        ManageLeaf[] memory liquidityLeafs = new ManageLeaf[](2);
        liquidityLeafs[0] = leafs[3]; // increase liquidity
        liquidityLeafs[1] = leafs[4]; // decrease liquidity
        bytes32[][] memory liquidityProofs = _getProofsUsingTree(liquidityLeafs, manageTree);

        address[] memory liquidityTargets = new address[](2);
        liquidityTargets[0] = getAddress(sourceChain, "shadowNonFungiblePositionManager");
        liquidityTargets[1] = getAddress(sourceChain, "shadowNonFungiblePositionManager");

        bytes[] memory liquidityTargetData = new bytes[](2);
        
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(newTokenId, 100e6, 0.1e18, 0, 0, block.timestamp);
        liquidityTargetData[0] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", 
            increaseLiquidityParams
        );

        uint128 expectedLiquidity = 6894419503503303421; // Actual liquidity from increaseLiquidity operation
        DecoderCustomTypes.DecreaseLiquidityParams memory decreaseLiquidityParams =
            DecoderCustomTypes.DecreaseLiquidityParams(newTokenId, expectedLiquidity / 2, 0, 0, block.timestamp);
        liquidityTargetData[1] = abi.encodeWithSignature(
            "decreaseLiquidity((uint256,uint128,uint256,uint256,uint256))", 
            decreaseLiquidityParams
        );

        address[] memory liquidityDecodersAndSanitizers = new address[](2);
        liquidityDecodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        liquidityDecodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Execute liquidity operations
        manager.manageVaultWithMerkleVerification(
            liquidityProofs, liquidityDecodersAndSanitizers, liquidityTargets, liquidityTargetData, new uint256[](2)
        );
    }

    function testShadowIntegrationReverts() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDC");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "WETH");
        _addShadowLeafs(leafs, token0, token1);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

                 ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
         manageLeafs[0] = leafs[0]; // approve USDC
         manageLeafs[1] = leafs[1]; // approve WETH
         manageLeafs[2] = leafs[2]; // mint
         manageLeafs[3] = leafs[3]; // increase liquidity
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "WETH");
        targets[2] = getAddress(sourceChain, "shadowNonFungiblePositionManager");
        targets[3] = getAddress(sourceChain, "shadowNonFungiblePositionManager");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            getAddress(sourceChain, "shadowNonFungiblePositionManager"), 
            type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", 
            getAddress(sourceChain, "shadowNonFungiblePositionManager"), 
            type(uint256).max
        );

        DecoderCustomTypes.MintParamsShadow memory mintParams = DecoderCustomTypes.MintParamsShadow(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "WETH"),
            int24(100),
            int24(-100),
            int24(100),
            1000e6,
            1e18,
            0,
            0,
            address(boringVault),
            block.timestamp
        );
        targetData[2] = abi.encodeWithSignature(
            "mint((address,address,int24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", 
            mintParams
        );

                 uint256 expectedTokenId = 643;
        
        // Try increasing liquidity to a token not owned by the boring vault.
        // Use a smaller offset to reference an existing tokenId that belongs to someone else
        DecoderCustomTypes.IncreaseLiquidityParams memory increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId - 10, 100e6, 0.1e18, 0, 0, block.timestamp);
        targetData[3] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", 
            increaseLiquidityParams
        );

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[3],
                targetData[3],
                0
            )
        );
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](4)
        );

        // Fix increase liquidity tokenId
        increaseLiquidityParams =
            DecoderCustomTypes.IncreaseLiquidityParams(expectedTokenId, 100e6, 0.1e18, 0, 0, block.timestamp);
        targetData[3] = abi.encodeWithSignature(
            "increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", 
            increaseLiquidityParams
        );

        // Call now works.
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](4)
        );
    }


    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
} 