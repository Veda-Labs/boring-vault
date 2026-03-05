// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol"; 
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

//TODO let's set up a basic test and go from there, that is today's plan/agenda

contract BoringSwapper is Auth {
        
    //EIP 1271
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;
    

    //we need to store a couple of things here, namely, the list of tokens that can be swapped
    //we need per protocol mappings
    //we need per strategist mappings (done in root) (this is kinda scuffed already) 
        
    //is there a way to make this extensible/upgradeable? Maybe we offload the structs to a different contracts? Likely we'll need a new pricing asset at some point on any given L2, XPL, HYPE, for example. 
    enum QuoteAsset {
        USD,
        ETH,
        BTC
    }

    struct TokenRoute {
        ERC20 tokenIn; 
        ERC20 tokenOut; 
    }
    
    struct SwapConfig{
        TokenRoute tokenRoute; 
        uint8 protocolId; 
        QuoteAsset quoteAsset; 
        bytes swapData; 
        BoringVault receiver; 
    }
    
    mapping(ERC20 token => bool approved) public approvedTokens;
    mapping(bytes32 routeId => bool approved) public approvedRoutes; //is this needed? annoying to auth (bad ux)
    mapping(bytes32 routeId => uint256 maxPriceImpact) public priceImpacts;
    mapping(uint8 protocolId => bool approved) public approvedProtocols; 
    
    /// @notice stores the current version this swapper subscribes to for a specific protocol
    /// @dev defaults to 0, the first version
    mapping(uint8 protocolId => uint256 version) public versions;

    AdapterRegistry public adapterRegsitry; 

    constructor(AdapterRegistry _adapterRegistry) Auth(address(0), Authority(address(0))) {
        adapterRegsitry = _adapterRegistry; 
    }
    
    //TODO do we need auth here? maybe not.  
    function swap(SwapConfig calldata swapConfig) external { 
        //compute the key
        bytes32 key = _getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        uint256 maxTradePriceImpact = priceImpacts[key]; //what do we do with routes that are not set?

        //check the whitelist of tokens
        if (approvedRoutes[key] == false) revert("not approved"); //TODO custom error
        
        //get the protocol id from the registry 
        //we can probably get away with whitelisting protocols directly so we can update our list centrally (though should check to be sure)
        if (approvedProtocols[swapConfig.protocolId] == false) revert("not approved"); 
        
        uint256 version = versions[swapConfig.protocolId]; 
        //get the correct adapter based on the version
        address adapter = adapterRegsitry.get(swapConfig.protocolId, version);  
        (bool success, bytes memory result) = adapter.staticcall(swapConfig.swapData);
        if (!success) revert("must succeed");

        //snapshot the balance
        uint256 tokenBalanceBefore = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)); 

        //if we succeeded, just execute the swap now. 
        (address target, uint256 amount) = abi.decode(result, (address, uint256));
        swapConfig.tokenRoute.tokenIn.transferFrom(address(swapConfig.receiver), address(this), amount); 
        swapConfig.tokenRoute.tokenIn.approve(target, amount); 
        (success, ) = target.call(swapConfig.swapData); 
        if (!success) revert("bad");
        
        uint256 tokenBalanceDelta = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)) - tokenBalanceBefore; 
        //do the check (after > expectedReturnAmount)

        //if (tokenBalanceDelta < normalizedDelta) revert("bad price");  

        //TODO reset approvals
        swapConfig.tokenRoute.tokenIn.approve(target, 0); 

        //send to vault
        swapConfig.tokenRoute.tokenOut.transfer(address(swapConfig.receiver), tokenBalanceDelta); 
    }  
    
    //do we even want this?
    function addApprovedRoute(ERC20 tokenIn, ERC20 tokenOut, uint256 maxPriceImpact) external {
        bytes32 key = _getRouteId(tokenIn, tokenOut);
        approvedRoutes[key] = true;
        priceImpacts[key] = maxPriceImpact;
        //TODO add event
    }

    function addApprovedProtocol(uint8 protocolId) external {
        approvedProtocols[protocolId] = true;  
        //TODO add event 
    }

    function addApprovedVersion(uint8 protocolId, uint256 version) external {
        versions[protocolId] = version; 
    } 
    
    /// @notice Called by CoW Protocol settlement contract to validate an order
    function isValidSignature(bytes32 _hash, bytes memory)
        external
        view
        returns (bytes4)
    {
        
        //TODO
        //can do additional validation logic here, importantly, the token MUST be preapproved by the vault already. 
        //we can send the data to the cowswap adapter here for verification, but the flow has to return here at some point

        //if (approvedOrders[_hash]) {
            return MAGIC_VALUE;
        //}
        //return 0xffffffff;
    }

    function _getRouteId(ERC20 tokenIn, ERC20 tokenOut) internal returns (bytes32) {
        return keccak256(abi.encode(address(tokenIn), address(tokenOut)));
    }
}
