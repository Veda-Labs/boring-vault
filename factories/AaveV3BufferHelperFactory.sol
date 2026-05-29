// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {AaveV3BufferHelper} from "../src/base/Roles/AaveV3BufferHelper.sol";
import {IFactory} from "./IFactory.sol";

contract AaveV3BufferHelperFactory is IFactory {
    bytes32 public immutable commitHash;
    string public version;

    constructor(bytes32 _commitHash, string memory _version) {
        commitHash = _commitHash;
        version = _version;
    }

    function creationCode() external pure returns (bytes memory) {
        return type(AaveV3BufferHelper).creationCode;
    }
}
