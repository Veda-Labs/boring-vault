// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ModuleRegistry, IModule} from "src/base/Registry/ModuleRegistry.sol";

contract AaveV3RulesetDecoder {

    ModuleRegistry internal moduleRegistry; 
    
    //this will get confusing, maybe we pass it in? 
    uint256 public constant AAVE_V3 = 1 << 1; //this does have the benefit of telling you which protocolId is which tho

    constructor (address _moduleRegistry) {
        moduleRegistry = ModuleRegistry(_moduleRegistry);
    }

    //============================== AAVEV3 ===============================

    function supply(address asset, uint256, address onBehalfOf, uint16)
        external
        view
        virtual
        returns (bool)
    {

        address vault;
        address storageContract; 
        assembly {
            //skip 4 bytes for selector, skip 32 for padding + first spender address, skip 32 for uin256
            let vaultData := calldataload(0x84)    //8 * 16 = 128 
            let storageData := calldataload(0x98)  //9 * 16 + 4 = 148 (next 20)
            
            //shift right so we are left padded (0x123abc...)
            vault := shr(96, vaultData)
            storageContract := shr(96, storageData)
        }
        
        //apply the logic here directly from the modules!
        address[] memory tokens = new address[](1); 
        tokens[0] = asset; 

        IModule module = moduleRegistry.getModule("tokenWhitelistModule");
        bool success = module.checkRule(abi.encode(AAVE_V3, storageContract, tokens));
        if (!success) return false; 

        module = moduleRegistry.getModule("recipientModule");
        success = module.checkRule(abi.encode(vault, onBehalfOf));
        if (!success) return false; 

        return true; 
    }

    function withdraw(address asset, uint256, address to) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset, to);
    }

    function borrow(address asset, uint256, uint256, uint16, address onBehalfOf)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    function repay(address asset, uint256, uint256, address onBehalfOf)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    function setUserUseReserveAsCollateral(address asset, bool)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset);
    }

    function setUserEMode(uint8) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function claimRewards(address[] calldata, /*assets*/ uint256, /*amount*/ address to, address /*reward*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(to);
    }
}
