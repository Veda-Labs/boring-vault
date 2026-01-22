// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/**
 * @title HyperliquidCoreWriterDecoderAndSanitizer
 * @notice Decoder and sanitizer for Hyperliquid CoreWriter interactions on HyperEVM.
 * @dev CoreWriter is deployed at 0x3333333333333333333333333333333333333333 on HyperEVM.
 *      It enables smart contracts to send transactions to HyperCore for perp trading,
 *      spot transfers, vault management, and staking.
 *
 *      Action encoding format:
 *      - Byte 0: Encoding version (currently 0x01)
 *      - Bytes 1-3: Action ID (big-endian uint24)
 *      - Remaining bytes: ABI-encoded action parameters
 *
 *      Action IDs (with types from official docs):
 *      - 1: Limit order (uint32 asset, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 encodedTif, uint128 cloid)
 *      - 2: Vault transfer (address vault, bool isDeposit, uint64 usd)
 *      - 3: Token delegate (address validator, uint64 wei, bool isUndelegate)
 *      - 4: Staking deposit (uint64 wei)
 *      - 5: Staking withdraw (uint64 wei)
 *      - 6: Spot send (address destination, uint64 token, uint64 wei)
 *      - 7: USD class transfer (uint64 ntl, bool toPerp)
 *      - 8: Finalize EVM contract (uint64 token, uint8 encodedVariant, uint64 createNonce)
 *      - 9: Add API wallet (address apiWallet, string name)
 *      - 10: Cancel order by oid (uint32 asset, uint64 oid)
 *      - 11: Cancel order by cloid (uint32 asset, uint128 cloid)
 *      - 12: Approve builder fee (uint64 maxFeeRate, address builder)
 *      - 13: Send asset (address destination, address subAccount, uint32 sourceDex, uint32 destDex, uint64 token, uint64 wei)
 *
 *      For ERC20 transfers to HyperCore, tokens are sent to system addresses starting with 0x20.
 *      For HYPE transfers to HyperCore, send native HYPE to 0x2222222222222222222222222222222222222222.
 */
contract HyperliquidCoreWriterDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error HyperliquidCoreWriterDecoderAndSanitizer__InvalidActionEncoding();

    //============================== CONSTANTS ===============================

    /// @notice CoreWriter contract address on HyperEVM
    address internal constant CORE_WRITER = 0x3333333333333333333333333333333333333333;

    /// @notice HYPE bridge address - send native HYPE here to transfer HYPE to HyperCore
    address internal constant HYPE_BRIDGE = 0x2222222222222222222222222222222222222222;

    /// @notice System address prefix for ERC20 transfers to HyperCore
    bytes1 internal constant SYSTEM_ADDRESS_PREFIX = 0x20;

    // Action IDs
    uint24 internal constant ACTION_LIMIT_ORDER = 1;
    uint24 internal constant ACTION_VAULT_TRANSFER = 2;
    uint24 internal constant ACTION_TOKEN_DELEGATE = 3;
    uint24 internal constant ACTION_STAKING_DEPOSIT = 4;
    uint24 internal constant ACTION_STAKING_WITHDRAW = 5;
    uint24 internal constant ACTION_SPOT_SEND = 6;
    uint24 internal constant ACTION_USD_CLASS_TRANSFER = 7;
    uint24 internal constant ACTION_ADD_API_WALLET = 9;
    uint24 internal constant ACTION_CANCEL_BY_OID = 10;
    uint24 internal constant ACTION_CANCEL_BY_CLOID = 11;
    uint24 internal constant ACTION_APPROVE_BUILDER_FEE = 12;
    uint24 internal constant ACTION_SEND_ASSET = 13;

    //============================== COREWRITER RAW ACTION ===============================

    /**
     * @notice Decode and sanitize sendRawAction call to CoreWriter.
     * @dev This is the low-level function that sends raw encoded actions.
     *      The data format is: [version(1)][actionId(3)][params(variable)]
     *      We extract addresses from the params based on the action ID.
     * @param data The raw encoded action data
     * @return addressesFound Packed addresses extracted from the action
     */
    function sendRawAction(bytes calldata data) external pure virtual returns (bytes memory addressesFound) {
        if (data.length < 4) revert HyperliquidCoreWriterDecoderAndSanitizer__InvalidActionEncoding();

        // Extract action ID from bytes 1-3 (big-endian)
        uint24 actionId = uint24(uint8(data[1])) << 16 | uint24(uint8(data[2])) << 8 | uint24(uint8(data[3]));

        // Encode actionId as first pseudo-address for Merkle tree validation
        address actionIdAddress = address(uint160(actionId));

        // Extract addresses and asset IDs based on action type
        if (actionId == ACTION_LIMIT_ORDER) {
            // Limit order: (uint32 asset, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 encodedTif, uint128 cloid)
            if (data.length >= 36) {
                uint32 asset = abi.decode(data[4:36], (uint32));
                addressesFound = abi.encodePacked(actionIdAddress, address(uint160(asset)));
            }
        } else if (actionId == ACTION_VAULT_TRANSFER) {
            // Vault transfer: (address vault, bool isDeposit, uint64 usd)
            if (data.length >= 36) {
                address vault = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(actionIdAddress, vault);
            }
        } else if (actionId == ACTION_TOKEN_DELEGATE) {
            // Token delegate: (address validator, uint64 wei, bool isUndelegate)
            if (data.length >= 36) {
                address validator = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(actionIdAddress, validator);
            }
        } else if (actionId == ACTION_STAKING_DEPOSIT) {
            // Staking deposit: (uint64 wei) - no addresses, just actionId
            addressesFound = abi.encodePacked(actionIdAddress);
        } else if (actionId == ACTION_STAKING_WITHDRAW) {
            // Staking withdraw: (uint64 wei) - no addresses, just actionId
            addressesFound = abi.encodePacked(actionIdAddress);
        } else if (actionId == ACTION_SPOT_SEND) {
            // Spot send: (address destination, uint64 token, uint64 wei)
            // ABI layout: [destination: 32 bytes][token: 32 bytes][wei: 32 bytes]
            if (data.length >= 68) {
                address destination = abi.decode(data[4:36], (address));
                uint64 token = abi.decode(data[36:68], (uint64));
                addressesFound = abi.encodePacked(actionIdAddress, destination, address(uint160(token)));
            }
        } else if (actionId == ACTION_USD_CLASS_TRANSFER) {
            // USD class transfer: (uint64 ntl, bool toPerp) - no addresses, just actionId
            addressesFound = abi.encodePacked(actionIdAddress);
        } else if (actionId == ACTION_ADD_API_WALLET) {
            // Add API wallet: (address apiWallet, bytes name)
            if (data.length >= 36) {
                address apiWallet = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(actionIdAddress, apiWallet);
            }
        } else if (actionId == ACTION_CANCEL_BY_OID) {
            // Cancel by OID: (uint32 asset, uint64 oid)
            if (data.length >= 36) {
                uint32 asset = abi.decode(data[4:36], (uint32));
                addressesFound = abi.encodePacked(actionIdAddress, address(uint160(asset)));
            }
        } else if (actionId == ACTION_CANCEL_BY_CLOID) {
            // Cancel by CLOID: (uint32 asset, uint128 cloid)
            if (data.length >= 36) {
                uint32 asset = abi.decode(data[4:36], (uint32));
                addressesFound = abi.encodePacked(actionIdAddress, address(uint160(asset)));
            }
        } else if (actionId == ACTION_APPROVE_BUILDER_FEE) {
            // Approve builder fee: (uint64 maxFeeRate, address builder)
            // Address is second param, starts at offset 4 + 32 = 36
            if (data.length >= 68) {
                address builder = abi.decode(data[36:68], (address));
                addressesFound = abi.encodePacked(actionIdAddress, builder);
            }
        } else if (actionId == ACTION_SEND_ASSET) {
            // Send asset: (address destination, address subAccount, uint32 sourceDex, uint32 destDex, uint64 token, uint64 wei)
            if (data.length >= 36) {
                address destination = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(actionIdAddress, destination);
            }
        }
        // Note: All known actions now return at least the actionId

        return addressesFound;
    }

    //============================== HYPE BRIDGE ===============================

    /**
     * @notice Bridge HYPE from HyperEVM to HyperCore.
     * @dev Send native ETH to 0x2222...2222 to bridge HYPE to the sender's HyperCore account.
     *      This is typically called via boringVault.manage() with value > 0.
     *      The receive() function at 0x2222...2222 emits Received(address user, uint256 amount).
     */
    function bridgeHypeToCore() external pure virtual returns (bytes memory addressesFound) {
        // No addresses to extract - the sender's address is used as the recipient on HyperCore
        return addressesFound;
    }

    //============================== USDC BRIDGE (CoreDepositWallet) ===============================

    /**
     * @notice Deposit native USDC to HyperCore via CoreDepositWallet.
     * @dev Native USDC on HyperEVM uses CoreDepositWallet for bridging to HyperCore.
     *      Flow: 1) approve USDC to CoreDepositWallet, 2) call deposit(amount, destinationDex)
     *      CoreDepositWallet address can be retrieved from spotMeta API (evmContract.address for token index 0)
     *      destinationDex: 0 = perps, 4294967295 (0xFFFFFFFF) = spot
     */
    function deposit(uint256, /*amount*/ uint32 /*destinationDex*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // No addresses to extract - deposits go to sender's HyperCore account
        return addressesFound;
    }
}
