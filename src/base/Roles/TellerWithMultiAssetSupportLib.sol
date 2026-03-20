// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeCast} from "@openzeppelin-contracts-5.3.0/utils/math/SafeCast.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {ECDSA} from "@openzeppelin-contracts-5.3.0/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

struct PrincipalCheckpoint {
    uint48 timestamp;
    uint104 cumulativeDeposits;
    uint104 cumulativeWithdrawals;
    uint256 sharePrice;
}

library TellerWithMultiAssetSupportLib {
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================

    /**
     * @param allowDeposits bool indicating whether or not deposits are allowed for this asset.
     * @param allowWithdraws bool indicating whether or not withdraws are allowed for this asset.
     * @param sharePremium uint16 indicating the premium to apply to the shares minted.
     *        where 40 represents a 40bps reduction in shares minted using this asset.
     */
    struct Asset {
        bool allowDeposits;
        bool allowWithdraws;
        uint16 sharePremium;
    }

    /**
     * @param depositBufferHelper IBufferHelper contract address for the deposit buffer helper.
     * @param withdrawBufferHelper IBufferHelper contract address for the withdraw buffer helper.
     */
    struct BufferHelpers {
        IBufferHelper depositBufferHelper;
        IBufferHelper withdrawBufferHelper;
    }

    /**
     * @param denyFrom bool indicating whether or not the user is on the deny from list.
     * @param denyTo bool indicating whether or not the user is on the deny to list.
     * @param denyOperator bool indicating whether or not the user is on the deny operator list.
     * @param shareUnlockTime uint64 indicating the time at which the shares will be unlocked.
     */
    struct BeforeTransferData {
        bool denyFrom;
        bool denyTo;
        bool denyOperator;
        uint64 shareUnlockTime;
    }

    // ========================================= CONSTANTS =========================================

    /**
     * @notice The maximum possible share premium that can be set using `updateAssetData`.
     * @dev 1,000 or 10%
     */
    uint16 internal constant MAX_SHARE_PREMIUM = 1_000;
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    //============================== ERRORS ===============================

    error TellerWithMultiAssetSupport__SharePremiumTooLarge();
    error TellerWithMultiAssetSupport__BufferHelperNotAllowed(ERC20 asset, IBufferHelper bufferHelper);
    error TellerWithMultiAssetSupport__SharesAreUnLocked();
    error TellerWithMultiAssetSupport__BadDepositHash();
    error TellerWithMultiAssetSupport__ComplianceCheckFailed();
    //============================== EVENTS ===============================

    event AssetDataUpdated(address indexed asset, bool allowDeposits, bool allowWithdraws, uint16 sharePremium);
    event DenyFrom(address indexed user);
    event DenyTo(address indexed user);
    event DenyOperator(address indexed user);
    event AllowFrom(address indexed user);
    event AllowTo(address indexed user);
    event AllowOperator(address indexed user);
    event DepositBufferHelperSet(ERC20 indexed asset, IBufferHelper indexed newDepositBufferHelper);
    event WithdrawBufferHelperSet(ERC20 indexed asset, IBufferHelper indexed newWithdrawBufferHelper);
    event BufferHelperAllowed(ERC20 indexed asset, IBufferHelper indexed bufferHelper);
    event BufferHelperDisallowed(ERC20 indexed asset, IBufferHelper indexed bufferHelper);
    event DepositRefunded(uint256 indexed nonce, bytes32 depositHash, address indexed user);

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Updates the asset data for a given asset.
     */
    function updateAssetData(
        mapping(ERC20 => Asset) storage assetData,
        ERC20 asset,
        bool allowDeposits,
        bool allowWithdraws,
        uint16 sharePremium
    ) external {
        if (sharePremium > MAX_SHARE_PREMIUM) {
            revert TellerWithMultiAssetSupport__SharePremiumTooLarge();
        }
        assetData[asset] = Asset(allowDeposits, allowWithdraws, sharePremium);
        emit AssetDataUpdated(address(asset), allowDeposits, allowWithdraws, sharePremium);
    }

    /**
     * @notice Deny a user from transferring or receiving shares.
     */
    function denyAll(mapping(address => BeforeTransferData) storage btd, address user) external {
        btd[user].denyFrom = true;
        btd[user].denyTo = true;
        btd[user].denyOperator = true;
        emit DenyFrom(user);
        emit DenyTo(user);
        emit DenyOperator(user);
    }

    /**
     * @notice Allow a user to transfer or receive shares.
     */
    function allowAll(mapping(address => BeforeTransferData) storage btd, address user) external {
        btd[user].denyFrom = false;
        btd[user].denyTo = false;
        btd[user].denyOperator = false;
        emit AllowFrom(user);
        emit AllowTo(user);
        emit AllowOperator(user);
    }

    /**
     * @notice Deny a user from transferring shares.
     */
    function denyFrom(mapping(address => BeforeTransferData) storage btd, address user) external {
        btd[user].denyFrom = true;
        emit DenyFrom(user);
    }

    /**
     * @notice Allow a user to transfer shares.
     */
    function allowFrom(mapping(address => BeforeTransferData) storage btd, address user) external {
        btd[user].denyFrom = false;
        emit AllowFrom(user);
    }

    /**
     * @notice Deny a user from receiving shares.
     */
    function denyTo(mapping(address => BeforeTransferData) storage btd, address user) external {
        btd[user].denyTo = true;
        emit DenyTo(user);
    }

    /**
     * @notice Allow a user to receive shares.
     */
    function allowTo(mapping(address => BeforeTransferData) storage btd, address user) external {
        btd[user].denyTo = false;
        emit AllowTo(user);
    }

    /**
     * @notice Deny an operator from transferring shares.
     */
    function denyOperator(mapping(address => BeforeTransferData) storage btd, address user) external {
        btd[user].denyOperator = true;
        emit DenyOperator(user);
    }

    /**
     * @notice Allow an operator to transfer shares.
     */
    function allowOperator(mapping(address => BeforeTransferData) storage btd, address user) external {
        btd[user].denyOperator = false;
        emit AllowOperator(user);
    }

    /**
     * @notice Updates the deposit buffer helper contract for a given asset.
     */
    function setDepositBufferHelper(
        mapping(ERC20 => BufferHelpers) storage currentBufferHelpers,
        mapping(ERC20 => mapping(IBufferHelper => bool)) storage allowedBufferHelpers,
        ERC20 _asset,
        IBufferHelper _depositBufferHelper
    ) external {
        if (allowedBufferHelpers[_asset][_depositBufferHelper] || _depositBufferHelper == IBufferHelper(address(0))) {
            currentBufferHelpers[_asset].depositBufferHelper = _depositBufferHelper;
            emit DepositBufferHelperSet(_asset, _depositBufferHelper);
        } else {
            revert TellerWithMultiAssetSupport__BufferHelperNotAllowed(_asset, _depositBufferHelper);
        }
    }

    /**
     * @notice Updates the withdrawal buffer helper contract for a given asset.
     */
    function setWithdrawBufferHelper(
        mapping(ERC20 => BufferHelpers) storage currentBufferHelpers,
        mapping(ERC20 => mapping(IBufferHelper => bool)) storage allowedBufferHelpers,
        ERC20 _asset,
        IBufferHelper _withdrawBufferHelper
    ) external {
        if (allowedBufferHelpers[_asset][_withdrawBufferHelper] || _withdrawBufferHelper == IBufferHelper(address(0))) {
            currentBufferHelpers[_asset].withdrawBufferHelper = _withdrawBufferHelper;
            emit WithdrawBufferHelperSet(_asset, _withdrawBufferHelper);
        } else {
            revert TellerWithMultiAssetSupport__BufferHelperNotAllowed(_asset, _withdrawBufferHelper);
        }
    }

    /**
     * @notice Allows a buffer helper to be used for a specific asset.
     */
    function allowBufferHelper(
        mapping(ERC20 => mapping(IBufferHelper => bool)) storage allowedBufferHelpers,
        ERC20 _asset,
        IBufferHelper _bufferHelper
    ) external {
        allowedBufferHelpers[_asset][_bufferHelper] = true;
        emit BufferHelperAllowed(_asset, _bufferHelper);
    }

    /**
     * @notice Disallows a buffer helper from being used for a specific asset.
     */
    function disallowBufferHelper(
        mapping(ERC20 => mapping(IBufferHelper => bool)) storage allowedBufferHelpers,
        ERC20 _asset,
        IBufferHelper _bufferHelper
    ) external {
        allowedBufferHelpers[_asset][_bufferHelper] = false;
        emit BufferHelperDisallowed(_asset, _bufferHelper);
    }

    // ========================================= REVERT DEPOSIT FUNCTIONS =========================================

    /**
     * @notice Allows a refund of a pending deposit.
     * @dev Once a deposit share lock period has passed, it can no longer be reverted.
     */
    function refundDeposit(
        mapping(uint256 => bytes32) storage publicDepositHistory,
        BoringVault vault,
        WETH nativeWrapper,
        uint256 nonce,
        address receiver,
        address depositAsset,
        uint256 depositAmount,
        uint256 shareAmount,
        uint256 depositTimestamp,
        uint256 shareLockUpPeriodAtTimeOfDeposit,
        address referralAddress
    ) external {
        if ((block.timestamp - depositTimestamp) >= shareLockUpPeriodAtTimeOfDeposit) {
            revert TellerWithMultiAssetSupport__SharesAreUnLocked();
        }
        bytes32 depositHash = keccak256(
            abi.encode(
                receiver,
                depositAsset,
                depositAmount,
                shareAmount,
                depositTimestamp,
                shareLockUpPeriodAtTimeOfDeposit,
                referralAddress
            )
        );
        if (publicDepositHistory[nonce] != depositHash) revert TellerWithMultiAssetSupport__BadDepositHash();

        delete publicDepositHistory[nonce];

        // If deposit used native asset, send user back wrapped native asset.
        depositAsset = depositAsset == NATIVE ? address(nativeWrapper) : depositAsset;
        vault.exit(receiver, ERC20(depositAsset), depositAmount, receiver, shareAmount);

        emit DepositRefunded(nonce, depositHash, receiver);
    }

    // ========================================= COMPLIANCE FUNCTIONS =========================================

    /**
     * @notice Verify a compliance signature and mark it as used.
     * @dev Callers are responsible for constructing the messageHash. This function handles
     *      ECDSA recovery, deadline checks, and marking the signature as consumed.
     */
    function verifyAndMarkCompliance(
        mapping(bytes32 => bool) storage usedComplianceSignatures,
        address complianceSigner,
        uint96 complianceWindow,
        bytes32 messageHash,
        uint256 deadline,
        bytes calldata signature
    ) external {
        _verifyAndMark(usedComplianceSignatures, complianceSigner, complianceWindow, messageHash, deadline, signature);
    }

    /**
     * @notice Verify deposit compliance: builds the deposit message hash, then verifies and marks the signature.
     * @dev Handles the complianceSigner == address(0) early return internally.
     */
    function verifyDepositCompliance(
        mapping(bytes32 => bool) storage usedComplianceSignatures,
        address complianceSigner,
        uint96 complianceWindow,
        address depositor,
        address depositAsset,
        uint256 depositAmount,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (complianceSigner == address(0)) return;
        bytes32 messageHash =
            keccak256(abi.encode(address(this), block.chainid, depositor, depositAsset, depositAmount, deadline));
        _verifyAndMark(usedComplianceSignatures, complianceSigner, complianceWindow, messageHash, deadline, signature);
    }

    /**
     * @notice Verify bridge compliance: builds the bridge message hash, then verifies and marks the signature.
     * @dev Handles the complianceSigner == address(0) early return internally.
     */
    function verifyBridgeCompliance(
        mapping(bytes32 => bool) storage usedComplianceSignatures,
        address complianceSigner,
        uint96 complianceWindow,
        address sender,
        uint96 shareAmount,
        address to,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (complianceSigner == address(0)) return;
        bytes32 messageHash = keccak256(abi.encode(address(this), block.chainid, sender, shareAmount, to, deadline));
        _verifyAndMark(usedComplianceSignatures, complianceSigner, complianceWindow, messageHash, deadline, signature);
    }

    /**
     * @param complianceWindow Duration in seconds. Deadline must be <= block.timestamp + complianceWindow.
     */
    function _verifyAndMark(
        mapping(bytes32 => bool) storage usedComplianceSignatures,
        address complianceSigner,
        uint96 complianceWindow,
        bytes32 messageHash,
        uint256 deadline,
        bytes calldata signature
    ) private {
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

    // ========================================= CHECKPOINT FUNCTIONS =========================================

    /**
     * @notice Appends a principal checkpoint for a user on deposit or withdrawal.
     * @dev Rounding is intentionally asymmetric: deposits round DOWN, withdrawals round UP.
     */
    function checkpointPrincipal(
        mapping(address => PrincipalCheckpoint[]) storage principalHistory,
        uint256 rate,
        uint256 oneShare,
        address user,
        uint256 shares,
        bool isDeposit
    ) external {
        uint256 len = principalHistory[user].length;
        if (!isDeposit && len == 0) return;
        uint104 prevDeposits = len > 0 ? principalHistory[user][len - 1].cumulativeDeposits : 0;
        uint104 prevWithdrawals = len > 0 ? principalHistory[user][len - 1].cumulativeWithdrawals : 0;
        if (isDeposit) {
            uint256 baseValue = shares.mulDivDown(rate, oneShare);
            prevDeposits += SafeCast.toUint104(baseValue);
        } else {
            uint256 baseValue = shares.mulDivUp(rate, oneShare);
            prevWithdrawals += SafeCast.toUint104(baseValue);
        }
        principalHistory[user].push(PrincipalCheckpoint(uint48(block.timestamp), prevDeposits, prevWithdrawals, rate));
    }

    /**
     * @notice Pushes a timestamp-only checkpoint for a user on share transfer.
     * @dev If the most recent entry is itself a transfer checkpoint (same cumulative values
     *      as the entry before it), overwrites its timestamp instead of pushing.
     */
    function checkpointTransfer(
        mapping(address => PrincipalCheckpoint[]) storage principalHistory,
        uint256 rate,
        address user
    ) external {
        PrincipalCheckpoint[] storage history = principalHistory[user];
        uint256 len = history.length;
        uint104 d;
        uint104 w;
        if (len != 0) {
            d = history[len - 1].cumulativeDeposits;
            w = history[len - 1].cumulativeWithdrawals;
            if (len > 1 && d == history[len - 2].cumulativeDeposits && w == history[len - 2].cumulativeWithdrawals) {
                history[len - 1].timestamp = uint48(block.timestamp);
                history[len - 1].sharePrice = rate;
                return;
            }
        }
        history.push(PrincipalCheckpoint(uint48(block.timestamp), d, w, rate));
    }
}
