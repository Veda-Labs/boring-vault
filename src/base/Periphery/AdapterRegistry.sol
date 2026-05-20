// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract AdapterRegistry is Auth {

    //============================== Errors ===============================

    error AdapterRegistry__AlreadyRegistered();
    error AdapterRegistry__NotRegistered();
    error AdapterRegistry__NameRequired();

    //============================== State ===============================

    mapping(address adapter => bool registered) public registeredAdapters;
    mapping(address adapter => string name) public adapterName;
    address[] public adapters;

    constructor() Auth(msg.sender, Authority(address(0))) {}

    //============================== Functions ===============================

    /// @notice Register a new adapter with a name.
    function put(address adapter, string calldata name) external requiresAuth {
        if (registeredAdapters[adapter]) revert AdapterRegistry__AlreadyRegistered();
        if (bytes(name).length == 0) revert AdapterRegistry__NameRequired();
        registeredAdapters[adapter] = true;
        adapterName[adapter] = name;
        adapters.push(adapter);
    }

    /// @notice Deregister an adapter.
    function remove(address adapter) external requiresAuth {
        if (!registeredAdapters[adapter]) revert AdapterRegistry__NotRegistered();
        registeredAdapters[adapter] = false;

        uint256 len = adapters.length;
        for (uint256 i; i < len; i++) {
            if (adapters[i] == adapter) {
                adapters[i] = adapters[len - 1];
                adapters.pop();
                break;
            }
        }
    }

    /// @notice Returns all registered adapters and their names.
    function getAdapters() external view returns (address[] memory, string[] memory names) {
        uint256 len = adapters.length;
        names = new string[](len);
        for (uint256 i; i < len; i++) {
            names[i] = adapterName[adapters[i]];
        }
        return (adapters, names);
    }

    function version() external view returns (string memory) {
        return "v1";
    }
}
