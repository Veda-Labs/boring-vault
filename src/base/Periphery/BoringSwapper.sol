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
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";

//TODO let's handle the cowswap path today

contract BoringSwapper is Auth {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
        
    //EIP 1271
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;
    
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

    struct OracleConfig {
        address usdOracle; 
        address ethOracle;
        address btcOracle;
    }
    
    struct SwapConfig{
        TokenRoute tokenRoute; 
        uint8 protocolId; 
        QuoteAsset quoteAsset; 
        bytes swapData; 
        uint256 slippageBps; 
        BoringVault receiver; 
    }
    
    mapping(ERC20 token => bool approved) public approvedTokens;
    mapping(bytes32 routeId => bool approved) public approvedRoutes; //is this needed? annoying to auth (bad ux)
    mapping(bytes32 routeId => uint256 maxSlippageBps) public maxSlippageBpsPerRoute;
    mapping(uint8 protocolId => bool approved) public approvedProtocols;
    mapping(ERC20 token => OracleConfig oracleConfig) public oracleConfigs; 
    
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

        //snapshot the balance
        uint256 tokenBalanceBefore = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)); 

        //if we succeeded, just execute the swap now. 
        (address target, uint256 amount) = abi.decode(result, (address, uint256));
        
        //price the trade
        //IMPORTANT: oracles will need to account for different decimals -> this should happen at the RateProvider level
        //do we sanity check it here? probably.  //TODO
        uint256 priceBefore = IRateProvider(
            _getOracle(swapConfig.tokenRoute.tokenIn, swapConfig.quoteAsset)
        ).getRate();
        uint256 tradePrice = priceBefore.mulDivDown(amount, 10 ** swapConfig.tokenRoute.tokenIn.decimals());

        swapConfig.tokenRoute.tokenIn.transferFrom(address(swapConfig.receiver), address(this), amount); 
        swapConfig.tokenRoute.tokenIn.approve(target, amount); 
        (success, ) = target.call(swapConfig.swapData); 
        if (!success) revert("bad");
        
        uint256 tokenBalanceDelta = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)) - tokenBalanceBefore; 
        
        //price out
        uint256 priceAfter = IRateProvider(
            _getOracle(swapConfig.tokenRoute.tokenOut, swapConfig.quoteAsset)
        ).getRate();
        uint256 valueOut = priceAfter.mulDivDown(tokenBalanceDelta, 10 ** swapConfig.tokenRoute.tokenOut.decimals());
        
        if(swapConfig.slippageBps > maxSlippageBpsPerRoute[key]) revert("exceeds max slippage for this token route"); 

        uint256 minValueOut = tradePrice.mulDivDown((10_000 - swapConfig.slippageBps), 10_000);
        if (valueOut < minValueOut) revert("exceeds max slippage for route");

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

    function addApprovedOracleConfig(ERC20 token, OracleConfig calldata config) external {
        oracleConfigs[token] = config; 
        //TODO add event
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

        (bool success, uint256 sellAmount, uint256 buyAmount) = IAdapter(adapter).swap(swapConfig.swapData, address(this));
        if (!success) revert("bad swap");
        
        //TODO better documentation here
        
        uint256 sellPrice = IRateProvider(
            _getOracle(swapConfig.tokenRoute.tokenIn, swapConfig.quoteAsset)
        ).getRate();
        uint256 valueIn = sellPrice.mulDivDown(sellAmount, 10 ** swapConfig.tokenRoute.tokenIn.decimals());

        uint256 buyPrice = IRateProvider(
            _getOracle(swapConfig.tokenRoute.tokenOut, swapConfig.quoteAsset)
        ).getRate();
        uint256 valueOut = buyPrice.mulDivDown(buyAmount, 10 ** swapConfig.tokenRoute.tokenOut.decimals());

        uint256 minValueOut = valueIn.mulDivDown((10_000 - swapConfig.slippageBps), 10_000);
        if (valueOut < minValueOut) revert("limit order price exceeds max slippage");

        return MAGIC_VALUE;
    }

    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) public pure returns (bytes32) {
        return keccak256(abi.encode(address(tokenIn), address(tokenOut)));
    }

    function _getOracle(ERC20 token, QuoteAsset quoteAsset) internal view returns (address) {
        OracleConfig memory oracleConfig = oracleConfigs[token]; 
         
        if (quoteAsset == QuoteAsset.BTC) return oracleConfig.btcOracle;
        if (quoteAsset == QuoteAsset.ETH) return oracleConfig.ethOracle;
        if (quoteAsset == QuoteAsset.USD) return oracleConfig.usdOracle;

        revert("unsupported quote asset"); 
    }
}
