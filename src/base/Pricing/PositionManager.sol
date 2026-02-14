// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

contract ComposablePositionManager {

    struct Position {
        address token; 
        bool isDebt;  
    }

    mapping(address vault => []Position) public positions; 

    ComposablePricingManager pricingManager;  

    constructor(ComposablePricingManager _pricingManager) {
        pricingManager = _pricingManager;
    }

    function addPosition(address toke, bool isDebt) external {
        //add to the list to track
    }
    
    //we could also price assets in via quote if we wanted to price it against something other than the base asset, useful for ETH -> USD accounting
    function getVaultValue(address vault, /*address quoteAsset*/) external view returns (int256 totalValue) {
        Position[] memory vaultPositions = positions[vault]; 
        for (uint256 i = 0; i < vaultPositions.length; i++) {
            int256 value = pricingManager.getAssetValue(position.token); 
            totalValue += value;
        }
    }
}
