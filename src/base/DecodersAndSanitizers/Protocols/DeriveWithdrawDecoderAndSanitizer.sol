// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";

/// @notice provides withdraw flow for boring vaults to use Derive (Basis) Vaults
contract DeriveWithdrawDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error DeriveDecoderAndSanitizer__OptionsLengthNonZero();
    error DeriveDecoderAndSanitizer__ExtraDataLengthNonZero();

    //============================== Deposits/Withdraws ===============================

    function bridge(
        address receiver_,
        uint256, /*amount_*/
        uint256, /*msgGasLimit_*/
        address connector_,
        bytes calldata extraData_,
        bytes calldata options_
    ) external pure virtual returns (bytes memory addressesFound) {
        if (options_.length > 0) revert DeriveDecoderAndSanitizer__OptionsLengthNonZero();
        if (extraData_.length > 0) revert DeriveDecoderAndSanitizer__ExtraDataLengthNonZero();
        addressesFound = abi.encodePacked(receiver_, connector_);
    }

    function withdrawToChain(
        address token,
        uint256, /*amount*/
        address recipient,
        address socketController,
        address connector,
        uint256 /*gasLimit*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(token, recipient, socketController, connector);
    }

    function withdrawFromAppChain(
        address receiver_,
        uint256, /*burnAmount_*/
        uint256, /*msgGasLimit_*/
        address connector_
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver_, connector_);
    }
}
