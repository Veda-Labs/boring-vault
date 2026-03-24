// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {PrincipalCheckpoint, BufferHelpers} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeCast} from "@openzeppelin-contracts-5.3.0/utils/math/SafeCast.sol";
import {ECDSA} from "@openzeppelin-contracts-5.3.0/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

library TellerWithMultiAssetSupportLib {
    using FixedPointMathLib for uint256;

    error TellerWithMultiAssetSupport__ComplianceCheckFailed();

    // ========================================= COMPLIANCE =========================================

    /// @notice Verify and mark a compliance signature as used.
    /// @dev Uses DELEGATECALL context so storage pointers reference the calling contract's state.
    function verifyAndMark(
        mapping(bytes32 messageHash => bool used) storage usedComplianceSignatures,
        address complianceSigner,
        uint96 complianceWindow,
        bytes32 messageHash,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (usedComplianceSignatures[messageHash]) {
            revert TellerWithMultiAssetSupport__ComplianceCheckFailed();
        }
        if (block.timestamp > deadline) {
            revert TellerWithMultiAssetSupport__ComplianceCheckFailed();
        }
        if (complianceWindow > 0 && deadline > block.timestamp + complianceWindow) {
            revert TellerWithMultiAssetSupport__ComplianceCheckFailed();
        }
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recovered = ECDSA.recover(ethSignedHash, signature);
        if (recovered != complianceSigner) revert TellerWithMultiAssetSupport__ComplianceCheckFailed();
        usedComplianceSignatures[messageHash] = true;
    }

    // ========================================= PRINCIPAL =========================================

    /// @notice Append a principal checkpoint for a user.
    /// @dev Rounding is asymmetric: deposits round DOWN, withdrawals round UP.
    function checkpointPrincipalAtRate(
        mapping(address user => PrincipalCheckpoint[]) storage principalHistory,
        uint256 oneShare,
        address user,
        uint256 shares,
        bool isDeposit,
        uint256 baseValueRate,
        uint256 currentRate
    ) external {
        uint256 len = principalHistory[user].length;
        if (!isDeposit && len == 0) return;
        uint104 prevDeposits = len > 0 ? principalHistory[user][len - 1].cumulativeDeposits : 0;
        uint104 prevWithdrawals = len > 0 ? principalHistory[user][len - 1].cumulativeWithdrawals : 0;
        if (isDeposit) {
            uint256 baseValue = shares.mulDivDown(baseValueRate, oneShare);
            prevDeposits += SafeCast.toUint104(baseValue);
        } else {
            uint256 baseValue = shares.mulDivUp(baseValueRate, oneShare);
            prevWithdrawals += SafeCast.toUint104(baseValue);
        }
        principalHistory[user].push(
            PrincipalCheckpoint(uint48(block.timestamp), prevDeposits, prevWithdrawals, currentRate)
        );
    }

    // ========================================= BUFFER HELPERS =========================================

    /// @notice Execute buffer management after a deposit.
    function afterDeposit(
        mapping(ERC20 => BufferHelpers) storage bufferHelpers,
        BoringVault vault,
        ERC20 depositAsset,
        uint256 assetAmount
    ) external {
        if (address(bufferHelpers[depositAsset].depositBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) =
                bufferHelpers[depositAsset].depositBufferHelper.getDepositManageCall(address(depositAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }

    /// @notice Execute buffer management before a withdrawal.
    function beforeWithdraw(
        mapping(ERC20 => BufferHelpers) storage bufferHelpers,
        BoringVault vault,
        ERC20 withdrawAsset,
        uint256 assetAmount
    ) external {
        if (address(bufferHelpers[withdrawAsset].withdrawBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) = bufferHelpers[withdrawAsset].withdrawBufferHelper
                .getWithdrawManageCall(address(withdrawAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }
}
