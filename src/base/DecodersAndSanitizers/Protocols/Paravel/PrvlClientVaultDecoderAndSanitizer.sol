// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract PrvlClientVaultDecoderAndSanitizer is BaseDecoderAndSanitizer {
    address public boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    function bulkDeposit(
        address depositAsset,
        uint256,
        uint256,
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(depositAsset, to);
    }

    function bulkWithdraw(
        address depositAsset,
        uint256,
        uint256,
        address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(depositAsset, to);
    }
}
