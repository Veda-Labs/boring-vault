// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

interface IComposablePricingModule {

}

contract ComposablePricingManager {
    
    struct ComposablePriceModule{
        address moduleAddress; 
        uint8 typeId; 
    } 
    
    //use the type to build out archetypes 
    //only need to compose new distinct types for complex protocols
    mapping(uint8 typeId => address typeFactory) public typeFactories;
    mapping(uint8 typeId => string typeName) public typeNames; 

    mapping(address priceModule => bool isActive) public activeModules; 
    mapping(address token => address priceModule) public tokenPrices; 
    ComposablePriceModule[] public priceModules; 
    uint8[] public priceFeedTypes;

    function addModule(IComposablePricingModule module, address factory, string memory name) external {
        //deploy and register a new pricing module type 
        //lookup the factory -> deploy contract
        
        //register factory
        typeFactories[module.typeId] = factory;
        typeNames[module.typeId] = name;
        activeModules[module.typeId] = true;
        
        //push into arrays
        priceFeedTypes.push(module.typeId);
        priceModules.push(factory); 
    }     

    function removeModule(IComposablePricingModule module) external {
        //remove the module 
    }

    function isModuleActive(address module) public returns (bool) {
        return activeModules[module]; 
    }

    function getAssetValue(address token) external view returns (int256) {
        address pricingModule = tokenPrices[token];
        int256 value = IComposablePricingModule(pricingModule).getPrice(); 
        return value; 
    }
    
}
