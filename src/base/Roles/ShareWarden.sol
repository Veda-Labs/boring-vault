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
        uint8 listBitmap; // Bitmap representing up to 8 blacklist IDs for the vault.
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

    uint8 public constant LIST_ID_SANCTIONS = 1 << 7;

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
    error ShareWarden__InvalidListId(uint8 listId);

    // =============================== CONSTRUCTOR ===============================

    constructor(address _owner) Auth(_owner, Authority(address(0))) {}

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Pause this contract, which prevents future calls to `beforeTransfer`.
     * @dev Callable by MULTISIG_ROLE.
     */
    function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    /**
     * @notice Unpause this contract, which allows future calls to `beforeTransfer`.
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
    function updateVaultListIds(address vault, uint8 listBitmap) external requiresAuth {
        vaultData[vault].listBitmap = listBitmap;
        emit VaultListIdsUpdated(vault, _bitmapToListIds(listBitmap));
    }

    /**
     * @notice Blacklist an address for a list ID.
     * @dev Callable by OWNER_ROLE.
     */
    function updateBlacklist(uint8 listId, bytes32[] memory addressHashes, bool isBlacklisted) external requiresAuth {
        _validateListId(listId);
        if(listId == LIST_ID_SANCTIONS) revert ShareWarden__InvalidListId(listId);
        for (uint256 i = 0; i < addressHashes.length; i++) {
            listIdToBlacklisted[listId][addressHashes[i]] = isBlacklisted;
        }
    }

    // =============================== VIEW FUNCTIONS ===============================

    function getVaultData(address vault) external view returns (address teller, uint8[] memory listIds) {
        VaultData storage data = vaultData[vault];
        return (data.teller, _bitmapToListIds(data.listBitmap));
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
        uint8 listBitmap = vaultData[msg.sender].listBitmap;
        if (listBitmap == 0) return;

        bytes32 fromHash = _hashAddress(from);

        for (uint256 bit = 0; bit < 7; bit++) {
            uint8 listId = uint8(1 << bit);
            if ((listBitmap & listId) == 0) continue;

            if (listIdToBlacklisted[listId][fromHash]) {
                revert ShareWarden__Blacklisted(from, listId);
            }
        }

        if ((listBitmap & LIST_ID_SANCTIONS) != 0 && address(sanctionsList) != address(0)) {
            if (sanctionsList.isSanctioned(from)) revert ShareWarden__SanctionsListBlacklisted(from);
        }
    }

    function _checkBlacklist(address from, address to, address operator) internal view {
        uint8 listBitmap = vaultData[msg.sender].listBitmap;
        if (listBitmap == 0) return;

        bytes32 fromHash = _hashAddress(from);
        bytes32 toHash = _hashAddress(to);
        bytes32 operatorHash = _hashAddress(operator);

        for (uint256 bit = 0; bit < 7; bit++) {
            uint8 listId = uint8(1 << bit);
            if ((listBitmap & listId) == 0) continue;

            if (listIdToBlacklisted[listId][fromHash]) {
                revert ShareWarden__Blacklisted(from, listId);
            }
            if (listIdToBlacklisted[listId][toHash]) {
                revert ShareWarden__Blacklisted(to, listId);
            }
            if (listIdToBlacklisted[listId][operatorHash]) {
                revert ShareWarden__Blacklisted(operator, listId);
            }
        }

        if ((listBitmap & LIST_ID_SANCTIONS) != 0 && address(sanctionsList) != address(0)) {
            if (sanctionsList.isSanctioned(from)) revert ShareWarden__SanctionsListBlacklisted(from);
            if (sanctionsList.isSanctioned(to)) revert ShareWarden__SanctionsListBlacklisted(to);
            if (sanctionsList.isSanctioned(operator)) revert ShareWarden__SanctionsListBlacklisted(operator);
        }
    }

    function _bitmapToListIds(uint8 listBitmap) internal pure returns (uint8[] memory listIds) {
        uint256 count;
        uint8 temp = listBitmap;
        while (temp != 0) {
            unchecked {
                temp &= temp - 1;
                count++;
            }
        }

        listIds = new uint8[](count);
        uint256 index;
        for (uint256 bit = 0; bit < 8; bit++) {
            uint8 listId = uint8(1 << bit);
            if ((listBitmap & listId) == 0) continue;
            listIds[index] = listId;
            unchecked {
                index++;
            }
        }
    }

    function _hashAddress(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    function _validateListId(uint8 listId) internal pure {
        if (listId == 0 || (listId & (listId - 1)) != 0) {
            revert ShareWarden__InvalidListId(listId);
        }
    }
}
