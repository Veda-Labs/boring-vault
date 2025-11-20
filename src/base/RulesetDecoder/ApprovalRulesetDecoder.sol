// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Registry} from "src/base/Registry/Registry.sol";
import {ModuleRegistry, IModule} from "src/base/Registry/ModuleRegistry.sol";
import {ManagerWithBitmaskVerification} from "src/base/Roles/ManagerWithBitmaskVerification.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ApprovalRulesetDecoder is Test {

    Registry internal registry; 
    ModuleRegistry internal moduleRegistry; 

    constructor (address _registry, address _moduleRegistry) {
        registry = Registry(_registry); 
        moduleRegistry = ModuleRegistry(_moduleRegistry);
    }
    
    function approve(address spender, uint256 /*amount*/) external view virtual returns (bool) {
    
        address vault;
        address token; 
        address storageContract; 
        assembly {
            //skip 4 bytes for selector, skip 32 for padding + first spender address, skip 32 for uin256
            let vaultData := calldataload(0x44)   //4 * 16 + 4 = 68
            let tokenData := calldataload(0x58)   //5 * 16 + 8 = 88 (next 20)
            let storageData := calldataload(0x6C) //6 * 16 + 12 = 108 (next 20)
            
            //shift right so we are left padded (0x123abc...)
            vault := shr(96, vaultData)
            token := shr(96, tokenData)
            storageContract := shr(96, storageData)
        }
         
        Registry.ProtocolConfig memory config = registry.getProtocolConfigFromTarget(spender);
        if (config.decoder == address(0) || config.targets.length == 0) revert("bad spender"); 

        bool success = ManagerWithBitmaskVerification(msg.sender).hasProtocol(config.bit, config.index); 
        if (!success) revert("no success"); 

        address[] memory tokens = new address[](1); 
        tokens[0] = token; 
        IModule module = moduleRegistry.getModule("tokenWhitelistModule");
        success = module.checkRule(abi.encode(config.bit, storageContract, tokens));

        return success;
    }
}
