// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {AddressToBytes32} from "src/helper/AddressToBytes32.sol"; 

contract M0Adapter is IAdapter {
    using AddressToBytes32 for bytes32;
    
    //============================== Errors ===============================
    
    error M0Adapter__CrossChainNotAllowed();
    error M0Adapter__PrivateOrdersNotAllowed();
    error M0Adapter__NotCancelFunction();
        
    //============================== Immutables ===============================
    
    address immutable orderBook;

    //============================== Constants ===============================
    
    //m0 doesn't have this so we can make our own
    //TODO also probably need a way for this not to be called via isValidSignature, though without approvals all you are getting back is a magic number, nothing really you can do with that?
    bytes32 constant ORDER_HASH = keccak256("not implemented");

    //============================== Constructor ===============================
    
    constructor(address _orderBook) {
        orderBook = _orderBook;
    }

    //============================== Limit Orders ===============================

    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address /*swapper*/)
        external
        view
        returns (OrderInfo memory)
    {
        //DecoderCustomTypes.GPv2OrderData memory order =
        //   abi.decode(swapConfig.swapData, (DecoderCustomTypes.GPv2OrderData));
        DecoderCustomTypes.OrderParams memory order =    
             abi.decode(swapConfig.swapData, (DecoderCustomTypes.OrderParams));
        
        if (ERC20(order.tokenIn) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();
        if (ERC20(order.tokenOut.toAddress()) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();
        if (order.recipient.toAddress() != address(swapConfig.receiver)) revert Adapter__ReceiverMismatch();
        if (order.destChainId != block.chainid) revert M0Adapter__CrossChainNotAllowed();
        if (order.solver != bytes32(0)) revert M0Adapter__PrivateOrdersNotAllowed();  
          

        return OrderInfo({
            approvalTarget: orderBook,
            cancelTarget: orderBook,
            inputToken: order.tokenIn,
            outputToken: tokenOut,
            inputAmount: order.amountIn,
            outputAmount: order.amountOut,
            protocolHash: ORDER_HASH,
            hook: orderBook,
            hookData: abi.encodeWithSignature("openOrder((uint32,uint32,address,bytes32,uint128,uint128,bytes32,bytes32))", swapConfig.swapData)
        });
    }
    
    // @dev In this adapter, you MUST pass the encoded function + params as the `cancelArgs`. 
    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address swapper, bytes memory cancelArgs)
        external
        view
        returns (address, bytes memory)
    {
        bytes4 selector = bytes4(cancelArgs);
        if (selector != bytes4(abi.encodeWithSignature("cancelOrder(bytes32,(uint16,bytes32,uint64,uint32,uint32,uint64,uint64,bytes32,bytes32,uint128,uint128,bytes32,bytes32))"))) revert M0Adapter__NotCancelFunction();
            

        if (orderData.amountIn
        //TODO implement the hash for the order, verify it matches here. We want to ensure that the order being cancelled is the one that was submitted so swapConfig.swapData and [4..]cancelArgs should match
    
        //validate the cancelArgs here, decode them to ensure we are decoding the proper types
        (, DecoderCustomTypes.OrderData memory orderData) = abi.decode(cancelArgs, (bytes32, DecoderCustomTypes.OrderData));
        if (ERC20(orderData.tokenIn.toAddress()) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();
        if (ERC20(orderData.tokenOut.toAddress()) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();
        
        return (orderBook, cancelArgs);
    }

    /// @dev `filledAmount` is also set to `type(uint256).max` by `invalidateOrder`. The swapper only
    ///      invalidates from inside `_cancelOrder` and queries `isFilled` BEFORE that call, so any
    ///      non-zero reading at this site must be a genuine fill. Partial fills are rejected upstream
    ///      in `verifyLimitOrder`.
    function filledAmount(ISwapperTypes.SwapConfig calldata swapConfig, address swapper)
        external
        view
        returns (uint256)
    {

    }

    function version() external pure returns (string memory) {
        return "v1";
    }
}

