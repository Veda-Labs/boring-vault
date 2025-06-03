/* SPDX-License-Identifier: UNLICENSED */
pragma solidity ^0.8.0;

import "../common/ITBContractDecoderAndSanitizer.sol";

contract CorkDecoderAndSanitizer is ITBContractDecoderAndSanitizer {
    type Id is bytes32;

    function updatePositionConfig(address _vault, Id, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_vault);
    }

    function updateVaultSupervisor(address _vault_supervisor) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_vault_supervisor);
    }

    function update1InchRouter(address _router) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_router);
    }

    function depositLv(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function swapPaToRa(bytes memory, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function swapCtDsToRa(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function swapDsPaToRa(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function redeemExpiredCt(address _ct, uint256, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_ct);
    }

    function startWithdrawal(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function claimWithdrawal(bytes32) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeWithdrawal(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeNextWithdrawal(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function completeNextWithdrawals(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function overrideWithdrawalIndexes(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function assemble(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function disassemble(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function fullDisassemble(uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function redeemExpiredCtByConfig(uint256, uint256) external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
