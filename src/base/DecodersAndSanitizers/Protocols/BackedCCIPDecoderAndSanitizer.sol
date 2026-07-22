// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

uint64 constant BACKED_CCIP_SOLANA_CHAIN_SELECTOR = 124615329519749607;
uint256 constant BACKED_CCIP_MAX_SVM_ACCOUNTS = 64;
uint256 constant BACKED_CCIP_MIN_SVM_ARGS_LENGTH = 128;
uint256 constant BACKED_CCIP_MAX_SVM_ARGS_LENGTH = 96 + 32 * BACKED_CCIP_MAX_SVM_ACCOUNTS;
bytes32 constant BACKED_CCIP_DRONE_TARGET_FLAG = keccak256(bytes("DroneLib.target"));

contract BackedCCIPDecoderAndSanitizer {
    error BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs();
    error BackedCCIPDecoderAndSanitizer__InvalidTokenReceiver();

    //============================== BACKED CCIP BRIDGE ===============================

    // For bridging Backed xStocks through Backed's CCIP wrapper (BackedCCIPReceiver).
    // Example TX: https://etherscan.io/tx/0x8139ca0ac22f858b3142b25183af69532d22ee9765261b875c5d56ea51321bff
    //
    // `chainSpecificArgs` is ignored by the bridge for EVM destinations, and for SVM (Solana)
    // destinations it is abi.decoded as (uint64 accountIsWritableBitmap, bytes32[] accounts).
    // The accounts array controls which Solana accounts the CCIP message executes against
    // (including the recipient's token account), so every decoded value must be pinned in the
    // leaf, otherwise a malicious strategist could redirect the bridged tokens on Solana.
    // Solana is identified by its CCIP chain selector, not by caller-controlled argument length.
    // SVM arguments must use the canonical abi.encode(bitmap, accounts) representation. For every
    // other destination selector the decoder uses the EVM shape and requires empty arguments.
    function send(
        uint64 destinationChainSelector,
        bytes32 tokenReceiver,
        address token,
        uint256, /*amount*/
        bytes calldata chainSpecificArgs
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        bool isSvmDestination = destinationChainSelector == BACKED_CCIP_SOLANA_CHAIN_SELECTOR;

        if (isSvmDestination) {
            // A canonical abi.encode(uint64, bytes32[]) value is 96 + 32 * accounts.length bytes.
            // Bound the byte length before abi.decode so a hostile array length cannot force an
            // unbounded memory allocation. At least one and at most 64 accounts are permitted.
            if (
                chainSpecificArgs.length < BACKED_CCIP_MIN_SVM_ARGS_LENGTH || chainSpecificArgs.length > BACKED_CCIP_MAX_SVM_ARGS_LENGTH
                    || chainSpecificArgs.length % 32 != 0
            ) {
                revert BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs();
            }
        } else {
            if (chainSpecificArgs.length != 0) {
                revert BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs();
            }
            // Backed truncates the receiver to its low 160 bits on destination EVMs.
            if (uint256(tokenReceiver) > type(uint160).max) {
                revert BackedCCIPDecoderAndSanitizer__InvalidTokenReceiver();
            }
        }

        if (tokenReceiver == bytes32(0)) {
            revert BackedCCIPDecoderAndSanitizer__InvalidTokenReceiver();
        }

        // Merkle tree helper is designed to work with addresses, so cast the chain selector to
        // an address, then split each bytes32 into 2 addresses.
        addressesFound = abi.encodePacked(
            address(uint160(destinationChainSelector)), address(bytes20(bytes16(tokenReceiver))), address(bytes20(bytes16(tokenReceiver << 128))), token
        );

        if (isSvmDestination) {
            (uint64 accountIsWritableBitmap, bytes32[] memory accounts) = abi.decode(chainSpecificArgs, (uint64, bytes32[]));

            if (
                accounts.length == 0 || accounts.length > BACKED_CCIP_MAX_SVM_ACCOUNTS
                    || (accounts.length < BACKED_CCIP_MAX_SVM_ACCOUNTS && accountIsWritableBitmap >> accounts.length != 0)
                    || keccak256(chainSpecificArgs) != keccak256(abi.encode(accountIsWritableBitmap, accounts))
            ) {
                revert BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs();
            }
            // ManagerWithMerkleVerification treats this exact final calldata word as Drone metadata
            // and appends another address to the decoder output before checking the leaf.
            if (accounts[accounts.length - 1] == BACKED_CCIP_DRONE_TARGET_FLAG) {
                revert BackedCCIPDecoderAndSanitizer__InvalidChainSpecificArgs();
            }

            addressesFound = abi.encodePacked(addressesFound, address(uint160(accountIsWritableBitmap)));
            for (uint256 i; i < accounts.length; ++i) {
                addressesFound = abi.encodePacked(addressesFound, address(bytes20(bytes16(accounts[i]))), address(bytes20(bytes16(accounts[i] << 128))));
            }
        }
    }
}
