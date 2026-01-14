// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/**
 * @title IHypeBridge
 * @notice Interface for the HYPE bridge contract on HyperEVM.
 * @dev Deployed at 0x2222222222222222222222222222222222222222 on HyperEVM.
 *      Send native ETH to this address to bridge HYPE to HyperCore.
 */
interface IHypeBridge {
    /**
     * @notice Emitted when HYPE is received for bridging to HyperCore.
     * @param user The address that sent the HYPE
     * @param amount The amount of HYPE sent
     */
    event Received(address indexed user, uint256 amount);
}
