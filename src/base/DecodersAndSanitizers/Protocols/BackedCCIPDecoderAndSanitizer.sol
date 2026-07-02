// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

contract BackedCCIPDecoderAndSanitizer {
    //============================== BACKED CCIP BRIDGE ===============================

    // For bridging Backed xStocks through Backed's CCIP wrapper (BackedCCIPReceiver).
    // Example TX: https://etherscan.io/tx/0x8139ca0ac22f858b3142b25183af69532d22ee9765261b875c5d56ea51321bff
    //
    // `chainSpecificArgs` is ignored by the bridge for EVM destinations, and for SVM (Solana)
    // destinations it is abi.decoded as (uint64 accountIsWritableBitmap, bytes32[] accounts).
    // The accounts array controls which Solana accounts the CCIP message executes against
    // (including the recipient's token account), so every decoded value must be pinned in the
    // leaf, otherwise a malicious strategist could redirect the bridged tokens on Solana.
    // We decode the same way the bridge does and pin the decoded values; non-canonical
    // re-encodings of the same values are harmless because the bridge only consumes the
    // decoded values. For EVM destinations the leaf pins `chainSpecificArgs` as empty bytes.
    function send(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        uint256, /*amount*/
        bytes calldata chainSpecificArgs
    ) external pure virtual returns (bytes memory addressesFound) {
        // Merkle tree helper is designed to work with addresses, so cast the chain selector to
        // an address, then split each bytes32 into 2 addresses.
        addressesFound = abi.encodePacked(
            address(uint160(destinationChainSelector)),
            address(bytes20(bytes16(tokenReceiver))),
            address(bytes20(bytes16(tokenReceiver << 128))),
            token
        );

        if (chainSpecificArgs.length > 0) {
            (uint64 accountIsWritableBitmap, bytes32[] memory accounts) =
                abi.decode(chainSpecificArgs, (uint64, bytes32[]));

            addressesFound = abi.encodePacked(addressesFound, address(uint160(accountIsWritableBitmap)));
            for (uint256 i; i < accounts.length; ++i) {
                addressesFound = abi.encodePacked(
                    addressesFound, address(bytes20(bytes16(accounts[i]))), address(bytes20(bytes16(accounts[i] << 128)))
                );
            }
        }
    }
}
