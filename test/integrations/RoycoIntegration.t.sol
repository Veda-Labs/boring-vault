// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract RoycoIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21529541;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullRoycoDecoderAndSaniziter());

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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testRoycoERC4626Integration() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "supplyUSDCAaveWrappedVault")));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //deposit
        manageLeafs[2] = leafs[2]; //withdraw
        manageLeafs[3] = leafs[3]; //mint
        manageLeafs[4] = leafs[4]; //redeem

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are supplying USDC onto Aave.
        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[2] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[3] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[4] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");

        bytes[] memory targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "supplyUSDCAaveWrappedVault"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e6, getAddress(sourceChain, "boringVault"));
        targetData[2] = abi.encodeWithSignature(
            "withdraw(uint256,address,address)",
            90e6,
            getAddress(sourceChain, "boringVault"),
            getAddress(sourceChain, "boringVault")
        );
        targetData[3] = //mint 10 shares
         abi.encodeWithSignature("mint(uint256,address)", 10e6, getAddress(sourceChain, "boringVault"));
        targetData[4] = //redeem 10 shares
        abi.encodeWithSignature(
            "redeem(uint256,address,address)",
            10e6,
            getAddress(sourceChain, "boringVault"),
            getAddress(sourceChain, "boringVault")
        );

        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](5);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoERC4626IntegrationClaiming() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
         _addRoyco4626VaultLeafs(leafs, ERC4626(getAddress(sourceChain, "supplyUSDCAaveWrappedVault")));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are supplying USDC onto Aave.
        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "supplyUSDCAaveWrappedVault"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e6, getAddress(sourceChain, "boringVault"));

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //skip some time 
        skip(12 weeks); 

        manageLeafs[0] = leafs[5]; //claim 
        manageLeafs[1] = leafs[6]; //claimFees 

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets[0] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");
        targets[1] = getAddress(sourceChain, "supplyUSDCAaveWrappedVault");

        targetData[0] = abi.encodeWithSignature(
            "claim(address)", getAddress(sourceChain, "boringVault")
        ); 
        targetData[1] = abi.encodeWithSignature(
            "claimFees(address)", getAddress(sourceChain, "boringVault")
        );

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoWeirollForfeitIntegration() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        bytes32 stkGHOHash = 0x8349eff9a17d01f2e9fa015121d0d03cd4b15ae9f2b8b17add16bbad006a1c6a; 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "USDC"), stkGHOHash, getAddress(sourceChain, "boringVault"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //first we'll check early unlocks and forfeits
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //fillIPOffers (execute deposit script)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are interacting the stkGHO market
        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "recipeMarketHub");

        bytes32[] memory ipOfferHashes = new bytes32[](1);
        ipOfferHashes[0] = stkGHOHash; //stkGHO offer hash from: https://etherscan.io/tx/0x133e477a7573555df912bba020c3a5e3c3b137a21a76c8f52b3b5a7a2065f2e0

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e6;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "recipeMarketHub"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "fillIPOffers(bytes32[],uint256[],address,address)",
            ipOfferHashes,
            amounts,
            address(0),
            getAddress(sourceChain, "boringVault")
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        //execute deposit script
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        ///Test Withdraws

        //accrue some rewards
        skip(7 days);

        //NOTE: created upon calling `fillIPOffers()` and needed for withdrawls
        address expectedWeirollWallet = 0x903eaa26E1C5fa9c12B7fa83Fa3db9aB824aAA42;
        bool executeWithdraw = true;

        ManageLeaf[] memory manageLeafs2 = new ManageLeaf[](1);
        manageLeafs2[0] = leafs[3]; //forfeit

        manageProofs = _getProofsUsingTree(manageLeafs2, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "recipeMarketHub");

        targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("forfeit(address,bool)", expectedWeirollWallet, executeWithdraw);

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        values = new uint256[](1);

        //execute forfeit script with rewards accrued
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testRoycoWeirollExecuteWithdrawIntegration() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        bytes32 stkGHOHash = 0x8349eff9a17d01f2e9fa015121d0d03cd4b15ae9f2b8b17add16bbad006a1c6a; 

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "USDC"), stkGHOHash, getAddress(sourceChain, "boringVault"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //first we'll check early unlocks and forfeits
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //fillIPOffers (execute deposit script)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //we are interacting the stkGHO market
        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "recipeMarketHub");

        bytes32[] memory ipOfferHashes = new bytes32[](1);
        ipOfferHashes[0] = stkGHOHash; //stkGHO offer hash from: https://etherscan.io/tx/0x133e477a7573555df912bba020c3a5e3c3b137a21a76c8f52b3b5a7a2065f2e0

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e6;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "recipeMarketHub"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "fillIPOffers(bytes32[],uint256[],address,address)",
            ipOfferHashes,
            amounts,
            address(0),
            getAddress(sourceChain, "boringVault")
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        //execute deposit script
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        ///Test Withdraws

        //accrue some rewards
        skip(40 days);

        //NOTE: created upon calling `fillIPOffers()` and needed for withdrawls
        address expectedWeirollWallet = 0x903eaa26E1C5fa9c12B7fa83Fa3db9aB824aAA42;

        ManageLeaf[] memory manageLeafs2 = new ManageLeaf[](2);
        manageLeafs2[0] = leafs[2]; //executeWithdrawalScript
        manageLeafs2[1] = leafs[4]; //executeWithdrawalScript

        manageProofs = _getProofsUsingTree(manageLeafs2, manageTree);

        targets = new address[](2);
        targets[0] = getAddress(sourceChain, "recipeMarketHub");
        targets[1] = getAddress(sourceChain, "recipeMarketHub");

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("executeWithdrawalScript(address)", expectedWeirollWallet);
        targetData[1] = abi.encodeWithSignature(
            "claim(address,address)", expectedWeirollWallet, getAddress(sourceChain, "boringVault")
        );

        decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        values = new uint256[](2);

        //execute forfeit script with rewards accrued
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullRoycoDecoderAndSaniziter is RoycoWeirollDecoderAndSanitizer, ERC4626DecoderAndSanitizer { }
