// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

contract AaveV3RulesetDecoder {

    //============================== AAVEV3 ===============================

    function supply(address asset, uint256, address onBehalfOf, uint16)
        external
        pure
        virtual
        returns (bool)
    {
        //apply the logic here directly from the modules!
        address[] memory tokens = new address[](1); 
        tokens[0] = asset; 
        
        //ideally there is some mechanism to loop through these checks if there are multiple we need to or something?
        bool success = Modules.TokenWhitelistModule.checkRule(abi.encode(msg.sender, tokens));
        if (!success) return false; 

        success = Modules.RecipientModule.checkRule(abi.encode(msg.sender, onBehalfOf));
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
