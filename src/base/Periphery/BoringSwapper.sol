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

// TODO: emit events from submitOrder (with orderId for strategist), cancelOrder, sweep, addApprovedRoute, addApprovedProtocol, addApprovedOracle
// TODO: add requiresAuth to admin functions (addApprovedRoute, addApprovedProtocol, addApprovedVersion, addApprovedOracle, setPriceValidator, sweep)
// TODO: replace string reverts with custom errors

// TODO test: limit orders in general, cowswap full flow test (api?) can use 1inch
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

    struct OrderRecord {
        ERC20 tokenIn;
        address settlement;
        uint256 inputAmount;
        BoringVault receiver;
    }
    
    mapping(bytes32 routeId => bool approved) public approvedRoutes; //is this needed? annoying to auth (bad ux)
    mapping(bytes32 routeId => uint256 maxSlippageBps) public maxSlippageBpsPerRoute;
    mapping(uint8 protocolId => bool approved) public approvedProtocols;
    mapping(ERC20 token => mapping(address quoteAsset => address oracle)) public oracles; 
    
    /// @notice stores the current version this swapper subscribes to for a specific protocol
    mapping(uint8 protocolId => uint256 version) public versions;

    mapping(uint256 orderId => OrderRecord) public orderRecords;
    uint256 public orders;

    AdapterRegistry public adapterRegistry; 
    IPriceValidator public priceValidator;

    constructor(AdapterRegistry _adapterRegistry) Auth(address(0), Authority(address(0))) {
        adapterRegistry = _adapterRegistry; 
    }
    
    function swap(SwapConfig calldata swapConfig) external {
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (approvedRoutes[key] == false) revert("not approved"); //TODO custom error
        if (approvedProtocols[swapConfig.protocolId] == false) revert("not approved");

        address target;
        uint256 amount;
        {
            //get the correct adapter based on the version
            address adapter = adapterRegistry.get(
                swapConfig.protocolId,
                versions[swapConfig.protocolId]
            );

            //append our data to the call + the length
            bytes memory appended = abi.encodePacked(swapConfig.swapData, abi.encode(swapConfig), uint256(swapConfig.swapData.length));
            (bytes memory result) = adapter.functionStaticCall(appended);

            //if we succeeded, decode the params we get back from the adapter
            (target, amount) = abi.decode(result, (address, uint256));
        }

        //snapshot the balance
        uint256 tokenBalanceBefore = swapConfig.tokenRoute.tokenOut.balanceOf(address(this));

        //transfer assets from the vault to the swapper, approve target & execute
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), amount);
        swapConfig.tokenRoute.tokenIn.approve(target, amount);
        (bool success, ) = target.call(swapConfig.swapData);
        if (!success) revert("swap failed");

        uint256 tokenBalanceDelta = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)) - tokenBalanceBefore;

        //validate the price & slippage
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
        swapConfig.tokenRoute.tokenOut.safeTransfer(address(swapConfig.receiver), tokenBalanceDelta);

        //return any unspent tokenIn dust to the vault
        uint256 dust = swapConfig.tokenRoute.tokenIn.balanceOf(address(this));
        if (dust > 0) swapConfig.tokenRoute.tokenIn.safeTransfer(address(swapConfig.receiver), dust);
    }  

    function submitOrder(SwapConfig memory swapConfig) external {
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (approvedRoutes[key] == false) revert("not approved"); //TODO custom error
        if (approvedProtocols[swapConfig.protocolId] == false) revert("not approved");

        address adapter = adapterRegistry.get(
            swapConfig.protocolId,
            versions[swapConfig.protocolId]
        );
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        //check for limit order fat fingers
        IPriceValidator(priceValidator).validate(ERC20(info.inputToken), ERC20(info.outputToken), info.inputAmount, info.outputAmount, swapConfig.quoteAsset, swapConfig.slippageBps);

        uint256 orderId = orders;
        orderRecords[orderId] = OrderRecord({
            tokenIn: swapConfig.tokenRoute.tokenIn,
            settlement: info.settlement,
            inputAmount: info.inputAmount,
            receiver: swapConfig.receiver
        });

        //preapprove the settlement contract & pull funds from the vault
        swapConfig.tokenRoute.tokenIn.approve(info.settlement, info.inputAmount);
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), info.inputAmount);

        orders += 1;

        //TODO emit event with orderId for strategist
    }

    //TODO: emit event
    function cancelOrder(uint256 orderId) external {
        OrderRecord memory record = orderRecords[orderId];
        if (address(record.tokenIn) == address(0)) revert("order not found");

        delete orderRecords[orderId];

        record.tokenIn.approve(record.settlement, 0);
        uint256 balance = record.tokenIn.balanceOf(address(this));
        uint256 refund = balance < record.inputAmount ? balance : record.inputAmount;
        if (refund > 0) record.tokenIn.safeTransfer(address(record.receiver), refund);
    }

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
    
    /// @notice ERC-1271 — re-validates the order at fill time
    /// @param _hash the protocol's EIP-712 order digest
    /// @param _signature abi.encode(SwapConfig) — full config for re-validation
    function isValidSignature(bytes32 _hash, bytes memory _signature)
        external
        view
        returns (bytes4)
    {
        SwapConfig memory swapConfig = abi.decode(_signature, (SwapConfig));

        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (!approvedRoutes[key]) revert("route not approved");
        if (!approvedProtocols[swapConfig.protocolId]) revert("protocol not approved");

        address adapter = adapterRegistry.get(
            swapConfig.protocolId,
            versions[swapConfig.protocolId]
        );
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        if (info.protocolHash != _hash) revert("hash mismatch");

        IPriceValidator(priceValidator).validate(
            ERC20(info.inputToken),
            ERC20(info.outputToken),
            info.inputAmount,
            info.outputAmount,
            swapConfig.quoteAsset,
            swapConfig.slippageBps
        );

        return MAGIC_VALUE;
    }

    /// @notice Reclaim any token sitting on the swapper back to a vault
    function sweep(ERC20 token, BoringVault vault) external {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) token.safeTransfer(address(vault), balance);
    }

    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) public pure returns (bytes32) {
        return keccak256(abi.encode(address(tokenIn), address(tokenOut)));
    }

    function getOracle(ERC20 token, address quoteAsset) external view returns (address) {
        return oracles[token][quoteAsset]; 
    }
}
