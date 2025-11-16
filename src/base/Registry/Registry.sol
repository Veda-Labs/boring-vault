// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;


//make upgradeable?
contract Registry {
       
    struct ProtocolConfig {
        address[] targets;
        address decoder;
        uint256 bit;
        uint256 index; 
    }

    mapping(uint256 protocolId => ProtocolConfig protocolConfig) public protocolConfigs;
    mapping(address target => ProtocolConfig protocolConfig) public targetToConfigs;
    
    // INDEX 0
    uint256 internal constant AAVE_V3 = 1 << 0; 
    
    //auth this eventually if we keep it 
    function addConfig(
        uint256 protocolId, 
        address[] calldata targets,
        address decoder, 
        uint256 index 
    ) external {
        protocolConfigs[protocolId] = ProtocolConfig({
            targets: targets,
            decoder: decoder,
            bit: protocolId,
            index: index
        });

        for (uint256 i; i < targets.length;) {
            targetToConfigs[targets[i]] = protocolConfigs[protocolId]; 
            unchecked {
                ++i; 
            }
        }
    }

    function getProtocolConfigFromTarget(address target) external view returns (ProtocolConfig memory) {
        return targetToConfigs[target];
    }
}
