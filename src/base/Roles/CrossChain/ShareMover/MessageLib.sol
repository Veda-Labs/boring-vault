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
    /// @dev Thrown when address is invalid
    error MessageLib__InvalidAddress();

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

        assembly {
            // -------------------------------- recipient --------------------------------
            // The first 32 bytes store the recipient unmodified.
            mstore(add(data, 0x20), mload(message))

            // -------------------------------- amount ----------------------------------
            // Shift the 128-bit amount 128 bits to the left so that it occupies the
            // high-order 16 bytes of the 32-byte slot – this is the expected big-endian
            // representation.
            let shiftedAmount := shl(128, mload(add(message, 0x20)))
            mstore(add(data, 0x40), shiftedAmount)
        }
    }

    /**
     * @notice Decodes bytes into a MessageLib following the Solana codec format
     * @dev Expects exactly MESSAGE_SIZE (48) bytes
     * @param data The encoded message bytes
     * @return message The decoded MessageLib
     */
    function decodeMessage(bytes memory data) internal pure returns (Message memory message) {
        if (data.length != MESSAGE_SIZE) revert MessageLib__InvalidLength();

        assembly {
            // -------------------------------- recipient --------------------------------
            mstore(message, mload(add(data, 0x20)))

            // -------------------------------- amount ----------------------------------
            // Read the 32-byte word starting at offset 32, then shift right 128 bits so
            // that the high-order 16 bytes (big-endian) become the least-significant 16
            // bytes of the word, giving the original uint128 value.
            let word := mload(add(data, 0x40))
            mstore(add(message, 0x20), shr(128, word))
        }
    }

    // ========================================= DECIMAL CONVERSION =========================================

    /**
     * @notice Helper to convert amount between different decimal representations
     * @dev Reverts if arithmetic overflow would occur or result would be zero (dust protection)
     * @param amount The amount to convert (uint128 chosen so that scaling up by up to 1e9—18→27 decimals—never overflows)
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
    function isValidPaddedEvmAddress(bytes32 addr) internal pure returns (bool) {
        // high == 0  &&  low != 0
        return bytes12(addr) == bytes12(0) && uint160(uint256(addr)) != 0;
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
        if (!isValidPaddedEvmAddress(paddedAddr)) revert MessageLib__InvalidAddress();
        return address(uint160(uint256(paddedAddr)));
    }
}