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
 *      Action IDs:
 *      - 1: Limit order (asset, isBuy, limitPx, sz, reduceOnly, encodedTif, cloid)
 *      - 2: Vault transfer (vault, isDeposit, usd)
 *      - 3: Token delegate (validator, wei, isUndelegate)
 *      - 4: Staking deposit (wei)
 *      - 5: Staking withdraw (wei)
 *      - 6: Spot send (destination, token, wei)
 *      - 7: USD class transfer (ntl, toPerp)
 *      - 9: Add API wallet (apiWallet, name)
 *      - 10: Cancel order by oid (asset, oid)
 *      - 11: Cancel order by cloid (asset, cloid)
 *      - 12: Approve builder fee (maxFeeRate, builder)
 *      - 13: Send asset (destination, subAccount, sourceDex, destDex, token, wei)
 *
 *      For ERC20 transfers to HyperCore, tokens are sent to system addresses starting with 0x20.
 *      For HYPE transfers to HyperCore, send native ETH to 0x2222222222222222222222222222222222222222.
 */
contract HyperliquidCoreWriterDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error HyperliquidCoreWriterDecoderAndSanitizer__InvalidActionEncoding();

    //============================== CONSTANTS ===============================

    /// @notice CoreWriter contract address on HyperEVM
    address internal constant CORE_WRITER = 0x3333333333333333333333333333333333333333;

    /// @notice HYPE bridge address - send native ETH here to transfer HYPE to HyperCore
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

        // Extract addresses based on action type
        if (actionId == ACTION_VAULT_TRANSFER) {
            // Vault transfer: (address vault, bool isDeposit, uint64 usd)
            if (data.length >= 36) {
                address vault = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(vault);
            }
        } else if (actionId == ACTION_TOKEN_DELEGATE) {
            // Token delegate: (address validator, uint64 wei, bool isUndelegate)
            if (data.length >= 36) {
                address validator = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(validator);
            }
        } else if (actionId == ACTION_SPOT_SEND) {
            // Spot send: (address destination, uint32 token, uint64 wei)
            if (data.length >= 36) {
                address destination = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(destination);
            }
        } else if (actionId == ACTION_ADD_API_WALLET) {
            // Add API wallet: (address apiWallet, bytes name)
            if (data.length >= 36) {
                address apiWallet = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(apiWallet);
            }
        } else if (actionId == ACTION_APPROVE_BUILDER_FEE) {
            // Approve builder fee: (uint64 maxFeeRate, address builder)
            // Address is second param, starts at offset 4 + 32 = 36
            if (data.length >= 68) {
                address builder = abi.decode(data[36:68], (address));
                addressesFound = abi.encodePacked(builder);
            }
        } else if (actionId == ACTION_SEND_ASSET) {
            // Send asset: (address destination, bytes1 subAccount, uint8 sourceDex, uint8 destDex, uint32 token, uint64 wei)
            if (data.length >= 36) {
                address destination = abi.decode(data[4:36], (address));
                addressesFound = abi.encodePacked(destination);
            }
        }
        // Actions 1, 4, 5, 7, 10, 11 have no addresses to extract

        return addressesFound;
    }

    //============================== PERP TRADING ===============================

    /**
     * @notice Place a limit order on HyperCore perps.
     * @dev Action ID 1: (uint32 asset, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 encodedTif, uint128 cloid)
     *      - asset: Perpetual asset index
     *      - isBuy: True for long, false for short
     *      - limitPx: Limit price (10^8 scaled)
     *      - sz: Size (10^8 scaled)
     *      - reduceOnly: Only reduce position
     *      - encodedTif: Time in force (1=Alo, 2=Gtc, 3=Ioc)
     *      - cloid: Client order ID (0 for none)
     */
    function placeLimitOrder(
        uint32, /*asset*/
        bool, /*isBuy*/
        uint64, /*limitPx*/
        uint64, /*sz*/
        bool, /*reduceOnly*/
        uint8, /*encodedTif*/
        uint128 /*cloid*/
    ) external pure virtual returns (bytes memory addressesFound) {
        // No addresses to extract - asset is an index, not an address
        return addressesFound;
    }

    /**
     * @notice Cancel an order by order ID on HyperCore.
     * @dev Action ID 10: (uint32 asset, uint64 oid)
     */
    function cancelOrderByOid(uint32, /*asset*/ uint64 /*oid*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // No addresses to extract
        return addressesFound;
    }

    /**
     * @notice Cancel an order by client order ID on HyperCore.
     * @dev Action ID 11: (uint32 asset, uint128 cloid)
     */
    function cancelOrderByCloid(uint32, /*asset*/ uint128 /*cloid*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // No addresses to extract
        return addressesFound;
    }

    /**
     * @notice Approve a builder to charge fees.
     * @dev Action ID 12: (uint64 maxFeeRate, address builder)
     * @param builder The builder address to approve
     */
    function approveBuilderFee(uint64, /*maxFeeRate*/ address builder)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(builder);
    }

    //============================== VAULT OPERATIONS ===============================

    /**
     * @notice Transfer funds to/from a HyperCore vault.
     * @dev Action ID 2: (address vault, bool isDeposit, uint64 usd)
     * @param vault The vault address on HyperCore
     */
    function vaultTransfer(address vault, bool, /*isDeposit*/ uint64 /*usd*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(vault);
    }

    //============================== STAKING ===============================

    /**
     * @notice Delegate/undelegate HYPE tokens to a validator for staking.
     * @dev Action ID 3: (address validator, uint64 wei, bool isUndelegate)
     * @param validator The validator address to delegate to
     */
    function tokenDelegate(address validator, uint64, /*wei*/ bool /*isUndelegate*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(validator);
    }

    /**
     * @notice Deposit HYPE into staking.
     * @dev Action ID 4: (uint64 wei)
     */
    function stakingDeposit(uint64 /*wei*/ ) external pure virtual returns (bytes memory addressesFound) {
        // No addresses to extract
        return addressesFound;
    }

    /**
     * @notice Withdraw HYPE from staking.
     * @dev Action ID 5: (uint64 wei)
     */
    function stakingWithdraw(uint64 /*wei*/ ) external pure virtual returns (bytes memory addressesFound) {
        // No addresses to extract
        return addressesFound;
    }

    //============================== SPOT TRANSFERS ===============================

    /**
     * @notice Send spot tokens to another address on HyperCore.
     * @dev Action ID 6: (address destination, uint32 token, uint64 wei)
     * @param destination Recipient address on HyperCore
     */
    function spotSend(address destination, uint32, /*token*/ uint64 /*wei*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(destination);
    }

    /**
     * @notice Send asset with full routing control.
     * @dev Action ID 13: (address destination, bytes1 subAccount, uint8 sourceDex, uint8 destDex, uint32 token, uint64 wei)
     * @param destination Recipient address on HyperCore
     */
    function sendAsset(
        address destination,
        bytes1, /*subAccount*/
        uint8, /*sourceDex*/
        uint8, /*destDex*/
        uint32, /*token*/
        uint64 /*wei*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(destination);
    }

    //============================== USD TRANSFERS ===============================

    /**
     * @notice Transfer USD between spot and perp accounts on HyperCore.
     * @dev Action ID 7: (uint64 ntl, bool toPerp)
     *      Moves USD balance between spot wallet and perp margin.
     */
    function usdClassTransfer(uint64, /*ntl*/ bool /*toPerp*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // No addresses to extract
        return addressesFound;
    }

    //============================== API WALLET ===============================

    /**
     * @notice Add an API wallet for trading.
     * @dev Action ID 9: (address apiWallet, bytes name)
     * @param apiWallet The API wallet address to add
     */
    function addApiWallet(address apiWallet, bytes calldata /*name*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(apiWallet);
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
