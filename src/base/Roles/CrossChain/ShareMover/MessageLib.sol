// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/**
 * @title MessageLib
 * @notice Library for encoding and decoding cross-chain share bridge messages
 * @dev Message format matches Solana codec for consistency:
 *      - recipient: bytes[0:32]  (32 bytes)
 *      - amount:    bytes[32:48] (16 bytes, u128 big-endian)
 *      Total: 48 bytes
 */
library MessageLib {
    // ========================================= CONSTANTS =========================================

    /// @notice Message size in bytes (32 + 16 = 48)
    uint256 public constant MESSAGE_SIZE = 48;

    /// @notice Offset where amount starts in the message
    uint256 private constant AMOUNT_OFFSET = 32;

    // ========================================= ERRORS =========================================

    /// @dev Thrown when message has invalid length
    error MessageLib__InvalidLength();
    /// @dev Thrown when arithmetic operation would overflow
    error MessageLib__ArithmeticOverflow();
    /// @dev Thrown when amount would become zero after decimal conversion (dust protection)
    error MessageLib__DustAmount();

    // ========================================= STRUCTS =========================================

    /**
     * @notice Cross-chain share bridge message structure
     * @dev Aligned with Solana codec format for consistency across chains
     * @param recipient The destination address (32-byte format, EVM addresses left-padded with zeros)
     * @param amount The amount of shares to transfer (u128 for up to 27 decimal precision)
     */
    struct Message {
        bytes32 recipient;    // 32 bytes - supports both Solana and padded EVM addresses
        uint128 amount;       // 16 bytes - supports up to 27 decimal places
    }

    // ========================================= ENCODING/DECODING =========================================

    /**
     * @notice Encodes a MessageLib into bytes following the Solana codec format
     * @dev Message layout (48 bytes total):
     *      - recipient: bytes[0:32]   (32 bytes)
     *      - amount:    bytes[32:48]  (16 bytes, u128 big-endian)
     * @param message The message to encode
     * @return data The encoded message as bytes
     */
    function encodeMessage(Message memory message) internal pure returns (bytes memory data) {
        data = new bytes(MESSAGE_SIZE);
        
        // Recipient (32 bytes) at offset 0
        assembly {
            mstore(add(data, 0x20), mload(add(message, 0x00)))
        }
        
        // Amount (16 bytes, big endian) at offset 32
        // Convert u128 to big-endian bytes16 by shifting left
        bytes16 amountBytes = bytes16(message.amount << 128);
        assembly {
            mstore(add(data, 0x40), amountBytes)
        }
    }

    /**
     * @notice Decodes bytes into a MessageLib following the Solana codec format
     * @dev Expects exactly MESSAGE_SIZE (48) bytes
     * @param data The encoded message bytes
     * @return message The decoded MessageLib
     */
    function decodeMessage(bytes memory data) internal pure returns (Message memory message) {
        if (data.length != MESSAGE_SIZE) {
            revert MessageLib__InvalidLength();
        }

        // Decode recipient (32 bytes) from offset 0
        assembly {
            mstore(add(message, 0x00), mload(add(data, 0x20)))
        }

        // Decode amount (16 bytes, big endian) from offset 32
        bytes16 amountBytes;
        assembly {
            amountBytes := mload(add(data, 0x40))
        }
        // Convert bytes16 to uint128 directly
        message.amount = uint128(bytes16(amountBytes));
    }

    // ========================================= DECIMAL CONVERSION =========================================

    /**
     * @notice Helper to convert amount between different decimal representations
     * @dev Reverts if arithmetic overflow would occur or result would be zero (dust protection)
     * @param amount The amount to convert
     * @param fromDecimals The source decimal places
     * @param toDecimals The target decimal places
     * @return convertedAmount The amount after decimal conversion
     */
    function convertAmountDecimals(
        uint128 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint128 convertedAmount) {
        if (fromDecimals == toDecimals) {
            return amount;
        }

        if (fromDecimals > toDecimals) {
            // Scale down
            uint256 divisor = 10 ** uint256(fromDecimals - toDecimals);
            convertedAmount = uint128(amount / divisor);
        } else {
            // Scale up
            uint256 multiplier = 10 ** uint256(toDecimals - fromDecimals);
            uint256 result = uint256(amount) * multiplier;
            
            // Check for overflow
            if (result > type(uint128).max) {
                revert MessageLib__ArithmeticOverflow();
            }
            
            convertedAmount = uint128(result);
        }

        // Dust protection: don't allow zero amounts after conversion
        if (convertedAmount == 0 && amount > 0) {
            revert MessageLib__DustAmount();
        }
    }

    // ========================================= ADDRESS HELPERS =========================================

    /**
     * @notice Validates if a 32-byte address is a correctly padded 20-byte EVM address
     * @dev EVM addresses should be left-padded with 12 zero bytes
     * @param addr The address to validate
     * @return valid True if the address is a valid padded EVM address
     */
    function isValidPaddedEvmAddress(bytes32 addr) internal pure returns (bool valid) {
        if (addr == bytes32(0)) return false;
        
        // Check that the first 12 bytes are all zeros (correct padding)
        for (uint256 i = 0; i < 12; i++) {
            if (addr[i] != 0) return false;
        }
        
        return true;
    }

    /**
     * @notice Converts a 20-byte EVM address to a 32-byte padded format
     * @param addr The EVM address to pad
     * @return paddedAddr The left-padded 32-byte address
     */
    function padEvmAddress(address addr) internal pure returns (bytes32 paddedAddr) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @notice Extracts a 20-byte EVM address from a 32-byte padded format
     * @param paddedAddr The padded 32-byte address
     * @return addr The extracted EVM address
     */
    function extractEvmAddress(bytes32 paddedAddr) internal pure returns (address addr) {
        return address(uint160(uint256(paddedAddr)));
    }
}