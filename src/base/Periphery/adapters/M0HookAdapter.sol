// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {IM0OrderBook} from "src/interfaces/IM0OrderBook.sol";

contract M0Adapter is IAdapter {
    using AddressToBytes32Lib for bytes32;
    using AddressToBytes32Lib for address;
    
    //============================== Errors ===============================
    
    error M0Adapter__CrossChainNotAllowed();
    error M0Adapter__PrivateOrdersNotAllowed();
    error M0Adapter__NotCancelFunction();
    error M0Adapter__OrderIdMismatch();
        
    //============================== Immutables ===============================
    
    address immutable orderBook;

    //============================== Constructor ===============================
    
    constructor(address _orderBook) {
        orderBook = _orderBook;
    }

    //============================== Limit Orders ===============================

    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address swapper)
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

        bytes32 m0OrderId = IM0OrderBook(orderBook).getOrderId(
            DecoderCustomTypes.OrderData({
                version: IM0OrderBook(orderBook).VERSION(),
                sender: swapper.toBytes32(),
                nonce: IM0OrderBook(orderBook).getSenderNonce(swapper),
                originChainId: uint32(block.chainid),
                destChainId: order.destChainId,
                createdAt: uint64(block.timestamp),
                fillDeadline: order.fillDeadline,
                tokenIn: order.tokenIn.toBytes32(),
                tokenOut: order.tokenOut,
                amountIn: order.amountIn,
                amountOut: order.amountOut,
                recipient: order.recipient,
                solver: order.solver
            })
        );

        return OrderInfo({
            approvalTarget: orderBook,
            cancelTarget: orderBook,
            inputToken: order.tokenIn,
            outputToken: order.tokenOut.toAddress(),
            inputAmount: order.amountIn,
            outputAmount: order.amountOut,
            protocolHash: keccak256(swapConfig.swapData), //hash the swapData since m0 doesn't use a domain separator pattern
            hook: orderBook,
            hookData: abi.encodeWithSignature("openOrder((uint32,uint32,address,bytes32,uint128,uint128,bytes32,bytes32))", order),
            context: abi.encode(m0OrderId)
        });
    }
    
    // @dev In this adapter, you MUST pass the encoded function + params as the `cancelArgs`. 
    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata /*swapConfig*/, address /*swapper*/, bytes calldata cancelArgs, bytes calldata context)
        external
        view
        returns (address, bytes memory)
    {
        bytes4 selector = bytes4(cancelArgs);
        if (selector != bytes4(abi.encodeWithSignature("cancelOrder(bytes32,(uint16,bytes32,uint64,uint32,uint32,uint64,uint64,bytes32,bytes32,uint128,uint128,bytes32,bytes32))"))) revert M0Adapter__NotCancelFunction();
        
        bytes32 expectedOrderId = abi.decode(context, (bytes32));
        (bytes32 decodedId, ) = abi.decode(cancelArgs[4:], (bytes32, DecoderCustomTypes.OrderData));
        if (decodedId != expectedOrderId) revert M0Adapter__OrderIdMismatch();
        
        return (orderBook, cancelArgs);
    }

    function filledAmount(ISwapperTypes.SwapConfig calldata /*swapConfig*/, address /*swapper*/, bytes calldata context)
        external
        view
        returns (uint256)
    {
        bytes32 orderId = abi.decode(context, (bytes32));
        IM0OrderBook.FilledAmounts memory filledAmounts = IM0OrderBook(orderBook).getFilledAmounts(orderId);
        return filledAmounts.amountInReleased;
    }

    function version() external pure returns (string memory) {
        return "v1";
    }
}

