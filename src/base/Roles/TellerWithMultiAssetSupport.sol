// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {WETH} from "@solmate/tokens/WETH.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BeforeTransferHook} from "src/interfaces/BeforeTransferHook.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {IncentivePool} from "src/base/IncentivePool.sol";
import {SafeCast} from "@openzeppelin-contracts-5.3.0/utils/math/SafeCast.sol";
import {ECDSA} from "@openzeppelin-contracts-5.3.0/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

struct DepositParams {
    ERC20 depositAsset;
    uint256 depositAmount;
    uint256 minimumMint;
    address to;
}

struct ComplianceData {
    uint256 deadline;
    bytes signature;
}

struct PermitData {
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct RewardData {
    address pool;
    uint256 cumulativeOwed;
    uint256 deadline;
    bytes signature;
}

struct PrincipalCheckpoint {
    uint48 timestamp;
    uint104 cumulativeDeposits;
    uint104 cumulativeWithdrawals;
    uint256 sharePrice;
}

struct Asset {
    bool allowDeposits;
    bool allowWithdraws;
    uint16 sharePremium;
}

struct BufferHelpers {
    IBufferHelper depositBufferHelper;
    IBufferHelper withdrawBufferHelper;
}

struct BeforeTransferData {
    bool denyFrom;
    bool denyTo;
    bool denyOperator;
    uint64 shareUnlockTime;
}

contract TellerWithMultiAssetSupport is Auth, BeforeTransferHook, ReentrancyGuard, IPausable {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using SafeTransferLib for WETH;

    // ========================================= CONSTANTS =========================================

    /**
     * @notice Native address used to tell the contract to handle native asset deposits.
     */
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @notice The maximum possible share lock period.
     */
    uint256 internal constant MAX_SHARE_LOCK_PERIOD = 3 days;

    /**
     * @notice The maximum possible share premium that can be set using `updateAssetData`.
     * @dev 1,000 or 10%
     */
    uint16 internal constant MAX_SHARE_PREMIUM = 1_000;

    // ========================================= STATE =========================================

    /**
     * @notice Mapping ERC20s to their assetData.
     */
    mapping(ERC20 => Asset) public assetData;

    /**
     * @notice The deposit nonce used to map to a deposit hash.
     */
    uint64 public depositNonce;

    /**
     * @notice After deposits, shares are locked to the msg.sender's address
     *         for `shareLockPeriod`.
     * @dev During this time all transfers from msg.sender will revert, and
     *      deposits are refundable.
     */
    uint64 public shareLockPeriod;

    /**
     * @notice Used to pause calls to `deposit` and `depositWithPermit`.
     */
    bool public isPaused;

    /**
     * @notice The global deposit cap of the vault.
     * @dev If the cap is reached, no new deposits are accepted. No partial fills.
     */
    uint112 public depositCap = type(uint112).max;

    /**
     * @dev Maps deposit nonce to keccak256(address receiver, address depositAsset, uint256 depositAmount, uint256 shareAmount, uint256 timestamp, uint256 shareLockPeriod).
     */
    mapping(uint256 => bytes32) public publicDepositHistory;

    /**
     * @notice Maps address to BeforeTransferData struct to check if shares are locked and if the address is on any allow or deny list.
     */
    mapping(address => BeforeTransferData) public beforeTransferData;

    /**
     * @notice Maps ERC20 assets to their current buffer helpers.
     */
    mapping(ERC20 => BufferHelpers) public currentBufferHelpers;

    /**
     * @notice Maps ERC20 assets to allowed buffer helpers.
     */
    mapping(ERC20 => mapping(IBufferHelper => bool)) public allowedBufferHelpers;

    /**
     * @notice The address that must sign compliance approvals for deposits.
     * @dev If set to address(0), compliance verification is skipped (backward-compatible default).
     */
    address public complianceSigner;

    /**
     * @notice Maximum duration (in seconds) into the future that a compliance signature deadline may extend.
     * @dev If set to 0, no cap is enforced. When non-zero, any compliance signature whose deadline exceeds
     *      block.timestamp + complianceWindow will be rejected. Set this to a relative duration, e.g. 3600 for 1 hour.
     */
    uint96 public complianceWindow;

    /**
     * @notice Maps compliance signature hashes to used status.
     */
    mapping(bytes32 messageHash => bool used) public usedComplianceSignatures;

    /**
     * @notice Per-user cumulative principal history in base-asset value.
     */
    mapping(address user => PrincipalCheckpoint[]) internal _principalHistory;

    /**
     * @notice Role ID that is allowed to be a counterparty in share transfers.
     * @dev When set to type(uint8).max (255), transfers are unrestricted.
     *      Any other value restricts transfers so that either `from` or `to` must hold that role.
     */
    uint8 public transferAllowedRole = type(uint8).max;

    //============================== ERRORS ===============================

    error TellerWithMultiAssetSupport__ShareLockPeriodTooLong();
    error TellerWithMultiAssetSupport__SharesAreLocked();
    error TellerWithMultiAssetSupport__SharesAreUnLocked();
    error TellerWithMultiAssetSupport__BadDepositHash();
    error TellerWithMultiAssetSupport__AssetNotSupported();
    error TellerWithMultiAssetSupport__ZeroAssets();
    error TellerWithMultiAssetSupport__MinimumMintNotMet();
    error TellerWithMultiAssetSupport__MinimumAssetsNotMet();
    error TellerWithMultiAssetSupport__PermitFailedAndAllowanceTooLow();
    error TellerWithMultiAssetSupport__ZeroShares();
    error TellerWithMultiAssetSupport__DualDeposit();
    error TellerWithMultiAssetSupport__Paused();
    error TellerWithMultiAssetSupport__TransferDenied(address from, address to, address operator);
    error TellerWithMultiAssetSupport__DepositExceedsCap();
    error TellerWithMultiAssetSupport__ZeroRecipient();
    error TellerWithMultiAssetSupport__ComplianceCheckFailed();
    error TellerWithMultiAssetSupport__SharePremiumTooLarge();
    error TellerWithMultiAssetSupport__BufferHelperNotAllowed(ERC20 asset, IBufferHelper bufferHelper);
    error TellerWithMultiAssetSupport__TransferNotAllowed();

    //============================== EVENTS ===============================

    event Paused();
    event Unpaused();
    event Deposit(
        uint256 nonce,
        address indexed receiver,
        address indexed depositAsset,
        uint256 depositAmount,
        uint256 shareAmount,
        uint256 depositTimestamp,
        uint256 shareLockPeriodAtTimeOfDeposit,
        address indexed referralAddress
    );
    event BulkDeposit(address indexed asset, uint256 depositAmount);
    event BulkWithdraw(address indexed asset, uint256 shareAmount);
    event Withdraw(address indexed asset, uint256 shareAmount);
    event DepositRefunded(uint256 indexed nonce, bytes32 depositHash, address indexed user);
    event DepositCapSet(uint112 cap);
    event ComplianceSignerSet(address indexed signer);
    event ComplianceWindowSet(uint96 window);
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
    event TransferAllowedRoleSet(uint8 role);

    //============================== IMMUTABLES ===============================

    /**
     * @notice The BoringVault this contract is working with.
     */
    BoringVault public immutable vault;

    /**
     * @notice The AccountantWithRateProviders this contract is working with.
     */
    AccountantWithRateProviders public immutable accountant;

    /**
     * @notice One share of the BoringVault.
     */
    uint256 internal immutable ONE_SHARE;

    /**
     * @notice The native wrapper contract.
     */
    WETH public immutable nativeWrapper;

    constructor(address _owner, address _vault, address _accountant, address _weth)
        Auth(_owner, Authority(address(0)))
    {
        vault = BoringVault(payable(_vault));
        ONE_SHARE = 10 ** vault.decimals();
        accountant = AccountantWithRateProviders(_accountant);
        nativeWrapper = WETH(payable(_weth));
    }

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
     * @notice Updates the asset data for a given asset.
     * @dev The accountant must also support pricing this asset, else the `deposit` call will revert.
     * @dev Callable by OWNER_ROLE.
     */
    function updateAssetData(ERC20 asset, bool allowDeposits, bool allowWithdraws, uint16 sharePremium)
        external
        requiresAuth
    {
        if (sharePremium > MAX_SHARE_PREMIUM) {
            revert TellerWithMultiAssetSupport__SharePremiumTooLarge();
        }
        assetData[asset] = Asset(allowDeposits, allowWithdraws, sharePremium);
        emit AssetDataUpdated(address(asset), allowDeposits, allowWithdraws, sharePremium);
    }

    /**
     * @notice Sets the share lock period.
     * @dev This not only locks shares to the user address, but also serves as the pending deposit period, where deposits can be reverted.
     * @dev If a new shorter share lock period is set, users with pending share locks could make a new deposit to receive 1 wei shares,
     *      and have their shares unlock sooner than their original deposit allows. This state would allow for the user deposit to be refunded,
     *      but only if they have not transferred their shares out of there wallet. This is an accepted limitation, and should be known when decreasing
     *      the share lock period.
     * @dev Callable by OWNER_ROLE.
     */
    function setShareLockPeriod(uint64 _shareLockPeriod) external requiresAuth {
        if (_shareLockPeriod > MAX_SHARE_LOCK_PERIOD) revert TellerWithMultiAssetSupport__ShareLockPeriodTooLong();
        shareLockPeriod = _shareLockPeriod;
    }

    /**
     * @notice Deny a user from transferring or receiving shares.
     * @dev Callable by OWNER_ROLE, and DENIER_ROLE.
     */
    function denyAll(address user) external requiresAuth {
        beforeTransferData[user].denyFrom = true;
        beforeTransferData[user].denyTo = true;
        beforeTransferData[user].denyOperator = true;
        emit DenyFrom(user);
        emit DenyTo(user);
        emit DenyOperator(user);
    }

    /**
     * @notice Allow a user to transfer or receive shares.
     * @dev Callable by OWNER_ROLE, and DENIER_ROLE.
     */
    function allowAll(address user) external requiresAuth {
        beforeTransferData[user].denyFrom = false;
        beforeTransferData[user].denyTo = false;
        beforeTransferData[user].denyOperator = false;
        emit AllowFrom(user);
        emit AllowTo(user);
        emit AllowOperator(user);
    }

    /**
     * @notice Deny a user from transferring shares.
     * @dev Callable by OWNER_ROLE, and DENIER_ROLE.
     */
    function denyFrom(address user) external requiresAuth {
        beforeTransferData[user].denyFrom = true;
        emit DenyFrom(user);
    }

    /**
     * @notice Allow a user to transfer shares.
     * @dev Callable by OWNER_ROLE, and DENIER_ROLE.
     */
    function allowFrom(address user) external requiresAuth {
        beforeTransferData[user].denyFrom = false;
        emit AllowFrom(user);
    }

    /**
     * @notice Deny a user from receiving shares.
     * @dev Callable by OWNER_ROLE, and DENIER_ROLE.
     */
    function denyTo(address user) external requiresAuth {
        beforeTransferData[user].denyTo = true;
        emit DenyTo(user);
    }

    /**
     * @notice Allow a user to receive shares.
     * @dev Callable by OWNER_ROLE, and DENIER_ROLE.
     */
    function allowTo(address user) external requiresAuth {
        beforeTransferData[user].denyTo = false;
        emit AllowTo(user);
    }

    /**
     * @notice Deny an operator from transferring shares.
     * @dev Callable by OWNER_ROLE, and DENIER_ROLE.
     */
    function denyOperator(address user) external requiresAuth {
        beforeTransferData[user].denyOperator = true;
        emit DenyOperator(user);
    }

    /**
     * @notice Allow an operator to transfer shares.
     * @dev Callable by OWNER_ROLE, and DENIER_ROLE.
     */
    function allowOperator(address user) external requiresAuth {
        beforeTransferData[user].denyOperator = false;
        emit AllowOperator(user);
    }

    /**
     * @notice Set the deposit cap of the vault.
     * @dev Callable by OWNER_ROLE
     */
    function setDepositCap(uint112 cap) external requiresAuth {
        depositCap = cap;
        emit DepositCapSet(cap);
    }

    /**
     * @notice Restrict share transfers so that either `from` or `to` must hold the given role.
     * @dev Set to type(uint8).max to allow unrestricted transfers (default).
     * @param _transferAllowedRole The role ID required for at least one side of a transfer.
     */
    function setTransferAllowedRole(uint8 _transferAllowedRole) external requiresAuth {
        transferAllowedRole = _transferAllowedRole;
        emit TransferAllowedRoleSet(_transferAllowedRole);
    }

    /**
     * @notice Updates the deposit buffer helper contract for a given asset.
     * @param _asset The asset to update the buffer helper for.
     * @param _depositBufferHelper The new deposit buffer helper contract address.
     * @dev Only callable by authorized accounts. The helper must be allowlisted or zero address.
     */
    function setDepositBufferHelper(ERC20 _asset, IBufferHelper _depositBufferHelper) external requiresAuth {
        if (allowedBufferHelpers[_asset][_depositBufferHelper] || _depositBufferHelper == IBufferHelper(address(0))) {
            currentBufferHelpers[_asset].depositBufferHelper = _depositBufferHelper;
            emit DepositBufferHelperSet(_asset, _depositBufferHelper);
        } else {
            revert TellerWithMultiAssetSupport__BufferHelperNotAllowed(_asset, _depositBufferHelper);
        }
    }

    /**
     * @notice Updates the withdrawal buffer helper contract for a given asset.
     * @param _asset The asset to update the buffer helper for.
     * @param _withdrawBufferHelper The new withdrawal buffer helper contract address.
     * @dev Only callable by authorized accounts. The helper must be allowlisted or zero address.
     */
    function setWithdrawBufferHelper(ERC20 _asset, IBufferHelper _withdrawBufferHelper) external requiresAuth {
        if (allowedBufferHelpers[_asset][_withdrawBufferHelper] || _withdrawBufferHelper == IBufferHelper(address(0))) {
            currentBufferHelpers[_asset].withdrawBufferHelper = _withdrawBufferHelper;
            emit WithdrawBufferHelperSet(_asset, _withdrawBufferHelper);
        } else {
            revert TellerWithMultiAssetSupport__BufferHelperNotAllowed(_asset, _withdrawBufferHelper);
        }
    }

    /**
     * @notice Allows a buffer helper to be used for a specific asset.
     * @param _asset The asset to allow the buffer helper for.
     * @param _bufferHelper The buffer helper contract address to allow.
     */
    function allowBufferHelper(ERC20 _asset, IBufferHelper _bufferHelper) external requiresAuth {
        allowedBufferHelpers[_asset][_bufferHelper] = true;
        emit BufferHelperAllowed(_asset, _bufferHelper);
    }

    /**
     * @notice Disallows a buffer helper from being used for a specific asset.
     * @dev Also clears the helper from active use if it is currently set as the
     *      deposit or withdraw buffer helper for the asset.
     * @param _asset The asset to disallow the buffer helper for.
     * @param _bufferHelper The buffer helper contract address to disallow.
     */
    function disallowBufferHelper(ERC20 _asset, IBufferHelper _bufferHelper) external requiresAuth {
        allowedBufferHelpers[_asset][_bufferHelper] = false;

        BufferHelpers storage helpers = currentBufferHelpers[_asset];
        if (helpers.depositBufferHelper == _bufferHelper) {
            helpers.depositBufferHelper = IBufferHelper(address(0));
            emit DepositBufferHelperSet(_asset, IBufferHelper(address(0)));
        }
        if (helpers.withdrawBufferHelper == _bufferHelper) {
            helpers.withdrawBufferHelper = IBufferHelper(address(0));
            emit WithdrawBufferHelperSet(_asset, IBufferHelper(address(0)));
        }

        emit BufferHelperDisallowed(_asset, _bufferHelper);
    }

    /**
     * @notice Sets the compliance signer address for deposit verification.
     * @dev Set to address(0) to disable compliance checks (default).
     *      When rotating keys, do not reuse a previously active signer address.
     *      Reusing a retired key would re-enable any unexpired signatures issued under that key.
     * @param _complianceSigner The address of the compliance signer.
     */
    function setComplianceSigner(address _complianceSigner) external requiresAuth {
        complianceSigner = _complianceSigner;
        emit ComplianceSignerSet(_complianceSigner);
    }

    /**
     * @notice Sets the maximum allowed window (in seconds) for compliance signature deadlines.
     * @dev Set to 0 to disable the cap (default). When non-zero, compliance signatures must have
     *      a deadline no later than block.timestamp + _complianceWindow.
     *      Example: setComplianceWindow(3600) limits signatures to 1 hour into the future.
     * @param _complianceWindow Duration in seconds. NOT an absolute timestamp.
     */
    function setComplianceWindow(uint96 _complianceWindow) external requiresAuth {
        complianceWindow = _complianceWindow;
        emit ComplianceWindowSet(_complianceWindow);
    }

    // ========================================= BeforeTransferHook FUNCTIONS =========================================

    /**
     * @notice Implement beforeTransfer hook to check if shares are locked, or if `from`, `to`, or `operator` are denied in beforeTransferData.
     * @notice If share lock period is set to zero, then users will be able to mint and transfer in the same tx.
     *         if this behavior is not desired then a share lock period of >=1 should be used.
     */
    function beforeTransfer(address from, address to, address operator) public view virtual {
        _handleDenyList(from, to, operator);

        if (beforeTransferData[from].shareUnlockTime > block.timestamp) {
            revert TellerWithMultiAssetSupport__SharesAreLocked();
        }

        _enforceTransferAllowlist(from, to);
    }

    /**
     * @notice Implement legacy beforeTransfer hook to check if shares are locked, or if `from` is on the deny list.
     * @dev This function is not expected to have `_enforceTransferAllowlist`
     */
    function beforeTransfer(address from) public view virtual {
        if (beforeTransferData[from].denyFrom) {
            revert TellerWithMultiAssetSupport__TransferDenied(from, address(0), address(0));
        }
        if (beforeTransferData[from].shareUnlockTime > block.timestamp) {
            revert TellerWithMultiAssetSupport__SharesAreLocked();
        }
    }

    /**
     * @notice Internal function to check deny lists for transfers.
     * @dev Reverts if `from` is denied, `to` is denied, or `operator` is denied.
     * @param from The sender address.
     * @param to The receiver address.
     * @param operator The address performing the operation.
     */
    function _handleDenyList(address from, address to, address operator) internal view {
        if (
            beforeTransferData[from].denyFrom || beforeTransferData[to].denyTo
                || beforeTransferData[operator].denyOperator
        ) {
            revert TellerWithMultiAssetSupport__TransferDenied(from, to, operator);
        }
    }

    /**
     * @notice Enforces transfer allowlist based on `transferAllowedRole`.
     * @dev If `transferAllowedRole` is type(uint8).max, no restriction is applied.
     *      Otherwise, at least one of `from` or `to` must hold the specified role.
     */
    function _enforceTransferAllowlist(address from, address to) internal view {
        uint8 role = transferAllowedRole;
        if (role == type(uint8).max) return;
        RolesAuthority auth = RolesAuthority(address(authority));
        if (!auth.doesUserHaveRole(from, role) && !auth.doesUserHaveRole(to, role)) {
            revert TellerWithMultiAssetSupport__TransferNotAllowed();
        }
    }

    // ========================================= REVERT DEPOSIT FUNCTIONS =========================================

    /**
     * @notice Allows DEPOSIT_REFUNDER_ROLE to revert a pending deposit.
     * @dev Once a deposit share lock period has passed, it can no longer be reverted.
     * @dev It is possible the admin does not setup the BoringVault to call the transfer hook,
     *      but this contract can still be saving share lock state. In the event this happens
     *      deposits are still refundable if the user has not transferred their shares.
     *      But there is no guarantee that the user has not transferred their shares.
     * @dev Callable by STRATEGIST_MULTISIG_ROLE.
     */
    function refundDeposit(
        uint256 nonce,
        address receiver,
        address depositAsset,
        uint256 depositAmount,
        uint256 shareAmount,
        uint256 depositTimestamp,
        uint256 shareLockUpPeriodAtTimeOfDeposit,
        uint256 depositSharePrice,
        address referralAddress
    ) external requiresAuth {
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
                depositSharePrice,
                referralAddress
            )
        );
        if (publicDepositHistory[nonce] != depositHash) revert TellerWithMultiAssetSupport__BadDepositHash();

        delete publicDepositHistory[nonce];

        // If deposit used native asset, send user back wrapped native asset.
        address refundAsset = depositAsset == NATIVE ? address(nativeWrapper) : depositAsset;
        vault.exit(receiver, ERC20(refundAsset), depositAmount, receiver, shareAmount);

        emit DepositRefunded(nonce, depositHash, receiver);
        _checkpointPrincipalAtRate(receiver, shareAmount, false, depositSharePrice, accountant.getRateSafe());
    }

    // ========================================= USER FUNCTIONS =========================================

    /**
     * @notice Allows users to deposit into the BoringVault, if this contract is not paused.
     * @dev Publicly callable.
     * @dev For native ETH deposits, the compliance signature must be built using the
     *      nativeWrapper (WETH) address as the deposit asset, not the NATIVE sentinel,
     *      because the NATIVE-to-WETH conversion occurs before compliance verification.
     */
    function deposit(DepositParams calldata params, address referralAddress, ComplianceData calldata compliance)
        external
        payable
        virtual
        requiresAuth
        nonReentrant
        returns (uint256 shares)
    {
        ERC20 depositAsset = params.depositAsset;
        uint256 depositAmount = params.depositAmount;
        address to = params.to;
        if (to == address(0)) revert TellerWithMultiAssetSupport__ZeroRecipient();
        Asset memory asset = _beforeDeposit(depositAsset);

        address from;
        if (address(depositAsset) == NATIVE) {
            if (msg.value == 0) revert TellerWithMultiAssetSupport__ZeroAssets();
            nativeWrapper.deposit{value: msg.value}();
            // Set depositAmount to msg.value.
            depositAmount = msg.value;
            nativeWrapper.safeApprove(address(vault), depositAmount);
            // Update depositAsset to nativeWrapper.
            depositAsset = nativeWrapper;
            // Set from to this address since user transferred value.
            from = address(this);
        } else {
            if (msg.value > 0) revert TellerWithMultiAssetSupport__DualDeposit();
            from = msg.sender;
        }

        _verifyComplianceSignature(to, depositAsset, depositAmount, compliance);
        shares = _erc20Deposit(depositAsset, depositAmount, params.minimumMint, from, to, asset);
        uint256 rate = accountant.getRateSafe();
        _checkpointPrincipalAtRate(to, shares, true, rate, rate);
        _afterPublicDeposit(to, depositAsset, depositAmount, shares, shareLockPeriod, referralAddress);
    }

    /**
     * @notice Allows users to deposit into BoringVault using permit.
     * @dev Publicly callable.
     */
    function depositWithPermit(
        DepositParams calldata params,
        PermitData calldata permit,
        address referralAddress,
        ComplianceData calldata compliance
    ) external virtual requiresAuth nonReentrant returns (uint256 shares) {
        if (address(params.depositAsset) == NATIVE) {
            revert TellerWithMultiAssetSupport__AssetNotSupported();
        }
        address to = params.to;
        if (to == address(0)) revert TellerWithMultiAssetSupport__ZeroRecipient();
        _verifyComplianceSignature(to, params.depositAsset, params.depositAmount, compliance);
        Asset memory asset = _beforeDeposit(params.depositAsset);

        _handlePermit(params.depositAsset, params.depositAmount, permit);

        shares = _erc20Deposit(params.depositAsset, params.depositAmount, params.minimumMint, msg.sender, to, asset);
        uint256 rate = accountant.getRateSafe();
        _checkpointPrincipalAtRate(to, shares, true, rate, rate);
        _afterPublicDeposit(to, params.depositAsset, params.depositAmount, shares, shareLockPeriod, referralAddress);
    }

    /**
     * @notice Allows on ramp role to deposit into this contract.
     * @dev Does NOT support native deposits.
     * @dev Callable by SOLVER_ROLE.
     */
    function bulkDeposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint, address to)
        external
        virtual
        requiresAuth
        nonReentrant
        returns (uint256 shares)
    {
        Asset memory asset = _beforeDeposit(depositAsset);

        shares = _erc20Deposit(depositAsset, depositAmount, minimumMint, msg.sender, to, asset);
        emit BulkDeposit(address(depositAsset), depositAmount);
    }

    /**
     * @notice Allows off ramp role to withdraw from this contract.
     * @dev Callable by SOLVER_ROLE.
     */
    function bulkWithdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        virtual
        requiresAuth
        nonReentrant
        returns (uint256 assetsOut)
    {
        assetsOut = _withdraw(withdrawAsset, shareAmount, minimumAssets, to);
        emit BulkWithdraw(address(withdrawAsset), shareAmount);
    }

    /**
     * @notice Allows withdrawals from this contract.
     * @dev Either public or disabled depending on configuration.
     */
    function withdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        virtual
        requiresAuth
        nonReentrant
        returns (uint256 assetsOut)
    {
        beforeTransfer(msg.sender, address(0), msg.sender);
        assetsOut = _withdraw(withdrawAsset, shareAmount, minimumAssets, to);
        emit Withdraw(address(withdrawAsset), shareAmount);
    }

    /**
     * @notice Allows withdrawals from this contract with rewards.
     * @dev Either public or disabled depending on configuration.
     */
    function withdrawWithRewards(
        ERC20 withdrawAsset,
        uint256 shareAmount,
        uint256 minimumAssets,
        address to,
        RewardData[] calldata rewards
    ) external virtual requiresAuth nonReentrant returns (uint256 assetsOut) {
        beforeTransfer(msg.sender, address(0), msg.sender);
        assetsOut = _withdraw(withdrawAsset, shareAmount, minimumAssets, to);
        _processRewards(rewards, msg.sender);
        emit Withdraw(address(withdrawAsset), shareAmount);
    }

    /**
     * @notice Allows rewards to be claimed from this contract.
     * @dev Either public or disabled depending on configuration.
     */
    function claimRewards(RewardData[] calldata rewards) external virtual requiresAuth nonReentrant {
        _processRewards(rewards, msg.sender);
    }

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    /**
     * @notice Implements a common ERC20 deposit into BoringVault.
     */
    function _erc20Deposit(
        ERC20 depositAsset,
        uint256 depositAmount,
        uint256 minimumMint,
        address from,
        address to,
        Asset memory asset
    ) internal virtual returns (uint256 shares) {
        _handleDenyList(from, to, msg.sender);
        uint112 cap = depositCap;
        if (depositAmount == 0) revert TellerWithMultiAssetSupport__ZeroAssets();
        shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(depositAsset));
        shares = asset.sharePremium > 0 ? shares.mulDivDown(1e4 - asset.sharePremium, 1e4) : shares;
        if (shares < minimumMint) revert TellerWithMultiAssetSupport__MinimumMintNotMet();
        if (cap != type(uint112).max) {
            if (shares + vault.totalSupply() > cap) revert TellerWithMultiAssetSupport__DepositExceedsCap();
        }
        vault.enter(from, depositAsset, depositAmount, to, shares);
        _afterDeposit(depositAsset, depositAmount);
    }

    /**
     * @notice Implements a common ERC20 withdraw from BoringVault.
     */
    function _withdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        internal
        virtual
        returns (uint256 assetsOut)
    {
        if (isPaused) revert TellerWithMultiAssetSupport__Paused();
        Asset memory asset = assetData[withdrawAsset];
        if (!asset.allowWithdraws) revert TellerWithMultiAssetSupport__AssetNotSupported();

        if (shareAmount == 0) revert TellerWithMultiAssetSupport__ZeroShares();
        assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), ONE_SHARE);
        if (assetsOut < minimumAssets) revert TellerWithMultiAssetSupport__MinimumAssetsNotMet();
        _beforeWithdraw(withdrawAsset, assetsOut);
        vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
        uint256 rate = accountant.getRateSafe();
        _checkpointPrincipalAtRate(msg.sender, shareAmount, false, rate, rate);
    }

    /**
     * @notice Verify compliance signature for a deposit if complianceSigner is set.
     * @dev The depositAsset passed here must be the actual ERC20 token entering the vault.
     *      For native ETH deposits via deposit(), this means the nativeWrapper address,
     *      not the NATIVE sentinel, since conversion happens before this call.
     */
    function _verifyComplianceSignature(
        address depositor,
        ERC20 depositAsset,
        uint256 depositAmount,
        ComplianceData calldata compliance
    ) internal {
        if (complianceSigner == address(0)) return;
        bytes32 messageHash = keccak256(
            abi.encode(
                address(this), block.chainid, depositor, address(depositAsset), depositAmount, compliance.deadline
            )
        );
        _verifyAndMark(messageHash, compliance.deadline, compliance.signature);
    }

    /**
     * @notice Verify bridge compliance: builds the bridge message hash, then verifies and marks the signature.
     * @dev Handles the complianceSigner == address(0) early return internally.
     */
    function _verifyBridgeCompliance(
        address sender,
        uint96 shareAmount,
        address to,
        uint256 deadline,
        bytes calldata signature
    ) internal {
        if (complianceSigner == address(0)) return;
        bytes32 messageHash = keccak256(abi.encode(address(this), block.chainid, sender, shareAmount, to, deadline));
        _verifyAndMark(messageHash, deadline, signature);
    }

    /**
     * @param messageHash The hash of the compliance message.
     * @param deadline The deadline for the compliance signature.
     * @param signature The compliance signature.
     */
    function _verifyAndMark(bytes32 messageHash, uint256 deadline, bytes calldata signature) internal {
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

    /**
     * @notice Handle pre-deposit checks.
     */
    function _beforeDeposit(ERC20 depositAsset) internal view returns (Asset memory asset) {
        if (isPaused) revert TellerWithMultiAssetSupport__Paused();
        asset = assetData[depositAsset];
        if (!asset.allowDeposits) revert TellerWithMultiAssetSupport__AssetNotSupported();
    }

    /**
     * @notice Handle share lock logic, and event.
     */
    function _afterPublicDeposit(
        address user,
        ERC20 depositAsset,
        uint256 depositAmount,
        uint256 shares,
        uint256 currentShareLockPeriod,
        address referralAddress
    ) internal {
        // Increment then assign as its slightly more gas efficient.
        uint256 nonce = ++depositNonce;
        uint256 sharePrice = accountant.getRateSafe();
        // Only set share unlock time and history if share lock period is greater than 0.
        if (currentShareLockPeriod > 0) {
            beforeTransferData[user].shareUnlockTime = uint64(block.timestamp + currentShareLockPeriod);
            publicDepositHistory[nonce] = keccak256(
                abi.encode(
                    user,
                    depositAsset,
                    depositAmount,
                    shares,
                    block.timestamp,
                    currentShareLockPeriod,
                    sharePrice,
                    referralAddress
                )
            );
        }
        emit Deposit(
            nonce,
            user,
            address(depositAsset),
            depositAmount,
            shares,
            block.timestamp,
            currentShareLockPeriod,
            referralAddress
        );
    }

    /**
     * @notice Handle permit logic.
     */
    function _handlePermit(ERC20 depositAsset, uint256 depositAmount, PermitData calldata permit) internal {
        try depositAsset.permit(
            msg.sender, address(vault), depositAmount, permit.deadline, permit.v, permit.r, permit.s
        ) {}
        catch {
            if (depositAsset.allowance(msg.sender, address(vault)) < depositAmount) {
                revert TellerWithMultiAssetSupport__PermitFailedAndAllowanceTooLow();
            }
        }
    }

    /**
     * @notice Appends a principal checkpoint using a caller-specified rate for the base value computation.
     * @dev Used by refundDeposit to record the withdrawal at the deposit-time rate, ensuring the
     *      refund exactly cancels the original deposit's principal impact.
     *      The checkpoint's sharePrice field still records the current rate for point-in-time context.
     * @dev Rounding is intentionally asymmetric to be conservative against the user:
     *      - Deposits round DOWN: records slightly less principal, meaning fewer incentive rewards earned.
     *      - Withdrawals round UP: records slightly more withdrawn, preventing dust accumulation
     *        that would otherwise create phantom principal over repeated deposit/withdraw cycles.
     * @dev Cumulative deposits and withdrawals are stored as uint104, which caps at ~2.03e31.
     *      For an 18-decimal token this is ~20.3 trillion units. If a single user's cumulative
     *      volume exceeds this limit, SafeCast.toUint104 will revert permanently for that user.
     *      This is acceptable for virtually all real-world vaults.
     * @param user The user whose principal history is being updated.
     * @param shares The number of shares involved.
     * @param isDeposit True for deposits, false for withdrawals.
     * @param baseValueRate The rate to use for converting shares to base value.
     * @param currentRate The current rate to record in the checkpoint.
     */
    function _checkpointPrincipalAtRate(
        address user,
        uint256 shares,
        bool isDeposit,
        uint256 baseValueRate,
        uint256 currentRate
    ) internal virtual {
        uint256 len = _principalHistory[user].length;
        if (!isDeposit && len == 0) return;
        uint104 prevDeposits = len > 0 ? _principalHistory[user][len - 1].cumulativeDeposits : 0;
        uint104 prevWithdrawals = len > 0 ? _principalHistory[user][len - 1].cumulativeWithdrawals : 0;
        if (isDeposit) {
            uint256 baseValue = shares.mulDivDown(baseValueRate, ONE_SHARE);
            prevDeposits += SafeCast.toUint104(baseValue);
        } else {
            uint256 baseValue = shares.mulDivUp(baseValueRate, ONE_SHARE);
            prevWithdrawals += SafeCast.toUint104(baseValue);
        }
        _principalHistory[user].push(
            PrincipalCheckpoint(uint48(block.timestamp), prevDeposits, prevWithdrawals, currentRate)
        );
    }

    /**
     * @notice Processes rewards for a user.
     * @param rewards The rewards to process.
     * @param user The user to process rewards for.
     */
    function _processRewards(RewardData[] calldata rewards, address user) internal {
        for (uint256 i; i < rewards.length; ++i) {
            IncentivePool(rewards[i].pool)
                .processRewards(user, rewards[i].cumulativeOwed, rewards[i].deadline, rewards[i].signature);
        }
    }

    /**
     * @notice Executes buffer management after a deposit operation.
     * @dev If a deposit buffer helper is configured for the asset, it retrieves management calls
     * and executes them through the vault's manage function.
     * @param depositAsset The ERC20 token that was deposited.
     * @param assetAmount The amount of the asset that was deposited.
     */
    function _afterDeposit(ERC20 depositAsset, uint256 assetAmount) internal virtual {
        if (address(currentBufferHelpers[depositAsset].depositBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) = currentBufferHelpers[depositAsset].depositBufferHelper
                .getDepositManageCall(address(depositAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }

    /**
     * @notice Executes buffer management before a withdrawal operation.
     * @dev If a withdraw buffer helper is configured for the asset, it retrieves management calls
     * and executes them through the vault's manage function.
     * @param withdrawAsset The ERC20 token that will be withdrawn.
     * @param assetAmount The amount of the asset that will be withdrawn.
     */
    function _beforeWithdraw(ERC20 withdrawAsset, uint256 assetAmount) internal virtual {
        if (address(currentBufferHelpers[withdrawAsset].withdrawBufferHelper) != address(0)) {
            (address[] memory targets, bytes[] memory data, uint256[] memory values) = currentBufferHelpers[withdrawAsset].withdrawBufferHelper
                .getWithdrawManageCall(address(withdrawAsset), assetAmount);
            vault.manage(targets, data, values);
        }
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @notice Returns the full principal checkpoint history for a user.
     */
    function getPrincipalHistory(address user) external view returns (PrincipalCheckpoint[] memory) {
        return _principalHistory[user];
    }

    /**
     * @notice Returns the version of the contract.
     */
    function version() public pure virtual returns (string memory) {
        return "Base V0.3";
    }
}
