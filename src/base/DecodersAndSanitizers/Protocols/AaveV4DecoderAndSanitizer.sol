// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

contract AaveV4DecoderAndSanitizer {
    //============================== ERRORS ===============================

    error AaveV4DecoderAndSanitizer__InvalidReserveId();

    //============================== AAVEV4 ===============================
    // Aave V4 spokes identify reserves with a per-spoke uint256 reserveId instead of the
    // underlying asset address. The reserveId is cast to an address and packed into
    // addressesFound so each merkle leaf pins the exact (spoke, reserveId) pair; reserveIds
    // that do not fit in 160 bits are rejected so the cast cannot alias two ids onto one leaf.
    // Withdraw and borrow always send funds to msg.sender (the vault); onBehalfOf is the
    // position owner being debited/credited. SECURITY: every reserve function packs onBehalfOf
    // into addressesFound, so the merkle leaf MUST pin it to the vault. This argument governs whose
    // position is touched and, for withdraw/borrow, coincides with the account whose funds move; a
    // leaf that left it unpinned (or pinned to a non-vault address) would let value leave the vault.
    // Aave V4 has no onchain rewards controller (incentives accrue offchain), so unlike the V3
    // decoder there is no claim function to decode.

    function supply(
        uint256 reserveId,
        uint256,
        /*amount*/
        address onBehalfOf
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_sanitizeReserveId(reserveId), onBehalfOf);
    }

    function withdraw(
        uint256 reserveId,
        uint256,
        /*amount*/
        address onBehalfOf
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_sanitizeReserveId(reserveId), onBehalfOf);
    }

    function borrow(
        uint256 reserveId,
        uint256,
        /*amount*/
        address onBehalfOf
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_sanitizeReserveId(reserveId), onBehalfOf);
    }

    function repay(
        uint256 reserveId,
        uint256,
        /*amount*/
        address onBehalfOf
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_sanitizeReserveId(reserveId), onBehalfOf);
    }

    function setUsingAsCollateral(
        uint256 reserveId,
        bool,
        /*usingAsCollateral*/
        address onBehalfOf
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_sanitizeReserveId(reserveId), onBehalfOf);
    }

    function updateUserRiskPremium(address onBehalfOf) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(onBehalfOf);
    }

    function updateUserDynamicConfig(address onBehalfOf) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(onBehalfOf);
    }

    // NOTE: setUserPositionManager(address,bool) is deliberately NOT decodable. An approved
    // position manager can call withdraw/borrow with onBehalfOf = vault and receives the funds
    // itself (V4 pays msg.sender), bypassing merkle verification entirely. Add it only with a
    // dedicated helper, test coverage, and the approve flag pinned.

    function _sanitizeReserveId(uint256 reserveId) internal pure returns (address) {
        if (reserveId > type(uint160).max) revert AaveV4DecoderAndSanitizer__InvalidReserveId();
        return address(uint160(reserveId));
    }
}
