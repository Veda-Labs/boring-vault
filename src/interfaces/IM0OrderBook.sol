// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

interface IM0OrderBook {
    struct FilledAmounts {
        uint128 amountOutFilled;
        uint128 amountInReleased;
        uint128 amountInRefunded;
    }

    function VERSION() external view returns (uint16);
    function getSenderNonce(address sender) external view returns (uint64);
    function getOrderId(DecoderCustomTypes.OrderData memory orderData) external pure returns (bytes32);
    function getFilledAmounts(bytes32 orderId) external view returns (FilledAmounts memory);
}
