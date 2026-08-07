// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

/**
 * @title MorphoMidnightDecoderAndSanitizer
 * @notice DecoderAndSanitizer for Morpho Midnight, Morpho's fixed-rate, fixed-maturity,
 *         intent-based lending singleton.
 * @dev Market pinning: instead of flattening the nested dynamic Market struct (up to 128
 *      collaterals) into leaf addresses, the market is pinned as a single address — the low
 *      160 bits of the Midnight market id. Per Midnight's IdLib, the id is the CREATE2 address
 *      (deployer = market.midnight, salt = 0) of the SSTORE2 contract whose creation code is
 *      SSTORE2_PREFIX ++ abi.encode(market), so it commits to every market field (chainId,
 *      midnight, loanToken, all collateralParams incl. oracles, maturity, rcfThreshold,
 *      enterGate, liquidatorGate) with standard address collision resistance.
 * @dev Taker-side callbacks are rejected so the vault itself is always payer (as buyer) and
 *      the pinned receiver receives (as seller). Maker-flow functions (setIsAuthorized,
 *      setConsumed, SetterRatifier.setIsRootRatified) are intentionally NOT supported: making
 *      offers requires ratifying opaque bytes32 offer-tree roots whose contents a leaf cannot
 *      inspect.
 * @dev multicall and flashLoan are intentionally not supported.
 */
contract MorphoMidnightDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error MorphoMidnightDecoderAndSanitizer__CallbackNotSupported();
    error MorphoMidnightDecoderAndSanitizer__OvercastUint160();

    //============================== MORPHO MIDNIGHT ===============================

    /// @notice Trade credit/debt units against a maker's ratified offer.
    /// @dev Vault as buyer (offer.buy = false, lending): pays loanToken, receiverIfTakerIsSeller
    ///      must be zero (enforced by Midnight). Vault as seller (offer.buy = true, exiting credit
    ///      or borrowing): receives loanToken at receiverIfTakerIsSeller, which the leaf pins.
    /// @dev offer.buy is pinned as address(1)/address(0) so a leaf commits to the trade direction
    ///      directly instead of relying on Midnight's unused-receiver-must-be-zero check.
    function take(
        DecoderCustomTypes.MidnightOffer calldata offer,
        bytes calldata, /*ratifierData*/
        uint256, /*units*/
        address taker,
        address receiverIfTakerIsSeller,
        address takerCallback,
        bytes calldata takerCallbackData
    ) external pure virtual returns (bytes memory addressesFound) {
        // Sanitize raw data
        if (takerCallback != address(0) || takerCallbackData.length > 0) {
            revert MorphoMidnightDecoderAndSanitizer__CallbackNotSupported();
        }
        // Return addresses found
        addressesFound = abi.encodePacked(
            _getMidnightMarketId(offer.market),
            address(uint160(offer.buy ? 1 : 0)),
            offer.maker,
            offer.callback,
            offer.receiverIfMakerIsSeller,
            offer.ratifier,
            taker,
            receiverIfTakerIsSeller
        );
    }

    /// @notice Redeem credit units 1:1 for loanToken, capped by the market's withdrawable amount.
    function withdraw(DecoderCustomTypes.MidnightMarket calldata market, uint256, address onBehalf, address receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_getMidnightMarketId(market), onBehalf, receiver);
    }

    /// @notice Repay debt units; loanToken is pulled from the caller (vault) since callbacks are rejected.
    function repay(
        DecoderCustomTypes.MidnightMarket calldata market,
        uint256, /*units*/
        address onBehalf,
        address callback,
        bytes calldata data
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Sanitize raw data
        if (callback != address(0) || data.length > 0) {
            revert MorphoMidnightDecoderAndSanitizer__CallbackNotSupported();
        }
        // Return addresses found
        addressesFound = abi.encodePacked(_getMidnightMarketId(market), onBehalf);
    }

    /// @notice Supply collateral; the token at market.collateralParams[collateralIndex] is pulled from the caller.
    function supplyCollateral(
        DecoderCustomTypes.MidnightMarket calldata market,
        uint256 collateralIndex,
        uint256, /*assets*/
        address onBehalf
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (collateralIndex > type(uint160).max) revert MorphoMidnightDecoderAndSanitizer__OvercastUint160();

        addressesFound = abi.encodePacked(_getMidnightMarketId(market), address(uint160(collateralIndex)), onBehalf);
    }

    /// @notice Withdraw collateral to receiver (health-checked on-chain if debt remains).
    function withdrawCollateral(
        DecoderCustomTypes.MidnightMarket calldata market,
        uint256 collateralIndex,
        uint256, /*assets*/
        address onBehalf,
        address receiver
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (collateralIndex > type(uint160).max) revert MorphoMidnightDecoderAndSanitizer__OvercastUint160();

        addressesFound = abi.encodePacked(_getMidnightMarketId(market), address(uint160(collateralIndex)), onBehalf, receiver);
    }

    /// @notice Permissionless bookkeeping: applies pending bad-debt slashing and fee accrual to a position.
    function updatePosition(DecoderCustomTypes.MidnightMarket calldata market, address user) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_getMidnightMarketId(market), user);
    }

    //============================== INTERNAL ===============================

    /// @dev Mirrors Midnight's IdLib.toId: keccak256(0xff ++ market.midnight ++ uint256(0) ++
    ///      keccak256(SSTORE2_PREFIX ++ abi.encode(market))). Midnight stores the market data at
    ///      the address given by the last 20 bytes of the id, which is exactly what we pin.
    function _getMidnightMarketId(DecoderCustomTypes.MidnightMarket calldata market) internal pure returns (address) {
        bytes32 id =
            keccak256(abi.encodePacked(uint8(0xff), market.midnight, uint256(0), keccak256(abi.encodePacked(hex"600b380380600b5f395ff3", abi.encode(market)))));
        return address(uint160(uint256(id)));
    }
}
