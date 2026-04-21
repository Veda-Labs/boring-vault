// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

interface IFactory {
    function creationCode() external pure returns (bytes memory);
    function commitHash() external view returns (bytes32);
    function version() external view returns (string memory);
}
