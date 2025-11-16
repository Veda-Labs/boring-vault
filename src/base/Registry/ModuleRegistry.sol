// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

interface IModule {
    function checkRule(bytes calldata params) external view returns (bool); 
}

contract ModuleRegistry {

    mapping(string moduleName => address module) public modules;  

    function addModule(string memory name, address module) external {
        modules[name] = module; 
    }

    function getModule(string memory name) public view returns (IModule) {
        return IModule(modules[name]); 
    }
}
