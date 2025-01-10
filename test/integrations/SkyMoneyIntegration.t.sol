// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 
import {SkyMoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SkyMoneyDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract SkyMoneyIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 21495090;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new FullSkyMoneyDecoderAndSanitizer(address(boringVault))
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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testSkyMoneyIntegration() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 100_000e6);
        deal(getAddress(sourceChain, "DAI"), address(boringVault), 100_000e18);
        deal(getAddress(sourceChain, "USDS"), address(boringVault), 100_000e18);


        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addAllSkyMoneyLeafs(leafs);

        //string memory filePath = "./TestTEST.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](12);
        manageLeafs[0] = leafs[0]; //approve 
        manageLeafs[1] = leafs[1]; //approve 
        manageLeafs[2] = leafs[2]; //dai -> usds
        manageLeafs[3] = leafs[3]; //usds -> dai
        manageLeafs[4] = leafs[4]; //approve 
        manageLeafs[5] = leafs[5]; //approve 
        manageLeafs[6] = leafs[6]; //sellGem (swap USDC for USDS)
        manageLeafs[7] = leafs[7]; //buyGem (swap USDS for USDC)
        manageLeafs[8] = leafs[8]; //approve 
        manageLeafs[9] = leafs[9]; //approve 
        manageLeafs[10] = leafs[10]; //sellGem (swap USDC for DAI) 
        manageLeafs[11] = leafs[11]; //buyGem (swap DAI for USDC)

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](12);
        targets[0] = getAddress(sourceChain, "DAI"); //approve converter
        targets[1] = getAddress(sourceChain, "USDS"); //approve converter
        targets[2] = getAddress(sourceChain, "daiConverter"); //swap DAI to USDS
        targets[3] = getAddress(sourceChain, "daiConverter"); //swap USDS to DAI
        targets[4] = getAddress(sourceChain, "USDS"); //approve USDS
        targets[5] = getAddress(sourceChain, "USDC"); //approve USDC
        targets[6] = getAddress(sourceChain, "usdsLitePsmUsdc"); //swap usdc for usds
        targets[7] = getAddress(sourceChain, "usdsLitePsmUsdc"); //swap usds for usdc
        targets[8] = getAddress(sourceChain, "DAI"); //approve
        targets[9] = getAddress(sourceChain, "USDC"); //approve
        targets[10] = getAddress(sourceChain, "daiLitePsmUsdc"); //swap usdc for dai
        targets[11] = getAddress(sourceChain, "daiLitePsmUsdc"); //swap dai for usdc

        bytes[] memory targetData = new bytes[](12);
        targetData[0] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "daiConverter"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "daiConverter"), type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("daiToUsds(address,uint256)", getAddress(sourceChain, "boringVault"), 100e18);
        targetData[3] =
            abi.encodeWithSignature("usdsToDai(address,uint256)", getAddress(sourceChain, "boringVault"), 100e18);
        targetData[4] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "usdsLitePsmUsdc"), type(uint256).max);
        targetData[5] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "usdsLitePsmUsdc"), type(uint256).max);
        targetData[6] =
            abi.encodeWithSignature("sellGem(address,uint256)", getAddress(sourceChain, "boringVault"), 100e6);
        targetData[7] =
            abi.encodeWithSignature("buyGem(address,uint256)", getAddress(sourceChain, "boringVault"), 100e6);
        targetData[8] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "daiLitePsmUsdc"), type(uint256).max);
        targetData[9] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "daiLitePsmUsdc"), type(uint256).max);
        targetData[10] =
            abi.encodeWithSignature("sellGem(address,uint256)", getAddress(sourceChain, "boringVault"), 100e6);
        targetData[11] =
            abi.encodeWithSignature("buyGem(address,uint256)", getAddress(sourceChain, "boringVault"), 100e6);

        uint256[] memory values = new uint256[](12);

        address[] memory decodersAndSanitizers = new address[](12);
        for (uint256 i = 0; i < decodersAndSanitizers.length; i++) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer; 
        }

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullSkyMoneyDecoderAndSanitizer is SkyMoneyDecoderAndSanitizer {
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault) {}
}

