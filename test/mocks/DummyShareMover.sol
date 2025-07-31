// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ShareMover} from "src/base/Roles/CrossChain/ShareMover/ShareMover.sol";
import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";

/**
 * @title DummyShareMover
 * @notice Minimal concrete ShareMover used only for unit testing the abstract logic.
 */
contract DummyShareMover is ShareMover {
    // Storage helpers for test introspection
    MessageLib.Message public lastMessage;
    bytes public lastWildCard;

    uint256 public immutable feeQuote;

    constructor(address _owner, address _authority, address _vault, uint256 _fee) ShareMover(_owner, _authority, _vault) {
        feeQuote = _fee;
    }

    // ------------------------------------------------------------------------------------------
    // ShareMover overrides
    // ------------------------------------------------------------------------------------------

    function _sendMessage(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) internal override returns (bytes32 messageId, uint32) {
        // Record message for introspection
        lastMessage = MessageLib.Message({recipient: to, amount: uint128(shareAmount)});
        lastWildCard = bridgeWildCard;

        // Return dummy id & chainId=0 (these aren’t used in unit tests)
        messageId = keccak256(abi.encodePacked(to, shareAmount, bridgeWildCard));
        return (messageId, 0);
    }

    function _previewFee(
        uint96, /*shareAmount*/
        bytes32, /*to*/
        bytes calldata /*bridgeWildCard*/
    ) internal view override returns (uint256 fee) {
        return feeQuote;
    }
} 