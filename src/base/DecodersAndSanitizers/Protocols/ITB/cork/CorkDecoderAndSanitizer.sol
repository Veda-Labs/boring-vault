// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

import '../common/ITBContractDecoderAndSanitizer.sol';

abstract contract CorkDecoderAndSanitizer is ITBContractDecoderAndSanitizer {
    type Id is bytes32;

    function updatePositionConfig(address _vault, Id, uint) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_vault);
    }

    function updateVaultSupervisor(address _vault_supervisor) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_vault_supervisor);
    }

    function update1InchRouter(address _router) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_router);
    }

    function depositLv(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function swapPaToRa(bytes memory, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function swapCtDsToRa(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function swapDsPaToRa(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function redeemExpiredCt(address _ct, uint, uint) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_ct);
    }

    function startWithdrawal(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function claimWithdrawal(bytes32) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeWithdrawal(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeNextWithdrawal(uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeNextWithdrawals(uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function overrideWithdrawalIndexes(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function assemble(uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function disassemble(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function fullDisassemble(uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function redeemExpiredCtByConfig(uint, uint) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
