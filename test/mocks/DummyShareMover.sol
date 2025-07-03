// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ShareMover} from "src/base/Roles/CrossChain/ShareMover/ShareMover.sol";
import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/**
 * @title DummyShareMover
 * @notice Minimal concrete ShareMover used only for unit testing the abstract logic.
 */
contract DummyShareMover is ShareMover {
    // Storage helpers for test introspection
    MessageLib.Message public lastMessage;
    uint32 public lastChainId;
    bytes public lastWildCard;
    address public lastFeeToken;

    constructor(address _vault) ShareMover(_vault) {}

    // ------------------------------------------------------------------------------------------
    // ShareMover overrides
    // ------------------------------------------------------------------------------------------

    function _sendMessage(
        MessageLib.Message memory message,
        uint32 chainId,
        bytes calldata bridgeWildCard,
        ERC20 feeToken
    ) internal override returns (bytes32 messageId) {
        lastMessage = message;
        lastChainId = chainId;
        lastWildCard = bridgeWildCard;
        lastFeeToken = address(feeToken);

        // Derive a pseudo-random message id for testing purposes
        messageId = keccak256(abi.encode(message.recipient, message.amount, chainId, bridgeWildCard, feeToken));
    }

    function _previewFee(
        MessageLib.Message memory, /*message*/
        uint32, /*chainId*/
        bytes calldata, /*bridgeWildCard*/
        ERC20 /*feeToken*/
    ) internal pure override returns (uint256 fee) {
        return 1 ether; // constant for easy assertions
    }
} 