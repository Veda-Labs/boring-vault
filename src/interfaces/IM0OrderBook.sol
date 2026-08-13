// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

interface IM0OrderBook {

    enum OrderStatus { DoesNotExist, Created, Cancelled, Completed }

    struct Order {
        OrderStatus status; // slot 1: 1 +
        uint16 version; //             2 +
        address sender; //             20 +
        uint64 nonce; //               8 = 31 bytes
        uint32 destChainId; // slot 2: 4 +
        uint32 createdAt; //           4 +
        uint32 fillDeadline; //        4 +
        address tokenIn; //            20 = 32 bytes
        bytes32 tokenOut; //   slot 3
        uint128 amountIn; //   slot 4: 16 +
        uint128 amountOut; //          16 = 32 bytes
        bytes32 recipient; //  slot 5
        bytes32 solver; //     slot 6
    }

    struct OrderData {
        uint16 version;
        bytes32 sender;
        uint64 nonce;
        uint32 originChainId;
        uint32 destChainId;
        uint64 createdAt;
        uint64 fillDeadline;
        bytes32 tokenIn;
        bytes32 tokenOut;
        uint128 amountIn;
        uint128 amountOut;
        bytes32 recipient;
        bytes32 solver;
    }

    struct FilledAmounts {
        uint128 amountInRefunded;
        uint128 amountInReleased;
        uint128 amountOutFilled;
    }

    struct FillParams {
        uint128 amountOutToFill;
        bytes32 originRecipient;
        bytes32 refundAddress;
    }

    function VERSION() external view returns (uint16);
    function getSenderNonce(address sender) external view returns (uint64);
    function getOrderId(DecoderCustomTypes.OrderData memory orderData) external pure returns (bytes32);
    function getOrderData(bytes32 orderId) external view returns (DecoderCustomTypes.OrderData memory);
    function getOrder(bytes32 orderId) external view returns (Order memory);
    function getFilledAmounts(bytes32 orderId) external view returns (FilledAmounts memory);
    function fillOrder(
        bytes32 orderId_,
        DecoderCustomTypes.OrderData calldata orderData_,
        FillParams calldata fillerParams_
    ) external payable returns (bytes32 messageId_);
}
