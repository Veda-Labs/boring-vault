// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {EtherFiLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";


contract BaseTestIntegration is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    struct Tx {
        ManageLeaf[] manageLeafs;  
        address[] targets;  
        bytes[] targetData; 
        address[] decodersAndSanitizers;
        uint256[] values;    
    }

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    address public strategist; 

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;
    
    mapping(string => string) public nameToRPC; 

    function setUp() public virtual {
        nameToRPC["mainnet"] = "MAINNET_RPC_URL";  
        nameToRPC["base"] = "BASE_RPC_URL";  
        nameToRPC["arbitrum"] = "ARBITRUM_RPC_URL";  
        nameToRPC["sonicMainnet"] = "SONIC_MAINNET_RPC_URL";  
        nameToRPC["berachain"] = "BERA_CHAIN_RPC_URL";  
        nameToRPC["bsc"] = "BNB_RPC_URL"; 
        nameToRPC["swell"] = "SWELL_CHAIN_RPC_URL"; 
        nameToRPC["derive"] = "DERIVE_RPC_URL"; 
        nameToRPC["avalanche"] = "AVALANCHE_RPC_URL"; 
        nameToRPC["hyperEVM"] = "HYPER_EVM_RPC_URL"; 
        nameToRPC["tac"] = "TAC_RPC_URL"; 
        nameToRPC["katana"] = "KATANA_RPC_URL"; 
        nameToRPC["plasma"] = "PLASMA_RPC_URL"; 
    }
    
    function _setupChain(string memory chain, uint256 blockNumber) internal {

        setSourceChainName(chain);
        // Setup forked environment.
        string memory rpcKey = nameToRPC[chain]; 
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new EtherFiLiquidDecoderAndSanitizer(address(0)));

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

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _overrideDecoder(address newDecoder) internal {
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", newDecoder);
        rawDataDecoderAndSanitizer = newDecoder; 
    }

    function _overrideBoringVault(address newBoringVault) internal {
        setAddress(true, sourceChain, "boringVault", newBoringVault);
        boringVault = BoringVault(payable(newBoringVault)); 
    }

    function _overrideManager(address newManager) internal {
        setAddress(true, sourceChain, "manager", newManager);
        manager = ManagerWithMerkleVerification(newManager); 
    }

    function _overrideRolesAuthority() internal {
        rolesAuthority = RolesAuthority(address(boringVault.authority()));
    }

    function _setStrategist(address _strategist) internal {
        strategist = _strategist;  
    }

    function _getTxArrays(uint256 size) internal pure returns (Tx memory) {
        Tx memory tx_; 

        tx_.manageLeafs = new ManageLeaf[](size); 
        tx_.targets = new address[](size); 
        tx_.targetData = new bytes[](size); 
        tx_.decodersAndSanitizers = new address[](size); 
        tx_.values = new uint256[](size); 

        return tx_; 
    }

    function _submitManagerCall(bytes32[][] memory proofs, Tx memory tx_) internal {
        manager.manageVaultWithMerkleVerification(proofs, tx_.decodersAndSanitizers, tx_.targets, tx_.targetData, tx_.values);
    }
}
