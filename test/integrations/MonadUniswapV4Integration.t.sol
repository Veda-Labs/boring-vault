// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Actions, Commands, TickMath, LiquidityAmounts, Constants} from "src/interfaces/UniswapV4Actions.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract MonadUniswapV4IntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("monad");
        string memory rpcKey = "MONAD_RPC_URL";
        uint256 blockNumber = 41107214;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer =
            address(new FullUniswapV4DecoderAndSanitizer(getAddress(sourceChain, "uniV4PositionManager")));

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

    function testUniswapV4LiquidityFunctionsNative() external {
        deal(address(boringVault), 1_000_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "MON");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        _generateTestLeafs(leafs, manageTree);
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[2]; //approve usdc permit2
        manageLeafs[1] = leafs[4]; //approve usdc permit2 for positionManager
        manageLeafs[2] = leafs[7]; //modifyLiquidities() mint (native)
        manageLeafs[3] = leafs[8]; //modifyLiquidities() increase via SETTLE
        manageLeafs[4] = leafs[9]; //modifyLiquidities() decrease
        manageLeafs[5] = leafs[9]; //modifyLiquidities() collect (same leaf as decrease)

        // // approve usdc on permit2
        // manageLeafs[0] = ManageLeaf(
        //     token1[0],
        //     false,
        //     "approve(address,uint256)",
        //     new address[](1),
        //     string.concat("approve Permit2 to spend USDC"),
        //     getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        // );
        // manageLeafs[0].argumentAddresses[0] = getAddress(sourceChain, "permit2");

        // // use permit2 to approve USDC for PositionManager
        // manageLeafs[1] = ManageLeaf(
        //     getAddress(sourceChain, "permit2"),
        //     false,
        //     "approve(address,address,uint160,uint48)",
        //     new address[](2),
        //     string.concat("use permit2 to approve USDC on PositionManager"),
        //     getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        // );
        // manageLeafs[1].argumentAddresses[0] = token1[0];
        // manageLeafs[1].argumentAddresses[1] = getAddress(sourceChain, "uniV4PositionManager");

        // // mint position leaves (native)
        // manageLeafs[2] = ManageLeaf(
        //     getAddress(sourceChain, "uniV4PositionManager"),
        //     true,
        //     "modifyLiquidities(bytes,uint256)",
        //     new address[](8),
        //     string.concat("mint uniswap v4 position for MON and USDC"),
        //     getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        // );
        // manageLeafs[2].argumentAddresses[0] = token0[0];
        // manageLeafs[2].argumentAddresses[1] = token1[0];
        // manageLeafs[2].argumentAddresses[2] = hooks[0];
        // manageLeafs[2].argumentAddresses[3] = getAddress(sourceChain, "boringVault");
        // manageLeafs[2].argumentAddresses[4] = token0[0];
        // manageLeafs[2].argumentAddresses[5] = token1[0];
        // manageLeafs[2].argumentAddresses[6] = token0[0];
        // manageLeafs[2].argumentAddresses[7] = getAddress(sourceChain, "boringVault");

        // // increase via SETTLE
        // manageLeafs[3] = ManageLeaf(
        //     getAddress(sourceChain, "uniV4PositionManager"),
        //     true,
        //     "modifyLiquidities(bytes,uint256)",
        //     new address[](7),
        //     string.concat("increase liquidity for univ4 position for MON and USDC"),
        //     getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        // );
        // manageLeafs[3].argumentAddresses[0] = token0[0];
        // manageLeafs[3].argumentAddresses[1] = token1[0];
        // manageLeafs[3].argumentAddresses[2] = hooks[0];
        // manageLeafs[3].argumentAddresses[3] = token0[0];
        // manageLeafs[3].argumentAddresses[4] = token1[0];
        // manageLeafs[3].argumentAddresses[5] = token0[0];
        // manageLeafs[3].argumentAddresses[6] = getAddress(sourceChain, "boringVault");

        // // decrease liquidity
        // manageLeafs[4] = ManageLeaf(
        //     getAddress(sourceChain, "uniV4PositionManager"),
        //     true,
        //     "modifyLiquidities(bytes,uint256)",
        //     new address[](6),
        //     string.concat("decrease liquidity for univ4 position for MON and USDC using SETTLE"),
        //     getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        // );
        // manageLeafs[4].argumentAddresses[0] = token0[0];
        // manageLeafs[4].argumentAddresses[1] = token1[0];
        // manageLeafs[4].argumentAddresses[2] = hooks[0];
        // manageLeafs[4].argumentAddresses[3] = token0[0];
        // manageLeafs[4].argumentAddresses[4] = token1[0];
        // manageLeafs[4].argumentAddresses[5] = getAddress(sourceChain, "boringVault");

        // // collect
        // manageLeafs[5] = ManageLeaf(
        //     getAddress(sourceChain, "uniV4PositionManager"),
        //     true,
        //     "modifyLiquidities(bytes,uint256)",
        //     new address[](6),
        //     string.concat("decrease liquidity for univ4 position for MON and USDC using SETTLE"),
        //     getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        // );
        // manageLeafs[5].argumentAddresses[0] = token0[0];
        // manageLeafs[5].argumentAddresses[1] = token1[0];
        // manageLeafs[5].argumentAddresses[2] = hooks[0];
        // manageLeafs[5].argumentAddresses[3] = token0[0];
        // manageLeafs[5].argumentAddresses[4] = token1[0];
        // manageLeafs[5].argumentAddresses[5] = getAddress(sourceChain, "boringVault");

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "USDC"); //approve usdt permit2
        targets[1] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdc
        targets[2] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities mint
        targets[3] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities increase
        targets[4] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities decrease
        targets[5] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities collect

        bytes[] memory targetData = new bytes[](6);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4PositionManager"),
            type(uint160).max,
            type(uint48).max
        );

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            address(0), // MON
            getAddress(sourceChain, "USDC"),
            500,
            10,
            address(0) //no hook address?
        );

        //actions
        bytes memory liquidityActions =
            abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            key,
            TickMath.minUsableTick(key.tickSpacing),
            TickMath.maxUsableTick(key.tickSpacing),
            1e6,
            type(uint128).max,
            type(uint128).max,
            address(boringVault),
            new bytes(0)
        );
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(boringVault));

        //mint token id = 2345
        targetData[2] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //increase liquidity
        liquidityActions =
            abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
        params = new bytes[](3);
        params[0] = abi.encode(2345, 1e6, type(uint128).max, type(uint128).max, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(boringVault));

        targetData[3] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //decrease liquidity
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(2345, 50e3, 0, 0, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[4] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //collect, no fees are collected here in the test because none have accumulated (view the logs with -vvvv to see this happening)
        // @dev collect is done by decreasing liquidity with a 0 amount, and then taking the pair
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //no liquidity decrease
            0,
            0,
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[5] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](6);
        values[0] = 0;
        values[1] = 0;
        values[2] = 1e16;
        values[3] = 1e16;
        values[4] = 0;
        values[5] = 0;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        skip(1 days);

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[11];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities

        targetData = new bytes[](1);

        // @dev docs are wrong here, we need to take pair still
        liquidityActions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //amount0 full slippage
            0, //amount1 full slippage
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[0] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp + 1
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullUniswapV4DecoderAndSanitizer is UniswapV4DecoderAndSanitizer {
    constructor(address _posm) UniswapV4DecoderAndSanitizer(_posm) {}
}

interface IUniswapV2Factory {
    function getPair(address token0, address token1) external view returns (address);
}
