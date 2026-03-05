// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol"; 
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";

//TODO add adapter type
contract AdapterRegistry is Auth {
   
    //adapters -- take out so we can update easily?
    struct Protocol {
        uint8 UNISWAP_V3;
        uint8 ONE_INCH;
        uint8 ODOS;
        uint8 COWSWAP;
        uint8 OOGA_BOOGA;
    } 

    mapping(uint8 protocolId => mapping(uint256 version => address adapater)) public availableAdapters;  //type this?


    constructor() Auth(address(0), Authority(address(0))) {}

    function get(uint8 protocolId, uint256 version) external view returns (address) { //type this?
        return availableAdapters[protocolId][version]; 
    }
        
    //maybe we can get the version from the contract? That way we ensure that it had the right function
    function put(uint8 protocolId, address adapter) external {
        IAdapter newAdapter = IAdapter(adapter); 
        uint256 version = newAdapter.version(); 
        availableAdapters[protocolId][version] = adapter; 

        //TODO return an event
    }
}
