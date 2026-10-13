// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault-fixes@40627627d0e68e8a5361f82e6fddaecedd357876 — file:audit/0xmacro-veda-106.pdf
pragma solidity 0.8.21;

import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

/**
 * @title HastraPrimeDecoderAndSanitizer
 * @notice DecoderAndSanitizer for minting and redeeming Hastra PRIME against USDC, including the
 *         intermediate wYLDS step (ETH mainnet: wYLDS 0x6aD038cA6C04e885630851278ca0a856Ad9a66Cc,
 *         PRIME 0x19ebb35279A16207Ec4ba82799CC64715065F7F6).
 * @dev Mint path: USDC -> wYLDS via wYLDS.deposit/mint (wYLDS is a 1:1 ERC4626 over USDC), then
 *      wYLDS -> PRIME via PRIME.deposit/mint (PRIME is an ERC4626 over wYLDS priced by a NAV oracle).
 *      Redeem path: PRIME -> wYLDS via PRIME.redeem/withdraw, then wYLDS -> USDC in two steps:
 *      the vault calls wYLDS.requestRedeem(shares), which escrows the shares against msg.sender, and
 *      Hastra's REDEEM_OPERATOR_ROLE later calls completeRedeem(vault), which pushes USDC from the
 *      wYLDS redeemVault to the vault. cancelRedeem() returns escrowed shares to msg.sender.
 * @dev The ERC4626 functions are inherited unchanged and pack every receiver/owner into
 *      addressesFound, so the merkle leaf MUST pin each of them to the vault. requestRedeem and
 *      cancelRedeem take no address and act on msg.sender only, so there is nothing to sanitize.
 * @dev wYLDS.withdraw/redeem always revert ("Use requestRedeem/completeRedeem"); leaves for those
 *      selectors belong on PRIME only.
 * @dev Intentionally not supported:
 *      - completeRedeem(address): REDEEM_OPERATOR_ROLE only, never callable by the vault.
 *      - depositWithPermit(...): the permit leg is wrapped in try/catch and a BoringVault cannot
 *        produce a valid permit signature, so the call reduces to deposit with a pre-set approval.
 *      - claimRewards(uint256,uint256,bytes32[]): outside the mint/redeem scope.
 */
contract HastraPrimeDecoderAndSanitizer is ERC4626DecoderAndSanitizer {
    //============================== HASTRA wYLDS ===============================

    /// @notice Escrows wYLDS shares from msg.sender into a pending redemption.
    /// @dev The redemption is keyed to msg.sender (the vault) and completeRedeem pays that key, so
    ///      USDC can only be delivered to the vault.
    function requestRedeem(uint256) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    /// @notice Cancels msg.sender's pending redemption, returning the escrowed wYLDS to msg.sender.
    function cancelRedeem() external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
