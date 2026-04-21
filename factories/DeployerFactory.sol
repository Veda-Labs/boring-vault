// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Deployer} from "../src/helper/Deployer.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {IFactory} from "./IFactory.sol";

contract DeployerFactory is IFactory {
    bytes32 public immutable commitHash;
    string public version;

    constructor(bytes32 _commitHash, string memory _version) {
        commitHash = _commitHash;
        version = _version;
    }

    function creationCode() external pure returns (bytes memory) {
        return type(Deployer).creationCode;
    }

    function createDeployer(Authority auth) external returns (address) {
        return address(new Deployer(msg.sender, auth));
    }
}
