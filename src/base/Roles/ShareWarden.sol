// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BeforeTransferHook} from "src/interfaces/BeforeTransferHook.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

interface SanctionsList {
    function isSanctioned(address addr) external view returns (bool);
}

contract ShareWarden is BeforeTransferHook, IPausable, Auth {
    // ========================================= STATE =========================================

    /**
     * @notice Used to pause calls to `beforeTransfer`.
     */
    bool public isPaused;

    /**
     * @notice Maps a vault to a teller.
     */
    mapping(address => address) public vaultToTeller;

    SanctionsList public ofacOracle;
    SanctionsList public vedaOracle;

    // =============================== EVENTS ===============================

    event Paused();
    event Unpaused();
    event VaultToTellerUpdated(address indexed vault, address indexed teller);
    event OFACOracleUpdated(address indexed oracle);
    event VedaOracleUpdated(address indexed oracle);

    // =============================== ERRORS ===============================

    error ShareWarden__Paused();
    error ShareWarden__OFACBlacklisted(address account);
    error ShareWarden__VedaBlacklisted(address account);

    // =============================== CONSTRUCTOR ===============================

    constructor(address _owner) Auth(_owner, Authority(address(0))) {}

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Pause this contract, which prevents future calls to `deposit` and `depositWithPermit`.
     * @dev Callable by MULTISIG_ROLE.
     */
     function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause this contract, which allows future calls to `deposit` and `depositWithPermit`.
     * @dev Callable by MULTISIG_ROLE.
     */
    function unpause() external requiresAuth {
        isPaused = false;
        emit Unpaused();
    }

    /**
     * @notice Update the teller for a vault.
     * @dev Callable by OWNER_ROLE.
     */
    function updateVaultToTeller(address vault, address teller) external requiresAuth {
        vaultToTeller[vault] = teller;
        emit VaultToTellerUpdated(vault, teller);
    }

    /**
     * @notice Update the OFAC oracle.
     * @dev Callable by OWNER_ROLE.
     */
    function updateOFACOracle(address oracle) external requiresAuth {
        ofacOracle = SanctionsList(oracle);
        emit OFACOracleUpdated(oracle);
    }

    /**
     * @notice Update the VEDA oracle.
     * @dev Callable by OWNER_ROLE.
     */
    function updateVedaOracle(address oracle) external requiresAuth {
        vedaOracle = SanctionsList(oracle);
        emit VedaOracleUpdated(oracle);
    }

    // ========================================= BeforeTransferHook FUNCTIONS =========================================

    function beforeTransfer(address from, address to, address operator) external view {
        if (isPaused) revert ShareWarden__Paused();

        _checkBlacklist(from, to, operator);
 
        if (vaultToTeller[msg.sender] != address(0)) {
            TellerWithMultiAssetSupport(vaultToTeller[msg.sender]).beforeTransfer(from, to, operator);
        }
    }

    function beforeTransfer(address from) external view {
        if (isPaused) revert ShareWarden__Paused();

        if (address(ofacOracle) != address(0) && ofacOracle.isSanctioned(from)) revert ShareWarden__OFACBlacklisted(from);
        if (address(vedaOracle) != address(0) && vedaOracle.isSanctioned(from)) revert ShareWarden__VedaBlacklisted(from);

        if (vaultToTeller[msg.sender] != address(0)) {
            TellerWithMultiAssetSupport(vaultToTeller[msg.sender]).beforeTransfer(from);
        }
    }

    function _checkBlacklist(address from, address to, address operator) internal view {
        if (address(ofacOracle) != address(0)) {
            if (ofacOracle.isSanctioned(from)) revert ShareWarden__OFACBlacklisted(from);
            if (ofacOracle.isSanctioned(to)) revert ShareWarden__OFACBlacklisted(to);
            if (ofacOracle.isSanctioned(operator)) revert ShareWarden__OFACBlacklisted(operator);
        }
        if (address(vedaOracle) != address(0)) {
            if (vedaOracle.isSanctioned(from)) revert ShareWarden__VedaBlacklisted(from);
            if (vedaOracle.isSanctioned(to)) revert ShareWarden__VedaBlacklisted(to);
            if (vedaOracle.isSanctioned(operator)) revert ShareWarden__VedaBlacklisted(operator);
        }
    }
}
