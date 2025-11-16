// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;


import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithBitmaskVerification} from "src/base/Roles/ManagerWithBitmaskVerification.sol"; 
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {RecipientModule} from "src/base/Modules/RecipientModule.sol"; 
import {ModuleRegistry} from "src/base/Registry/ModuleRegistry.sol"; 
import {Registry} from "src/base/Registry/Registry.sol"; 
import {AaveV3RulesetDecoder} from "src/base/RulesetDecoder/AaveV3RulesetDecoder.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ManagerWithBitmaskVerificationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    
    //vault 
    BoringVault public boringVault;
    
    //roles auth
    RolesAuthority public rolesAuthority;

    //registeries 
    Registry public registry;
    ModuleRegistry public moduleRegistry;

    //manager
    ManagerWithBitmaskVerification public manager; 
    
    //modules
    RecipientModule public recipientModule; 
    
    //aaveV3
    AaveV3RulesetDecoder public aaveV3Decoder;

    function setUp() public {

        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        _startFork(rpcKey, 23808519);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);

        //register the recipient module
        recipientModule = new RecipientModule();  

        //deploy module registry
        moduleRegistry = new ModuleRegistry(); 
        moduleRegistry.addModule("recipientModule", address(recipientModule)); 
        
        //decoders
        aaveV3Decoder = new AaveV3RulesetDecoder(address(moduleRegistry));
        
        //registry
        registry = new Registry(); 

        uint256 AAVE_V3 = 1 << 0; 
        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "v3Pool");

        registry.addConfig(
            AAVE_V3, 
            targets,
            address(aaveV3Decoder),
            0 //0 index
        ); 

        manager = new ManagerWithBitmaskVerification(address(0), address(boringVault), address(registry));
        manager.subscribe(AAVE_V3, 0); 
        //manager.setAuthority(rolesAuthority);

        //set roles
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
            ManagerWithBitmaskVerification.manageVaultWithBitmaskVerification.selector,
            true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);

    }
    

    function testManagerCanCall() public {
        
        address[] memory targets = new address[](1); 
        targets[0] = getAddress(sourceChain, "v3Pool");

        bytes[] memory targetDatas = new bytes[](1); 
        targetDatas[0] = abi.encodeWithSignature(
            "supply(address,uint256,address,uint16)", 
            getAddress(sourceChain, "USDC"), 
            100e6,
            address(boringVault),
            0
        );
        
        console.log("manager", address(manager));
        manager.manageVaultWithBitmaskVerification(
            targets, 
            targetDatas,
            new uint256[](1)
        ); 
    } 

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}


