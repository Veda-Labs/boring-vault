// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MessageLib} from "src/base/Roles/CrossChain/MessageLib.sol";

library CrossChainTellerLib {
    using MessageLib for uint256;
    using MessageLib for MessageLib.Message;

    event MessageReceived(bytes32 indexed messageId, uint256 shareAmount, address indexed to);

    /**
     * @notice Burns shares from the sender and encodes the bridge message.
     * @param vault The BoringVault to burn shares from.
     * @param sender The address whose shares are burned.
     * @param shareAmount The number of shares to burn.
     * @param to The destination address on the remote chain.
     * @return message The packed uint256 message for the bridge.
     */
    function burnAndEncode(BoringVault vault, address sender, uint96 shareAmount, address to)
        external
        returns (uint256 message)
    {
        vault.exit(address(0), ERC20(address(0)), 0, sender, shareAmount);
        MessageLib.Message memory m = MessageLib.Message(shareAmount, to);
        message = m.messageToUint256();
    }

    /**
     * @notice Completes a received cross-chain message by minting shares.
     * @param vault The BoringVault to mint shares into.
     * @param messageId The bridge message ID.
     * @param message The packed uint256 message to decode.
     */
    function completeMessageReceive(BoringVault vault, bytes32 messageId, uint256 message) external {
        MessageLib.Message memory m = message.uint256ToMessage();
        vault.enter(address(0), ERC20(address(0)), 0, m.to, m.shareAmount);
        emit MessageReceived(messageId, m.shareAmount, m.to);
    }
}
