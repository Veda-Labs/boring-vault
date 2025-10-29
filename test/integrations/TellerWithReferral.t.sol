// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
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
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringVaultIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public GoldenGoose;
    ManagerWithMerkleVerification public GoldenGooseManager;
    LayerZeroTeller public GoldenGooseTeller;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    struct DepositAndBridgeParams{
        address depositAsset;
        uint256 depositAmount;
        uint256 minimumMint;
        address to;
        bytes bridgeWildCard;
        address feeToken;
        uint256 maxFee;
        address referrer;
    }

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23678596;

        _startFork(rpcKey, blockNumber);

        address goldenGooseAddress = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
        GoldenGoose = BoringVault(payable(goldenGooseAddress));
        GoldenGooseManager = ManagerWithMerkleVerification(0x5F341B1cf8C5949d6bE144A725c22383a5D3880B);
        GoldenGooseTeller = LayerZeroTeller(0x4C74ccA483A278Bcb90Aea3f8F565e56202D82B2);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidEthDecoderAndSanitizer(
                getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"),
                getAddress(sourceChain, "odosRouterV2")
            )
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
    

        vm.startPrank(address(0x130CA661B9c0bcbCd1204adF9061A569D5e0Ca24));
        RolesAuthority(address(0x9778D78495cBbfce0B1F6194526a8c3D4b9C3AAF)).setPublicCapability(address(GoldenGooseTeller), bytes4(keccak256(abi.encodePacked("withdraw(address,uint256,uint256,address)"))), true);
        GoldenGooseTeller.setShareLockPeriod(0);
        RolesAuthority(address(0x9778D78495cBbfce0B1F6194526a8c3D4b9C3AAF)).setPublicCapability(address(GoldenGooseTeller), bytes4(keccak256(abi.encodePacked("depositAndBridge(address,uint256,uint256,address,bytes,address,uint256,address)"))), true);
        vm.stopPrank();
    }

    function testBoringVaultDepositAndWithdraw() external {
        uint256 assets = 100e18;
        deal(getAddress(sourceChain, "WETH"), address(boringVault), assets);

        address referrer = 0x4200000000000000000000000000000000000006;
        ERC20[] memory assetsArray = new ERC20[](1);
        assetsArray[0] = ERC20(getAddress(sourceChain, "WETH"));

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addTellerLeafsWithReferral(leafs, address(GoldenGooseTeller), assetsArray, true, true, referrer);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[3];
        manageLeafs[2] = leafs[4];


        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH"); //approve WETH to be spent by GoldenGooseTeller
        targets[1] = address(GoldenGooseTeller);
        targets[2] = address(GoldenGooseTeller);

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(GoldenGoose), assets);
        targetData[1] = abi.encodeWithSelector(GoldenGooseTeller.deposit.selector, getAddress(sourceChain, "WETH"), assets, 0, referrer);
        targetData[2] = abi.encodeWithSelector(GoldenGooseTeller.withdraw.selector, getAddress(sourceChain, "WETH"), assets/2, 0, getAddress(sourceChain, "boringVault"));
    
        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    
    }

    function testBoringVaultDepositAndBridgeWithReferral() external {
        uint256 assets = 100e18;
        deal(getAddress(sourceChain, "WETH"), address(boringVault), assets);

        address referrer = 0x4200000000000000000000000000000000000006;
        address[] memory assetsArray = new address[](1);
        assetsArray[0] = getAddress(sourceChain, "WETH");

        address[] memory feeAssets = new address[](1);
        feeAssets[0] = getAddress(sourceChain, "ETH");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addCrossChainTellerLeafsWithReferral(leafs, address(GoldenGooseTeller), assetsArray, feeAssets, abi.encode(layerZeroLineaEndpointId), referrer);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[1];
        manageLeafs[1] = leafs[2];


        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH"); //approve WETH to be spent by GoldenGooseTeller
        targets[1] = address(GoldenGooseTeller);

        DepositAndBridgeParams memory params = DepositAndBridgeParams({
            depositAsset: getAddress(sourceChain, "WETH"),
            depositAmount: assets,
            minimumMint: 0,
            to: getAddress(sourceChain, "boringVault"),
            bridgeWildCard: abi.encode(layerZeroLineaEndpointId),
            feeToken: getAddress(sourceChain, "ETH"),
            maxFee: 1e18,
            referrer: referrer
        });

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(GoldenGoose), assets);
        targetData[1] = abi.encodeWithSelector(
            GoldenGooseTeller.depositAndBridge.selector, 
            params.depositAsset,
            params.depositAmount,
            params.minimumMint,
            params.to,
            params.bridgeWildCard,
            params.feeToken,
            params.maxFee,
            params.referrer
        );
    
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);
        values[1] = 30819757242215;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

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
