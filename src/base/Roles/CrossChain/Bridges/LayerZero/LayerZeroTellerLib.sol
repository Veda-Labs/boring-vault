// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {OptionsBuilder} from "@oapp-auth/OptionsBuilder.sol";
import {MessagingFee} from "@oapp-auth/OAppAuth.sol";

library LayerZeroTellerLib {
    using OptionsBuilder for bytes;

    // ========================================= STRUCTS =========================================

    /**
     * @notice Stores information about a chain.
     * @dev Sender is stored in OAppAuthCore `peers` mapping.
     * @param allowMessagesFrom Whether to allow messages from this chain.
     * @param allowMessagesTo Whether to allow messages to this chain.
     * @param messageGasLimit The gas limit for messages to this chain.
     */
    struct Chain {
        bool allowMessagesFrom;
        bool allowMessagesTo;
        uint128 messageGasLimit;
    }

    //============================== ERRORS ===============================

    error LayerZeroTeller__MessagesNotAllowedFrom(uint256 chainSelector);
    error LayerZeroTeller__MessagesNotAllowedTo(uint256 chainSelector);
    error LayerZeroTeller__FeeExceedsMax(uint256 chainSelector, uint256 fee, uint256 maxFee);
    error LayerZeroTeller__BadFeeToken();
    error LayerZeroTeller__ZeroMessageGasLimit();

    //============================== EVENTS ===============================

    event ChainAdded(uint256 chainId, bool allowMessagesFrom, bool allowMessagesTo, address targetTeller);
    event ChainRemoved(uint256 chainId);
    event ChainStopMessagesFrom(uint256 chainId);
    event ChainStopMessagesTo(uint256 chainId);

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Adds a new chain configuration for cross-chain messaging.
     * @param idToChains Storage mapping of chain ID to Chain config.
     * @param chainId The LayerZero endpoint ID of the chain to add.
     * @param allowMessagesFrom Whether to accept inbound messages from this chain.
     * @param allowMessagesTo Whether to allow outbound messages to this chain.
     * @param targetTeller The address of the teller contract on the destination chain (emitted only).
     * @param messageGasLimit The gas limit for outbound messages to this chain.
     */
    function addChain(
        mapping(uint32 => Chain) storage idToChains,
        uint32 chainId,
        bool allowMessagesFrom,
        bool allowMessagesTo,
        address targetTeller,
        uint128 messageGasLimit
    ) external {
        if (allowMessagesTo && messageGasLimit == 0) {
            revert LayerZeroTeller__ZeroMessageGasLimit();
        }
        idToChains[chainId] = Chain(allowMessagesFrom, allowMessagesTo, messageGasLimit);
        emit ChainAdded(chainId, allowMessagesFrom, allowMessagesTo, targetTeller);
    }

    /**
     * @notice Removes a chain configuration, disabling all messaging to and from it.
     * @param idToChains Storage mapping of chain ID to Chain config.
     * @param chainId The LayerZero endpoint ID of the chain to remove.
     */
    function removeChain(mapping(uint32 => Chain) storage idToChains, uint32 chainId) external {
        delete idToChains[chainId];
        emit ChainRemoved(chainId);
    }

    /**
     * @notice Disables inbound messages from a chain without removing the full config.
     * @param idToChains Storage mapping of chain ID to Chain config.
     * @param chainId The LayerZero endpoint ID of the chain to stop receiving from.
     */
    function stopMessagesFromChain(mapping(uint32 => Chain) storage idToChains, uint32 chainId) external {
        idToChains[chainId].allowMessagesFrom = false;
        emit ChainStopMessagesFrom(chainId);
    }

    /**
     * @notice Disables outbound messages to a chain without removing the full config.
     * @param idToChains Storage mapping of chain ID to Chain config.
     * @param chainId The LayerZero endpoint ID of the chain to stop sending to.
     */
    function stopMessagesToChain(mapping(uint32 => Chain) storage idToChains, uint32 chainId) external {
        idToChains[chainId].allowMessagesTo = false;
        emit ChainStopMessagesTo(chainId);
    }

    // ========================================= BRIDGE HELPER FUNCTIONS =========================================

    /**
     * @notice Validates source chain allows messages and reverts if not.
     */
    function validateSourceChain(mapping(uint32 => Chain) storage idToChains, uint32 srcEid) external view {
        if (!idToChains[srcEid].allowMessagesFrom) {
            revert LayerZeroTeller__MessagesNotAllowedFrom(srcEid);
        }
    }

    /**
     * @notice Looks up destination chain, validates it allows messages, and builds the encoded message and LZ options.
     * @dev Combines chain lookup + validation + message building into a single DELEGATECALL.
     */
    function validateDestAndBuildMessage(
        mapping(uint32 => Chain) storage idToChains,
        uint32 destinationId,
        uint256 message
    ) external view returns (bytes memory m, bytes memory options) {
        Chain memory chain = idToChains[destinationId];
        if (!chain.allowMessagesTo) {
            revert LayerZeroTeller__MessagesNotAllowedTo(destinationId);
        }
        m = abi.encode(message);
        options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(chain.messageGasLimit, 0);
    }

    /**
     * @notice Validates fee token and checks that the fee does not exceed maxFee.
     * @dev Reverts if the fee token is invalid or the fee exceeds maxFee.
     */
    function validateFeeAndCheck(
        address feeToken,
        address nativeToken,
        address lzToken,
        uint32 destinationId,
        MessagingFee memory fee,
        uint256 maxFee
    ) external pure {
        if (feeToken == nativeToken) {
            if (fee.nativeFee > maxFee) {
                revert LayerZeroTeller__FeeExceedsMax(destinationId, fee.nativeFee, maxFee);
            }
        } else if (feeToken == lzToken) {
            if (fee.lzTokenFee > maxFee) {
                revert LayerZeroTeller__FeeExceedsMax(destinationId, fee.lzTokenFee, maxFee);
            }
        } else {
            revert LayerZeroTeller__BadFeeToken();
        }
    }

    /**
     * @notice Validates that the fee token is either the native token or the LZ token,
     *         and returns the appropriate fee amount.
     */
    function validateAndSelectFee(
        address feeToken,
        address nativeToken,
        address lzToken,
        MessagingFee memory messageFee
    ) external pure returns (uint256 fee) {
        if (feeToken != nativeToken && feeToken != lzToken) {
            revert LayerZeroTeller__BadFeeToken();
        }
        fee = feeToken == nativeToken ? messageFee.nativeFee : messageFee.lzTokenFee;
    }
}
