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
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";

// TODO: cancelOrder() — set approvedOrders[hash] = false, revoke settlement approval, return tokens to vault
// TODO: sweep(ERC20 token) — generic reclaim for tokens on swapper after fills or expired orders
// TODO: stale order hash cleanup strategy — hashes persist after fills since isValidSignature is view
// TODO: emit events from submitOrder (with orderHash + orderId for strategist), addApprovedRoute, addApprovedProtocol, addApprovedOracle
// TODO: add requiresAuth to admin functions (addApprovedRoute, addApprovedProtocol, addApprovedVersion, addApprovedOracle, setPriceValidator)
// TODO: remove unused approvedTokens mapping or wire it up
// TODO: replace string reverts with custom errors
// TODO: check target.call return value in swap() (line 84)
// TODO: in submitOrder, transfer tokens before approving settlement (ordering)
// TODO: fix adapterRegsitry typo -> adapterRegistry
// TODO: ProtocolId in adapterRegistry
//
// TODO think: do we have a 2 step process for claiming? 
// TODO think: pressure test the design a bit more  
// TODO think: return values from adapters 
// TODO test: limit orders in general, cowswap full flow test (api?) can use 1inch
// TODO 
contract BoringSwapper is Auth {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;
        
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
    
    mapping(bytes32 routeId => bool approved) public approvedRoutes; //is this needed? annoying to auth (bad ux)
    mapping(bytes32 routeId => uint256 maxSlippageBps) public maxSlippageBpsPerRoute;
    mapping(uint8 protocolId => bool approved) public approvedProtocols;
    mapping(ERC20 token => mapping(address quoteAsset => address oracle)) public oracles; 
    
    /// @notice stores the current version this swapper subscribes to for a specific protocol
    mapping(uint8 protocolId => uint256 version) public versions;

    mapping(bytes32 hash => bool approvedOrder) public approvedOrders;
    uint256 public orders;

    AdapterRegistry public adapterRegsitry; 
    IPriceValidator public priceValidator;

    constructor(AdapterRegistry _adapterRegistry) Auth(address(0), Authority(address(0))) {
        adapterRegsitry = _adapterRegistry; 
    }
    
    function swap(SwapConfig calldata swapConfig) external { 

        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (approvedRoutes[key] == false) revert("not approved"); //TODO custom error
        if (approvedProtocols[swapConfig.protocolId] == false) revert("not approved");
        
        //get the correct adapter based on the version
        address adapter = adapterRegsitry.get(
            swapConfig.protocolId, 
            versions[swapConfig.protocolId]
        );  

        //append our data to the call + the length
        bytes memory appended = abi.encodePacked(swapConfig.swapData, abi.encode(swapConfig), uint256(swapConfig.swapData.length));
        (bytes memory result) = adapter.functionStaticCall(appended);

        //if we succeeded, decode the params we get back from the adapter
        (address target, uint256 amount) = abi.decode(result, (address, uint256));

        //snapshot the balance
        uint256 tokenBalanceBefore = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)); 
        
        //transfer assets from the vault to the swapper, approve target & execute
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), amount); 
        swapConfig.tokenRoute.tokenIn.approve(target, amount); 
        target.call(swapConfig.swapData); 
        
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

    function submitOrder(SwapConfig memory swapConfig) external {
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (approvedRoutes[key] == false) revert("not approved"); //TODO custom error
        if (approvedProtocols[swapConfig.protocolId] == false) revert("not approved");

        address adapter = adapterRegsitry.get(
            swapConfig.protocolId,
            versions[swapConfig.protocolId]
        ); 
        (address settlement, address inputToken, address outputToken, uint256 inputAmount, uint256 outputAmount) =
            IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        //check for limit order fat fingers
        IPriceValidator(priceValidator).validate(ERC20(inputToken), ERC20(outputToken), inputAmount, outputAmount, swapConfig.quoteAsset, swapConfig.slippageBps);
        bytes32 orderHash = keccak256(abi.encode(swapConfig, orders)); 
        approvedOrders[orderHash] = true; 

        //preapprove the settlement contract & pull funds from the vault
        swapConfig.tokenRoute.tokenIn.approve(settlement, inputAmount); 
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), inputAmount);

        orders += 1;

        //TODO emit event with data needed for signature building for strategist to reconstruct this for the _signature field
    }

    //TODO: finish implementation — revoke settlement approval, emit event
    function cancelOrder(SwapConfig memory swapConfig, uint256 orderId) external {
        bytes32 orderHash = keccak256(abi.encode(swapConfig, orderId));
        if (!approvedOrders[orderHash]) revert("order not found");
        approvedOrders[orderHash] = false;

        address adapter = adapterRegsitry.get(
            swapConfig.protocolId,
            versions[swapConfig.protocolId]
        );
        (address settlement, , , uint256 inputAmount, ) =
            IAdapter(adapter).verifyLimitOrder(swapConfig, address(this)); //also verifies receiver == vault

        swapConfig.tokenRoute.tokenIn.approve(settlement, 0);
        swapConfig.tokenRoute.tokenIn.safeTransfer(address(swapConfig.receiver), inputAmount);
    }
    
    //some way to clear hashes after approval (we cannot clear the state because isValidSignature must be a view function)
    //  leave state dangling, rely on protocol to handle (cow does this, not sure about others)
    //  change the flow so that swaps actually go here and strategists must call (reclaim()) to issue the funds back to the vault (terrible ux)
    //sweep() 

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
        (SwapConfig memory swapConfig, uint256 orderId) = abi.decode(_signature, (SwapConfig, uint256)); 
        bytes32 orderHash = keccak256(abi.encode(swapConfig, orderId));
        if (!approvedOrders[orderHash]) revert("trade not approved");

        return MAGIC_VALUE;
    }

    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) public pure returns (bytes32) {
        return keccak256(abi.encode(address(tokenIn), address(tokenOut)));
    }

    function getOracle(ERC20 token, address quoteAsset) external view returns (address) {
        return oracles[token][quoteAsset]; 
    }
}
