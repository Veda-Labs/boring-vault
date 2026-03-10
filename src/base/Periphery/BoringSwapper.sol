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
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";

//TODO let's handle the cowswap path today

contract BoringSwapper is Auth {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
        
    //EIP 1271
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;

    struct TokenRoute {
        ERC20 tokenIn; 
        ERC20 tokenOut; 
    }
    
    struct SwapConfig{
        TokenRoute tokenRoute; 
        uint8 protocolId; 
        address quoteAsset; 
        bytes swapData; 
        uint256 slippageBps; 
        BoringVault receiver; 
    }
    
    mapping(ERC20 token => bool approved) public approvedTokens;
    mapping(bytes32 routeId => bool approved) public approvedRoutes; //is this needed? annoying to auth (bad ux)
    mapping(bytes32 routeId => uint256 maxSlippageBps) public maxSlippageBpsPerRoute;
    mapping(uint8 protocolId => bool approved) public approvedProtocols;
    mapping(ERC20 token => mapping(address quoteAsset => address oracle)) public oracles; 
    
    /// @notice stores the current version this swapper subscribes to for a specific protocol
    mapping(uint8 protocolId => uint256 version) public versions;

    AdapterRegistry public adapterRegsitry; 
    IPriceValidator public priceValidator;

    constructor(AdapterRegistry _adapterRegistry) Auth(address(0), Authority(address(0))) {
        adapterRegsitry = _adapterRegistry; 
    }
    
    //TODO do we need auth here? maybe not.  
    function swap(SwapConfig calldata swapConfig) external { 
        //compute the key
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);

        //check the whitelist of tokens
        if (approvedRoutes[key] == false) revert("not approved"); //TODO custom error
        
        //get the protocol id from the registry
        //we can probably get away with whitelisting protocols directly so we can update our list centrally (though should check to be sure)
        if (approvedProtocols[swapConfig.protocolId] == false) revert("not approved");
        
        //get the correct adapter based on the version
        address adapter = adapterRegsitry.get(
            swapConfig.protocolId, 
            versions[swapConfig.protocolId]
        );  
        (bool success, bytes memory result) = adapter.staticcall(swapConfig.swapData);
        if (!success) revert("must succeed");
        //if we succeeded, just execute the swap now. 
        (address target, uint256 amount) = abi.decode(result, (address, uint256));

        //snapshot the balance
        uint256 tokenBalanceBefore = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)); 
        
        //transfer assets from the vault to the swapper, approve target & execute
        swapConfig.tokenRoute.tokenIn.transferFrom(address(swapConfig.receiver), address(this), amount); 
        swapConfig.tokenRoute.tokenIn.approve(target, amount); 
        (success, ) = target.call(swapConfig.swapData); 
        if (!success) revert("bad");
        
        uint256 tokenBalanceDelta = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)) - tokenBalanceBefore; 
        
        //validate the price
        IPriceValidator(priceValidator).validate(
            swapConfig.tokenRoute.tokenIn,
            swapConfig.tokenRoute.tokenOut,
            amount,
            tokenBalanceDelta,
            swapConfig.quoteAsset,
            swapConfig.slippageBps
        );  

        //reset approvals and transfer
        swapConfig.tokenRoute.tokenIn.approve(target, 0); 
        swapConfig.tokenRoute.tokenOut.transfer(address(swapConfig.receiver), tokenBalanceDelta); 
    }  
    
    //do we even want this?
    function addApprovedRoute(ERC20 tokenIn, ERC20 tokenOut, uint256 maxSlippageBps) external {
        bytes32 key = getRouteId(tokenIn, tokenOut);
        approvedRoutes[key] = true;
        maxSlippageBpsPerRoute[key] = maxSlippageBps;
        //TODO add event
    }

    function addApprovedProtocol(uint8 protocolId) external {
        approvedProtocols[protocolId] = true;  
        //TODO add event 
    }

    function addApprovedVersion(uint8 protocolId, uint256 version) external {
        versions[protocolId] = version; 
    } 

    function addApprovedOracle(ERC20 token, address quoteAsset, address oracle) external {
        oracles[token][quoteAsset] = oracle; 
        //TODO add event
    }

    function setPriceValidator(IPriceValidator newValidator) external {
        priceValidator = newValidator;
    }
    
    /// @notice Called by CoW Protocol settlement contract to validate an order
    function isValidSignature(bytes32 _hash, bytes memory _signature)
        external
        view
        returns (bytes4)
    {
        (SwapConfig memory swapConfig) = abi.decode(_signature, (SwapConfig));
        address adapter = adapterRegsitry.get(
            swapConfig.protocolId,
            versions[swapConfig.protocolId]
        );
        //TODO handle errors/edge cases: what happens when the hash is not valid or spoofed?
        
        (address inputToken, address outputToken, uint256 inputAmount, uint256 outputAmount) = IAdapter(adapter).swap(swapConfig);
        IPriceValidator(priceValidator).validate(ERC20(inputToken), ERC20(outputToken), inputAmount, outputAmount, swapConfig.quoteAsset, swapConfig.slippageBps); //will revert if does not pass

        return MAGIC_VALUE;
    }

    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) public pure returns (bytes32) {
        return keccak256(abi.encode(address(tokenIn), address(tokenOut)));
    }

    function getOracle(ERC20 token, address quoteAsset) external view returns (address) {
        return oracles[token][quoteAsset]; 
    }
}
