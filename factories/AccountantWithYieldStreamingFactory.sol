// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {AccountantWithYieldStreaming} from "../src/base/Roles/AccountantWithYieldStreaming.sol";
import {IFactory} from "./IFactory.sol";

contract AccountantWithYieldStreamingFactory is IFactory {
    bytes32 public immutable commitHash;
    string public version;

    constructor(bytes32 _commitHash, string memory _version) {
        commitHash = _commitHash;
        version = _version;
    }

    function creationCode() external pure returns (bytes memory) {
        return type(AccountantWithYieldStreaming).creationCode;
    }
}
