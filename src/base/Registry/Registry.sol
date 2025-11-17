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

    uint256[] public allProtocolIds;
    mapping(uint256 protocolId => ProtocolConfig protocolConfig) public protocolConfigs;
    mapping(address target => ProtocolConfig protocolConfig) public targetToConfigs;
    mapping(uint256 => bool) internal _exists;
    
    //auth this eventually if we keep it 
    function addConfig(
        uint256 protocolId, 
        address[] calldata targets,
        address decoder, 
        uint256 index 
    ) external {
        if (_exists[protocolId]) revert("nah"); 
        allProtocolIds.push(protocolId);
        _exists[protocolId] = true;

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
    
    function getAllProtocols() external view returns (uint256[] memory) {
        return allProtocolIds;
    }

    function getProtocolCount() external view returns (uint256) {
        return allProtocolIds.length;
    }
}
