// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol"; 
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";

contract AdapterRegistry is Auth {

    mapping(uint8 protocolId => mapping(uint256 version => address adapter)) public availableAdapters;
    mapping(uint8 protocolId => string name) public protocolName;
    mapping(string name => uint8 protocolId) public protocolId;
    uint8[] public protocolIds;

    constructor() Auth(address(0), Authority(address(0))) {}

    function get(uint8 _protocolId, uint256 version) external view returns (address) {
        return availableAdapters[_protocolId][version];
    }

    /// @notice Register an adapter. Sets the protocol name on first registration for a given protocolId.
    function put(uint8 _protocolId, address adapter, string calldata name) external {
        IAdapter newAdapter = IAdapter(adapter);
        uint256 version = newAdapter.version();
        if (availableAdapters[_protocolId][version] != address(0)) revert("adapter already registered");
        availableAdapters[_protocolId][version] = adapter;

        if (bytes(protocolName[_protocolId]).length == 0) {
            if (bytes(name).length == 0) revert("name required");
            protocolName[_protocolId] = name;
            protocolId[name] = _protocolId;
            protocolIds.push(_protocolId);
        }
    }

    /// @notice Register an adapter for an already-named protocol (version bump)
    function put(uint8 _protocolId, address adapter) external {
        if (bytes(protocolName[_protocolId]).length == 0) revert("protocol not registered");
        IAdapter newAdapter = IAdapter(adapter);
        uint256 version = newAdapter.version();
        if (availableAdapters[_protocolId][version] != address(0)) revert("adapter already registered");
        availableAdapters[_protocolId][version] = adapter;
    }

    function getProtocols() external view returns (uint8[] memory ids, string[] memory names) {
        ids = protocolIds;
        names = new string[](ids.length);
        for (uint256 i; i < ids.length; i++) {
            names[i] = protocolName[ids[i]];
        }
    }
}
