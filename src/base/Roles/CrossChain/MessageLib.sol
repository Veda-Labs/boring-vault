// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity >=0.8.0;

library MessageLib {
    error MessageLib__ShareAmountOverflow();

    uint256 internal constant MAX_SHARE_AMOUNT = type(uint96).max;

    /**
     * @notice Messages are transferred between chains as uint256
     *         The first 96 bits are the share amount.
     *         The remaining 160 bits are the address to send the shares to.
     * @dev Using a uint256 was chosen because most bridging protocols charge based off the number of
     *      bytes sent, and packing a uint256 in this way caps it at 32 bytes.
     */
    struct Message {
        uint256 shareAmount; // The amount of shares to bridge.
        address to;
    }

    /**
     * @notice Extracts a Message from a uint256.
     */
    function uint256ToMessage(uint256 b) internal pure returns (Message memory m) {
        m.shareAmount = uint96(b >> 160);
        m.to = address(uint160(b));
    }

    /**
     * @notice Packs a Message into a uint256.
     */
    function messageToUint256(Message memory m) internal pure returns (uint256 b) {
        if (m.shareAmount > MAX_SHARE_AMOUNT) revert MessageLib__ShareAmountOverflow();

        b |= m.shareAmount << 160;
        b |= uint160(m.to);
    }
}
