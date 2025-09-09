// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity >=0.8.0;

library AddressToBytes32Lib {
    function toBytes32(address addressValue) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addressValue)));
    }

    function toAddress(bytes32 bytes32Value) internal pure returns (address) {
        return address(bytes20(bytes32Value << 96));
    }
}
