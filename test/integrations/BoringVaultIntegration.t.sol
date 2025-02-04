// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    EtherFiLiquidEthDecoderAndSanitizer,
    TellerDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {EtherFiBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiBtcDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringVaultIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public liquidEth;
    ManagerWithMerkleVerification public liquidEthManager;
    BoringVault public superSymbiotic;
    TellerWithMultiAssetSupport public superSymbioticTeller;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    address public liquidEthOwner;

    uint8 public constant SOLVER_ROLE = 12;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21579297;

        _startFork(rpcKey, blockNumber);

        //TODO fixme, most likely broken
        liquidEth = BoringVault(payable(getAddress(sourceChain, "liquidEth")));
        liquidEthManager = ManagerWithMerkleVerification(getAddress(sourceChain, "liquidEthManager"));
        superSymbiotic = BoringVault(payable(getAddress(sourceChain, "superSymbiotic")));
        superSymbioticTeller = TellerWithMultiAssetSupport(getAddress(sourceChain, "superSymbioticTeller"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidEthDecoderAndSanitizer(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"))
        );

        setAddress(false, sourceChain, "boringVault", address(liquidEth));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(liquidEthManager));
        setAddress(false, sourceChain, "managerAddress", address(liquidEthManager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = RolesAuthority(address(liquidEth.authority()));

        liquidEthOwner = rolesAuthority.owner();

        rolesAuthority = RolesAuthority(address(superSymbiotic.authority()));

        address superSymbioticOwner = rolesAuthority.owner();

        // Allow liquidEth to call superSymbioticTeller bulk functions by granting it the SOLVER_ROLE.
        vm.prank(superSymbioticOwner);
        rolesAuthority.setUserRole(address(liquidEth), SOLVER_ROLE, true);
    }

    function testBoringVaultDepositAndWithdraw() external {
        deal(getAddress(sourceChain, "WETH"), address(liquidEth), 1_000e18);
        deal(getAddress(sourceChain, "WEETH"), address(liquidEth), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory assets = new ERC20[](2);
        assets[0] = ERC20(getAddress(sourceChain, "WETH"));
        assets[1] = ERC20(getAddress(sourceChain, "WEETH"));
        _addTellerLeafs(leafs, address(superSymbioticTeller), assets, false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        vm.prank(liquidEthOwner);
        liquidEthManager.setManageRoot(
            getAddress(sourceChain, "liquidEthStrategist"), manageTree[manageTree.length - 1][0]
        );

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approve weth
        manageLeafs[1] = leafs[1]; //bulk deposit weth
        manageLeafs[2] = leafs[5]; //approve weeth
        manageLeafs[3] = leafs[6]; //bulk deposit weeth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = address(superSymbioticTeller);
        targets[2] = getAddress(sourceChain, "WEETH");
        targets[3] = address(superSymbioticTeller);

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", address(superSymbiotic), type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "bulkDeposit(address,uint256,uint256,address)",
            getAddress(sourceChain, "WETH"),
            1_000e18,
            0,
            address(liquidEth)
        );
        targetData[2] = abi.encodeWithSignature("approve(address,uint256)", address(superSymbiotic), type(uint256).max);
        targetData[3] = abi.encodeWithSignature(
            "bulkDeposit(address,uint256,uint256,address)",
            getAddress(sourceChain, "WEETH"),
            1_000e18,
            0,
            address(liquidEth)
        );
        uint256[] memory values = new uint256[](4);
        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        // Deposit into Super Symbiotic.
        vm.prank(getAddress(sourceChain, "liquidEthStrategist"));
        liquidEthManager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, values
        );

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(liquidEth)), 0, "Should have deposited all WETH");
        assertEq(getERC20(sourceChain, "WEETH").balanceOf(address(liquidEth)), 0, "Should have deposited all WEETH");
        uint256 expectedSuperSymbioticBalance = 2026664295752061105010;
        assertEq(
            superSymbiotic.balanceOf(address(liquidEth)),
            expectedSuperSymbioticBalance,
            "Should expected superSymbiotic balance"
        );

        // skip(1 days);

        manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[2];
        manageLeafs[1] = leafs[7];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](2);
        targets[0] = address(superSymbioticTeller);
        targets[1] = address(superSymbioticTeller);

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "bulkWithdraw(address,uint256,uint256,address)",
            getAddress(sourceChain, "WETH"),
            expectedSuperSymbioticBalance - 1041202549969661833442,
            0,
            address(liquidEth)
        );
        targetData[1] = abi.encodeWithSignature(
            "bulkWithdraw(address,uint256,uint256,address)",
            getAddress(sourceChain, "WEETH"),
            1041202549969661833442,
            0,
            address(liquidEth)
        );
        values = new uint256[](2);
        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Withdraw from Super Symbiotic.
        vm.prank(getAddress(sourceChain, "liquidEthStrategist"));
        liquidEthManager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, values
        );

        uint256 wethDust = 271785476448469428;
        assertApproxEqAbs(
            getERC20(sourceChain, "WETH").balanceOf(address(liquidEth)) - wethDust,
            1_000e18,
            1,
            "Should have withdrawn all WETH"
        );

        uint256 weethDust = 256474008239288232;
        assertApproxEqAbs(
            getERC20(sourceChain, "WEETH").balanceOf(address(liquidEth)) + weethDust,
            1_000e18,
            1,
            "Should have withdrawn all WEETH"
        );
        assertEq(superSymbiotic.balanceOf(address(liquidEth)), 0, "Should have burned all superSymbiotic shares");
    }

    function testBoringVaultSingleDepositERC20() external {
        deal(getAddress(sourceChain, "WETH"), address(liquidEth), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "WETH"));
        _addTellerLeafs(leafs, address(superSymbioticTeller), assets, false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        vm.prank(liquidEthOwner);
        liquidEthManager.setManageRoot(
            getAddress(sourceChain, "liquidEthStrategist"), manageTree[manageTree.length - 1][0]
        );

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[3]; //deposit w/o value

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // string memory filePath = "./testTEST.json";

        // _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH");
        targets[1] = address(superSymbioticTeller);

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", address(superSymbiotic), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", getAddress(sourceChain, "WETH"), 1_000e18, 0);

        uint256[] memory values = new uint256[](2);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Deposit into Super Symbiotic.
        vm.prank(getAddress(sourceChain, "liquidEthStrategist"));
        liquidEthManager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, values
        );

        //assertEq(getERC20(sourceChain, "WETH").balanceOf(address(liquidEth)), 0, "Should have deposited all WETH");
        //assertEq(getERC20(sourceChain, "WEETH").balanceOf(address(liquidEth)), 0, "Should have deposited all WEETH");
        //uint256 expectedSuperSymbioticBalance = 2038537506572571692614;
        //assertEq(
        //    superSymbiotic.balanceOf(address(liquidEth)),
        //    expectedSuperSymbioticBalance,
        //    "Should expected superSymbiotic balance"
        //);
    }

    function testBoringVaultSingleDepositETH() external {
        deal(address(liquidEth), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = ERC20(getAddress(sourceChain, "WETH"));
        _addTellerLeafs(leafs, address(superSymbioticTeller), assets, false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        vm.prank(liquidEthOwner);
        liquidEthManager.setManageRoot(
            getAddress(sourceChain, "liquidEthStrategist"), manageTree[manageTree.length - 1][0]
        );

        vm.prank(liquidEthOwner);
        IOldTeller(address(superSymbioticTeller)).addAsset(getERC20(sourceChain, "ETH"));

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[4]; //deposit w/ value

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = address(superSymbioticTeller);

        bytes[] memory targetData = new bytes[](1);
        targetData[0] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", getAddress(sourceChain, "ETH"), 1_000e18, 0);

        uint256[] memory values = new uint256[](1);
        values[0] = 1_000e18;

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        // Deposit into Super Symbiotic.
        vm.prank(getAddress(sourceChain, "liquidEthStrategist"));
        liquidEthManager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, values
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface IOldTeller {
    function addAsset(ERC20 asset) external;
}
