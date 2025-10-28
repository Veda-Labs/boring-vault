// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BeforeTransferHook} from "src/interfaces/BeforeTransferHook.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ISanctionsList} from "src/interfaces/ISanctionsList.sol";

contract ShareWarden is BeforeTransferHook, IPausable, Auth {
    // ========================================= STRUCTS =========================================

    struct VaultData {
        address teller; // The teller for the vault.
        uint8[] listIds; // The blacklist IDs for the vault.
    }

    // ========================================= STATE =========================================

    /**
     * @notice Used to pause calls to `beforeTransfer`.
     */
    bool public isPaused;

    /**
     * @notice Maps a vault to its configuration data (teller and list IDs).
     */
    mapping(address => VaultData) internal vaultData;

    /**
     * @notice Maps a list ID to a mapping of address hashes to blacklisted status.
     */
    mapping(uint8 => mapping(bytes32 => bool)) internal listIdToBlacklisted;

    /**
     * @notice The SanctionsList oracle.
     */
    ISanctionsList public sanctionsList;

    uint8 public constant LIST_ID_SANCTIONS = type(uint8).max;

    // =============================== EVENTS ===============================

    event Paused();
    event Unpaused();
    event SanctionsListUpdated(address indexed sanctionsList);
    event VaultTellerUpdated(address indexed vault, address indexed teller);
    event VaultListIdsUpdated(address indexed vault, uint8[] listIds);

    // =============================== ERRORS ===============================

    error ShareWarden__Paused();
    error ShareWarden__SanctionsListBlacklisted(address account);
    error ShareWarden__Blacklisted(address account, uint8 listId);

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
     * @notice Update the SanctionsList oracle.
     * @dev Callable by OWNER_ROLE.
     */
    function updateSanctionsList(address _sanctionsList) external requiresAuth {
        sanctionsList = ISanctionsList(_sanctionsList);
        emit SanctionsListUpdated(_sanctionsList);
    }

    /**
     * @notice Update the teller for a vault.
     * @dev Callable by OWNER_ROLE.
     */
    function updateVaultTeller(address vault, address teller) external requiresAuth {
        vaultData[vault].teller = teller;
        emit VaultTellerUpdated(vault, teller);
    }

    /**
     * @notice Update the blacklist IDs for a vault.
     * @dev Callable by OWNER_ROLE.
     */
    function updateVaultListIds(address vault, uint8[] memory listIds) external requiresAuth {
        vaultData[vault].listIds = listIds;
        emit VaultListIdsUpdated(vault, listIds);
    }

    /**
     * @notice Blacklist an address for a list ID.
     * @dev Callable by OWNER_ROLE.
     */
    function updateBlacklist(uint8 listId, bytes32[] memory addressHashes, bool isBlacklisted) external requiresAuth {
        require(listId != LIST_ID_SANCTIONS, "SanctionsList list cannot be updated in this contract");
        for (uint256 i = 0; i < addressHashes.length; i++) {
            listIdToBlacklisted[listId][addressHashes[i]] = isBlacklisted;
        }
    }

    // =============================== VIEW FUNCTIONS ===============================

    function getVaultData(address vault) external view returns (address teller, uint8[] memory listIds) {
        return (vaultData[vault].teller, vaultData[vault].listIds);
    }

    // ========================================= BeforeTransferHook FUNCTIONS =========================================

    function beforeTransfer(address from, address to, address operator) external view {
        if (isPaused) revert ShareWarden__Paused();

        _checkBlacklist(from, to, operator);

        address teller = vaultData[msg.sender].teller;
        if (teller != address(0)) {
            TellerWithMultiAssetSupport(teller).beforeTransfer(from, to, operator);
        }
    }

    function beforeTransfer(address from) external view {
        if (isPaused) revert ShareWarden__Paused();

        _checkBlacklist(from);

        address teller = vaultData[msg.sender].teller;
        if (teller != address(0)) {
            TellerWithMultiAssetSupport(teller).beforeTransfer(from);
        }
    }

    function _checkBlacklist(address from) internal view {
        uint8[] memory listIds = vaultData[msg.sender].listIds;
        for (uint256 i = 0; i < listIds.length; i++) {
            uint8 listId = listIds[i];
            if (listIdToBlacklisted[listId][keccak256(abi.encodePacked(from))]) {
                revert ShareWarden__Blacklisted(from, listId);
            }
            if (listId == LIST_ID_SANCTIONS && address(sanctionsList) != address(0)) {
                if (sanctionsList.isSanctioned(from)) revert ShareWarden__SanctionsListBlacklisted(from);
            }
        }
    }

    function _checkBlacklist(address from, address to, address operator) internal view {
        uint8[] memory listIds = vaultData[msg.sender].listIds;
        for (uint256 i = 0; i < listIds.length; i++) {
            uint8 listId = listIds[i];
            if (listIdToBlacklisted[listId][keccak256(abi.encodePacked(from))]) {
                revert ShareWarden__Blacklisted(from, listId);
            }
            if (listIdToBlacklisted[listId][keccak256(abi.encodePacked(to))]) {
                revert ShareWarden__Blacklisted(to, listId);
            }
            if (listIdToBlacklisted[listId][keccak256(abi.encodePacked(operator))]) {
                revert ShareWarden__Blacklisted(operator, listId);
            }

            if (listId == LIST_ID_SANCTIONS && address(sanctionsList) != address(0)) {
                if (sanctionsList.isSanctioned(from)) revert ShareWarden__SanctionsListBlacklisted(from);
                if (sanctionsList.isSanctioned(to)) revert ShareWarden__SanctionsListBlacklisted(to);
                if (sanctionsList.isSanctioned(operator)) revert ShareWarden__SanctionsListBlacklisted(operator);
            }
        }
    }
}
