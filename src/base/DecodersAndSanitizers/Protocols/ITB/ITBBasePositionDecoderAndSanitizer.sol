// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

contract ITBBasePositionDecoderAndSanitizer {
    function approve(address spender, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }

    function transfer(address _to, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_to);
    }

    function removeExecutor(
        address /*_executor*/
    )
        external
        pure
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdraw(
        address,
        /*_asset_address*/
        uint256
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdrawAll(
        address /*_asset_address*/
    )
        external
        pure
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function approveToken(address _token, address _guy, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_token, _guy);
    }

    function revokeToken(address _token, address _guy) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_token, _guy);
    }

    function acceptOwnership() external pure returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
