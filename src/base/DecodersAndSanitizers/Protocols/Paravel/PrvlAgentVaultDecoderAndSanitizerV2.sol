// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {PrvlAgentVaultDecoderAndSanitizer} from "./PrvlAgentVaultDecoderAndSanitizer.sol";

contract PrvlAgentVaultDecoderAndSanitizerV2 is PrvlAgentVaultDecoderAndSanitizer {
    // =============================== AAVE DEBT TOKEN ================================

    function approveDelegation(
        address delegatee,
        uint256 /*amount*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(delegatee);
    }

    // =============================== PRVL AAVE BORROW ADAPTOR ================================

    function supply(
        uint256, /*configId*/
        uint256, /*swapIn*/
        uint256, /*swapMinOut*/
        uint256 /*borrowAmount*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked();
    }

    function reducePosition(
        uint256, /*configId*/
        uint256, /*swapMinOut*/
        uint256, /*repayAmount*/
        uint256 /*withdrawAmount*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked();
    }

    function settle(
        uint256, /*configId*/
        uint256 /*swapMinOut*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked();
    }
}
