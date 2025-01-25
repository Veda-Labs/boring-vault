// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

abstract contract EulerEVKDecoderAndSanitizer is BaseDecoderAndSanitizer, ERC4626DecoderAndSanitizer {
    function enableController(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function enableCollateral(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function disableController(address account) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(account);
    }
    
    //nothing to sanitize
    function disableController() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function disableCollateral(address account, address vault)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(account, vault);
    }

    function borrow(uint256, /*amount*/ address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver);
    }

    function repay(uint256, /*amount*/ address receiver) external pure virtual returns (bytes memory addressesFound) {
        return abi.encodePacked(receiver);
    }

    function repayWithShares(uint256, /*amount*/ address receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(receiver);
    }
}
