// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;


//make upgradeable?
contract TokenRegistry {

    uint256[] public allTokenIds;
    mapping(address token => uint256 tokenId) public tokenIds; // where an Id is just the bit
    mapping(uint256 tokenId => address token) public tokenAddresses; // where an Id is just the bit
    mapping(uint256 tokenId => bool maybe) internal _exists;

    function addToken(
        address token,
        uint256 tokenId
    ) external {
        if (_exists[tokenId]) revert("nah"); 
        allTokenIds.push(tokenId); 
        _exists[tokenId] = true; 
        
        //address => uint256
        tokenIds[token] = tokenId; 
        //uint256 => address 
        tokenAddresses[tokenId] = token; 
    }

    function isApprovedGlobally(address token) external view returns (bool) {
        uint256 tokenId = tokenIds[token];
        return _exists[tokenId];
    }
} 
