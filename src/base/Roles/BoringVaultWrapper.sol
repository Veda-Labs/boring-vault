// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY - NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20 as SolmateERC20} from "@solmate/tokens/ERC20.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport, ComplianceData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithMultiAssetSupportLib} from "src/base/Roles/TellerWithMultiAssetSupportLib.sol";

/// @dev Minimal view used to validate a configured withdrawal queue against this
///      wrapper's BoringVault. Matches BoringOnChainQueue.boringVault().
interface IBoringQueueVault {
    function boringVault() external view returns (address);
    function requestOnChainWithdrawFor(
        address user,
        address assetOut,
        uint128 amountOfShares,
        uint16 discount,
        uint24 secondsToDeadline
    ) external returns (bytes32 requestId);
}

/**
 * @title  BoringVaultWrapper
 * @notice ERC4626 wrapper over a BoringVault. asset() is the BV share.
 *         Fees are realized as wrapper-share dilution; no underlying assets
 *         are ever extracted.
 *
 * @dev Inflation-attack protection: _decimalsOffset() = DECIMALS_OFFSET (6),
 *      making the share conversion `assets * (supply + 10^6) / (totalAssets + 1)`.
 *      Donations are always strictly unprofitable. Wrapper decimals =
 *      BoringVault decimals + DECIMALS_OFFSET.
 *
 * @dev Fee model:
 *      - Management fee: annualized % of AUM, accrued continuously.
 *      - Performance fee: % of appreciation in accountant.getRate() above HWM.
 *      Both are settled before every user action.
 *
 *      If a fee recipient is denyTo on the live Teller at accrual time, that
 *      recipient's shares for the current accrual window are forfeited (never
 *      minted to anyone) rather than reverting the accrual. Accrual runs inside
 *      every deposit/withdraw/redeem path (transfers do not accrue, since they
 *      change no supply or totalAssets), so reverting on a blocked recipient
 *      would let an unrelated Teller-side compliance action freeze deposits and
 *      exits for all users. See _mintFeeShares / FeeSharesForfeited.
 *
 *      The HWM tracks accountant.getRate() and nothing else. The wrapper does
 *      not read feesOwedInBase or any other accountant fee state, so
 *      claimFees / accountant.resetHighwaterMark / fee-config edits cannot
 *      perturb wrapper fee accrual. The wrapper's perf-fee surface equals the
 *      set of updateExchangeRate(...) calls.
 *
 * @dev Direct asset I/O: depositAsset() routes through the Teller's bulkDeposit.
 *      redeemAsset() routes through bulkWithdraw, which is a privileged synchronous
 *      exit that would let wrapper users jump any associated BoringQueue. It is
 *      therefore DISABLED whenever a withdrawal queue is configured (see setQueue):
 *      under a queue, users exit via the standard ERC4626 redeem/withdraw, which
 *      hand back BV shares (asset() == BV share) with no teller/queue interaction,
 *      and then queue those BV shares themselves on equal footing with direct
 *      BV holders.
 *
 * @dev Share lock: bulkDeposit does not set the Teller's per-holder share lock on
 *      the wrapper's BV position, so the wrapper would otherwise be a lock bypass.
 *      To close that, the wrapper enforces its OWN per-holder lock at the wrapper-
 *      share layer: on every deposit/mint/depositAsset it snapshots the period the
 *      BoringVault actually enforces -- read from boringVault.hook().shareLockPeriod()
 *      so it can never diverge from the BV's authoritative enforcer -- and locks the
 *      receiver's wrapper shares for that duration. The lock is enforced on wrapper-
 *      share transfers and on every exit (withdraw / redeem / redeemAsset). The
 *      period is snapshotted at deposit time, never read live at exit, so a later
 *      setShareLockPeriod / setBeforeTransferHook cannot retroactively mutate an
 *      existing holder's lock (matching how the BV itself snapshots).
 *
 *      Because the lock is keyed on the receiver, deposit/mint/depositAsset require
 *      receiver == caller. Otherwise a third party could mint dust to an arbitrary
 *      receiver to perpetually refresh that receiver's lock (grief), and the symmetric
 *      relaxation (skip the lock when receiver != caller) would be a lock bypass via a
 *      helper contract. Requiring receiver == caller makes the lock strictly self-
 *      imposed, closing both. This is stricter than the BV Teller, which locks an
 *      arbitrary `to`.
 *
 * @dev Compliance: denylist + transfer allowlist + signature checks are read
 *      live from the Teller and enforced on the real user identity (not the
 *      wrapper address). Compliance signatures are wrapper-scoped via
 *      address(this) in the message hash; replay protection is local.
 *
 *      Assumption: the wrapper's own address is never denylisted on the Teller.
 *      depositAsset() and standard withdraw/redeem move BV shares through calls
 *      where the wrapper itself is from/to/operator at the BV layer (bulkDeposit,
 *      and the BV-token transfer() inside ERC4626 withdraw/redeem) -- denylisting
 *      the wrapper there would block those paths for every user with no owner-side
 *      recovery. Out of scope to defend against; assumed to hold operationally.
 *
 * @dev Fees-on-fees: BV-level and wrapper-level fees are additive. End users
 *      pay both layers.
 *
 * @dev White-labeling: deploy one instance per partner with independent
 *      name / symbol / fee recipients / fee rates over the same BoringVault.
 *      The management fee and performance fee are paid to independently
 *      configured non-zero recipients (managementFeeRecipient /
 *      performanceFeeRecipient). Set fee rates to 0 to disable either fee.
 */
contract BoringVaultWrapper is ERC4626, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // =========================================================================
    //                              CONSTANTS
    // =========================================================================

    /// @notice Hard cap on the annual management fee: 5% (500 bps).
    uint16 public constant MAX_MANAGEMENT_FEE = 500;

    /// @notice Hard cap on the performance fee: 50% (5_000 bps).
    uint16 public constant MAX_PERFORMANCE_FEE = 5_000;

    /// @notice Minimum drawdown (bps below HWM) required for resetHighWaterMark().
    ///         10% prevents gaming small or transient dips.
    uint16 public constant MIN_HWM_RESET_DRAWDOWN_BPS = 1_000;

    /// @notice Virtual-share offset for inflation-attack mitigation.
    uint8 public constant DECIMALS_OFFSET = 6;

    // =========================================================================
    //                              IMMUTABLES
    // =========================================================================

    /// @notice The BoringVault whose shares are this wrapper's underlying asset.
    BoringVault public immutable boringVault;

    /// @notice Accountant providing the BV share price via getRate() / getRateSafe().
    ///         Only those two functions are read; no internal fee state is touched.
    AccountantWithRateProviders public immutable accountant;

    // =========================================================================
    //                               STATE
    // =========================================================================

    /// @notice Optional withdrawal queue associated with the BoringVault. When set
    ///         (non-zero), the privileged synchronous redeemAsset() path is disabled
    ///         so wrapper users cannot jump the queue via bulkWithdraw.
    address public queue;

    /// @notice Recipient of accrued management-fee shares.
    address public managementFeeRecipient;

    /// @notice Recipient of accrued performance-fee shares.
    address public performanceFeeRecipient;

    /// @notice Annual management fee in basis points (e.g. 200 = 2%).
    uint16 public managementFee;

    /// @notice Performance fee in basis points (e.g. 1_000 = 10%).
    uint16 public performanceFee;

    /// @notice Block timestamp of the last fee accrual.
    uint64 public lastFeeAccrual;

    /// @notice BV exchange rate above which the performance fee fires, in the
    ///         same unit as accountant.getRate().
    uint96 public performanceHighWaterMark;

    /// @notice Replay protection for wrapper-domain compliance signatures.
    mapping(bytes32 messageHash => bool used) public usedComplianceSignatures;

    /// @notice Per-holder wrapper-share unlock timestamp. Set on deposit/mint/
    ///         depositAsset from a snapshot of the Teller's shareLockPeriod, and
    ///         enforced on wrapper-share transfers and every exit path.
    mapping(address holder => uint64 unlockTime) public shareUnlockTime;

    // =========================================================================
    //                               ERRORS
    // =========================================================================

    error BoringVaultWrapper__ZeroAddress();
    error BoringVaultWrapper__FeeTooHigh();
    error BoringVaultWrapper__ZeroBVSharesReceived();
    error BoringVaultWrapper__BadAccountant();
    error BoringVaultWrapper__TransferDenied(address from, address to, address operator);
    error BoringVaultWrapper__TransferNotAllowed();
    /// @dev resetHighWaterMark() when rate >= HWM. Normal accrual handles that case.
    error BoringVaultWrapper__HWMResetNotNeeded();
    /// @dev resetHighWaterMark() when drawdown < MIN_HWM_RESET_DRAWDOWN_BPS.
    error BoringVaultWrapper__DrawdownTooSmall();
    /// @dev Wrapper shares are still within their share-lock window.
    error BoringVaultWrapper__SharesLocked(address holder);
    /// @dev setQueue() with a queue whose boringVault() != this wrapper's vault.
    error BoringVaultWrapper__BadQueue();
    /// @dev redeemAsset() while a withdrawal queue is configured. Use redeem/withdraw.
    error BoringVaultWrapper__RedeemAssetDisabledWithQueue();
    /// @dev requestOnChainWithdrawFromQueue() called before a queue is configured.
    error BoringVaultWrapper__QueueNotSet();
    /// @dev Wrapper share redemption produced more BV shares than the queue can store.
    error BoringVaultWrapper__Overflow();
    /// @dev setQueue() called by an address that is not the underlying BoringVault
    ///      owner. Queue governance belongs to the BV operator,
    ///      not the partner wrapper admin, so that no partner can unilaterally bypass
    ///      a BoringQueue by simply omitting the setQueue() call.
    error BoringVaultWrapper__NotBVAuthorized();
    /// @dev deposit/mint/depositAsset with receiver != caller. The share lock is a
    ///      per-holder window keyed on the receiver; allowing a third party to mint
    ///      to an arbitrary receiver would let anyone refresh that receiver's lock
    ///      (grief). Requiring receiver == caller makes the lock self-imposed only.
    error BoringVaultWrapper__ReceiverMustBeCaller();
    /// @dev setFeeConfig() or constructor called with a fee recipient that is
    ///      currently flagged denyTo on the Teller. Setting a denylisted address
    ///      would freeze the wrapper on the very next fee accrual.
    error BoringVaultWrapper__FeeRecipientDenylisted(address recipient);
    /// @dev deposit()/mint() are disabled — BV shares are this wrapper's asset() and wrapping
    ///      them adds a fees-on-fees layer with no rational use case. Use depositAsset() instead.
    error BoringVaultWrapper__DirectDepositDisabled();

    // =========================================================================
    //                               EVENTS
    // =========================================================================

    event FeesAccrued(uint256 managementFeeShares, uint256 performanceFeeShares);
    event FeeConfigSet(
        address indexed oldManagementFeeRecipient,
        address indexed newManagementFeeRecipient,
        address oldPerformanceFeeRecipient,
        address newPerformanceFeeRecipient,
        uint16 oldManagementFee,
        uint16 newManagementFee,
        uint16 oldPerformanceFee,
        uint16 newPerformanceFee
    );
    /// @notice Emitted when a management or performance fee recipient is denyTo on the
    ///         live Teller at accrual time. `shares` were computed but never minted to
    ///         anyone -- that recipient's slice of the current accrual window is
    ///         forfeited, not deferred. lastFeeAccrual still advances, so the forfeited
    ///         period is not retried later.
    event FeeSharesForfeited(address indexed recipient, uint256 shares);
    event QueueSet(address oldQueue, address newQueue);
    event ShareLockSet(address indexed receiver, uint64 unlockTime);
    event HighWaterMarkUpdated(uint96 oldHighWaterMark, uint96 newHighWaterMark);

    /// @notice Emitted by depositAsset() with the raw-asset entry context that
    ///         the standard ERC4626 Deposit event hides (which logs BV shares).
    event AssetDeposit(
        address indexed caller,
        address indexed receiver,
        address indexed rawAsset,
        uint256 rawAmount,
        uint256 bvReceived,
        uint256 wrapperShares
    );

    /// @notice Emitted by redeemAsset() with the raw-asset exit context.
    event AssetRedeem(
        address indexed caller,
        address indexed receiver,
        address indexed rawAsset,
        address owner,
        uint256 wrapperShares,
        uint256 bvRedeemed,
        uint256 assetOut
    );

    /// @notice Emitted by requestOnChainWithdrawFromQueue() with the queue-request exit
    ///         context. The queue, not `user`, actually custodies `bvQueued` until the
    ///         request is solved or canceled, so this is tracked separately from the
    ///         generic ERC4626 Withdraw event (which is emitted with receiver = user).
    event QueuedWithdrawRequested(
        address indexed user,
        address indexed queue,
        address indexed assetOut,
        uint256 wrapperShares,
        uint256 bvQueued,
        bytes32 requestId
    );

    // =========================================================================
    //                             CONSTRUCTOR
    // =========================================================================

    constructor(
        address _owner,
        address _boringVault,
        address _accountant,
        string memory _name,
        string memory _symbol,
        address _managementFeeRecipient,
        address _performanceFeeRecipient,
        uint16 _managementFee,
        uint16 _performanceFee
    ) ERC4626(IERC20(_boringVault)) ERC20(_name, _symbol) Ownable(_owner) {
        if (address(AccountantWithRateProviders(_accountant).vault()) != address(_boringVault)) {
            revert BoringVaultWrapper__BadAccountant();
        }
        boringVault = BoringVault(payable(_boringVault));
        accountant = AccountantWithRateProviders(_accountant);

        _validateFeeConfig(_managementFeeRecipient, _performanceFeeRecipient, _managementFee, _performanceFee);

        managementFeeRecipient = _managementFeeRecipient;
        performanceFeeRecipient = _performanceFeeRecipient;
        managementFee = _managementFee;
        performanceFee = _performanceFee;

        // Seed HWM at the current gross rate.
        performanceHighWaterMark = SafeCast.toUint96(AccountantWithRateProviders(_accountant).getRateSafe());
    }

    // =========================================================================
    //                              ADMIN
    // =========================================================================

    /// @notice Set fee recipients and rates for both the management and performance fee.
    ///         Settles any outstanding fees at the current configuration first so no
    ///         appreciation is retroactively re-priced by a rate change.
    /// @param _managementFeeRecipient  Recipient of minted management-fee shares. Must be non-zero.
    /// @param _performanceFeeRecipient Recipient of minted performance-fee shares. Must be non-zero.
    /// @param _managementFee  Annual management fee in basis points. Capped at MAX_MANAGEMENT_FEE (500 bps).
    /// @param _performanceFee Performance fee in basis points. Capped at MAX_PERFORMANCE_FEE (5_000 bps).
    function setFeeConfig(
        address _managementFeeRecipient,
        address _performanceFeeRecipient,
        uint16 _managementFee,
        uint16 _performanceFee
    ) external onlyOwner {
        _validateFeeConfig(_managementFeeRecipient, _performanceFeeRecipient, _managementFee, _performanceFee);

        _accrueFees();
        emit FeeConfigSet(
            managementFeeRecipient,
            _managementFeeRecipient,
            performanceFeeRecipient,
            _performanceFeeRecipient,
            managementFee,
            _managementFee,
            performanceFee,
            _performanceFee
        );
        managementFeeRecipient = _managementFeeRecipient;
        performanceFeeRecipient = _performanceFeeRecipient;
        managementFee = _managementFee;
        performanceFee = _performanceFee;
    }

    /// @notice Associate (or clear) a withdrawal queue. While a non-zero queue is
    ///         set, redeemAsset() reverts so wrapper users cannot bypass the queue
    ///         via the privileged synchronous bulkWithdraw path. Pass address(0) to
    ///         re-enable redeemAsset (only for vaults that have no queue).
    ///
    /// @dev Authorization is delegated to the UNDERLYING BORINGVAULT'S owner. Queue
    ///      discipline is a BV-level governance concern: a partner wrapper admin must
    ///      not be able to bypass an active BoringQueue by simply never calling this
    ///      function, or by calling setQueue(0) to clear it. Only the BV owner may
    ///      configure the queue association — no capability registration or selector
    ///      check against the BV's authority is required.
    /// @param newQueue Address of the BoringOnChainQueue to associate, or address(0) to
    ///                 clear the queue and re-enable redeemAsset().
    /// @dev FOOTGUN: clearing the queue (newQueue == address(0)) while a real BoringQueue
    ///      is still the vault's live exit mechanism immediately reopens redeemAsset(),
    ///      letting wrapper users jump that queue and drain the liquid buffer ahead of
    ///      queued holders. Only clear when the vault genuinely has no queue.
    function setQueue(address newQueue) external {
        _requiresBVAuth();
        if (newQueue != address(0) && IBoringQueueVault(newQueue).boringVault() != address(boringVault)) {
            revert BoringVaultWrapper__BadQueue();
        }
        emit QueueSet(queue, newQueue);
        queue = newQueue;
    }

    /**
     * @notice Reset the performance-fee HWM to the current BV rate. Intended
     *         for drawdown recovery: while the rate is below the HWM, perf
     *         fees are frozen until this is called. Settles outstanding fees
     *         at the old HWM first. Reverts if the accountant is paused.
     */
    function resetHighWaterMark() external onlyOwner {
        uint96 hwm = performanceHighWaterMark;
        uint96 newHWM_ = SafeCast.toUint96(accountant.getRateSafe());

        // Rate >= HWM: the normal accrual path already handles this regime.
        if (newHWM_ >= hwm) revert BoringVaultWrapper__HWMResetNotNeeded();

        // Block resets on minor dips so admin cannot collect perf fee on the
        // immediate recovery. Require rate <= hwm * (1 - MIN_DRAWDOWN/1e4).
        if (uint256(newHWM_) > uint256(hwm) * (1e4 - MIN_HWM_RESET_DRAWDOWN_BPS) / 1e4) {
            revert BoringVaultWrapper__DrawdownTooSmall();
        }

        // Settle at the old HWM first. rate < HWM here, so this won't advance it.
        _accrueFees();

        emit HighWaterMarkUpdated(hwm, newHWM_);
        performanceHighWaterMark = newHWM_;
    }

    // =========================================================================
    //                         ERC4626 - totalAssets
    // =========================================================================

    /// @notice Total BV shares held by this wrapper, used as the ERC4626 asset base.
    function totalAssets() public view override returns (uint256) {
        return boringVault.balanceOf(address(this));
    }

    // =========================================================================
    //                       ERC4626 - virtual offset
    // =========================================================================

    function _decimalsOffset() internal pure override returns (uint8) {
        return DECIMALS_OFFSET;
    }

    // =========================================================================
    //                    ERC4626 - public entrypoints
    // =========================================================================
    // Each entrypoint: (1) enforce compliance on the real user, (2) settle
    // pending fees, (3) delegate to OZ super(). Conversion uses the overridden
    // _convertToShares / _convertToAssets below.

    /// @notice Disabled. BV shares are this wrapper's asset(); wrapping them adds a
    ///         fees-on-fees layer with no rational use case. Use depositAsset() instead.
    function deposit(uint256, address) public pure override returns (uint256) {
        revert BoringVaultWrapper__DirectDepositDisabled();
    }

    /// @notice Disabled. BV shares are this wrapper's asset(); wrapping them adds a
    ///         fees-on-fees layer with no rational use case. Use depositAsset() instead.
    function mint(uint256, address) public pure override returns (uint256) {
        revert BoringVaultWrapper__DirectDepositDisabled();
    }

    /// @notice Withdraw BV shares by burning the corresponding wrapper shares.
    /// @dev Compliance (denylist + allowlist) is enforced on `shareOwner`, `receiver`,
    ///      and the caller. `shareOwner`'s share lock is checked before exit. Fees are
    ///      settled before conversion so the caller redeems at the post-accrual rate.
    function withdraw(uint256 assets, address receiver, address shareOwner)
        public
        override
        nonReentrant
        returns (uint256)
    {
        _enforceTransferPolicy(shareOwner, receiver, _msgSender());
        _enforceShareLock(shareOwner);
        _accrueFees();
        return super.withdraw(assets, receiver, shareOwner);
    }

    /// @notice Burn wrapper shares and receive the proportional BV shares.
    /// @dev Compliance (denylist + allowlist) is enforced on `shareOwner`, `receiver`,
    ///      and the caller. `shareOwner`'s share lock is checked before exit. Fees are
    ///      settled before conversion so the caller redeems at the post-accrual rate.
    function redeem(uint256 shares, address receiver, address shareOwner)
        public
        override
        nonReentrant
        returns (uint256)
    {
        _enforceTransferPolicy(shareOwner, receiver, _msgSender());
        _enforceShareLock(shareOwner);
        _accrueFees();
        return super.redeem(shares, receiver, shareOwner);
    }

    // =========================================================================
    //                       ERC4626 - exit caps
    // =========================================================================
    // The share lock is all-or-nothing per holder: while shareUnlockTime[shareOwner]
    // is in the future, every exit path reverts. Reflect that in the ERC4626
    // caps so integrators that quote max*() before exiting don't get a value the
    // contract will then reject.

    /// @notice Always returns 0 — direct BV-share deposits are disabled.
    function maxDeposit(address) public pure override returns (uint256) {
        return 0;
    }

    /// @notice Always returns 0 — direct BV-share mints are disabled.
    function maxMint(address) public pure override returns (uint256) {
        return 0;
    }

    /// @notice Always returns 0 — direct BV-share deposits are disabled.
    ///         Consistent with maxDeposit(); prevents ERC4626 integrators from quoting
    ///         a non-zero preview for an entry path that always reverts.
    function previewDeposit(uint256) public pure override returns (uint256) {
        return 0;
    }

    /// @notice Always returns 0 — direct BV-share mints are disabled.
    ///         Consistent with maxMint(); prevents ERC4626 integrators from quoting
    ///         a non-zero preview for an entry path that always reverts.
    function previewMint(uint256) public pure override returns (uint256) {
        return 0;
    }

    /// @notice Returns 0 while `shareOwner`'s wrapper shares are within their share-lock
    ///         window; otherwise delegates to the ERC4626 base implementation.
    function maxWithdraw(address shareOwner) public view override returns (uint256) {
        if (shareUnlockTime[shareOwner] > block.timestamp) return 0;
        return super.maxWithdraw(shareOwner);
    }

    /// @notice Returns 0 while `shareOwner`'s wrapper shares are within their share-lock
    ///         window; otherwise delegates to the ERC4626 base implementation.
    function maxRedeem(address shareOwner) public view override returns (uint256) {
        if (shareUnlockTime[shareOwner] > block.timestamp) return 0;
        return super.maxRedeem(shareOwner);
    }

    // =========================================================================
    //                              RATE VIEWS
    // =========================================================================

    /// @notice Get one wrapper share's current rate in the BoringVault's base asset.
    /// @dev Scales the BV share rate by this wrapper's current BV-share entitlement per
    ///      full wrapper token, incorporating simulated pending wrapper fee dilution.
    ///      Equivalent to the rate that would be observed immediately after _accrueFees() runs.
    ///      WARNING: does not check whether the accountant is paused. Use getRateSafe()
    ///      for any on-chain consumer that must not act on a potentially stale rate.
    function getRate() public view returns (uint256 rate) {
        rate = _rateFromBoringVaultRate(accountant.getRate());
    }

    /// @notice Get one wrapper share's current rate in the BoringVault's base asset.
    /// @dev Incorporates simulated pending wrapper-fee dilution; equivalent to the rate
    ///      that would be observed immediately after _accrueFees() runs.
    ///      Reverts if the accountant is paused.
    function getRateSafe() external view returns (uint256 rate) {
        rate = _rateFromBoringVaultRate(accountant.getRateSafe());
    }

    /// @notice Get one wrapper share's current rate in a BoringVault quote asset.
    /// @dev `quote` must be configured on the accountant, matching BV secondary assets.
    ///      Incorporates simulated pending wrapper-fee dilution; equivalent to the rate
    ///      that would be observed immediately after _accrueFees() runs.
    ///      WARNING: does not check whether the accountant is paused. Use getRateInQuoteSafe()
    ///      for any on-chain consumer that must not act on a potentially stale rate.
    function getRateInQuote(IERC20 quote) public view returns (uint256 rateInQuote) {
        rateInQuote = _rateFromBoringVaultRate(accountant.getRateInQuote(SolmateERC20(address(quote))));
    }

    /// @notice Get one wrapper share's current rate in a BoringVault quote asset.
    /// @dev `quote` must be configured on the accountant.
    ///      Incorporates simulated pending wrapper-fee dilution; equivalent to the rate
    ///      that would be observed immediately after _accrueFees() runs.
    ///      Reverts if the accountant is paused.
    function getRateInQuoteSafe(IERC20 quote) external view returns (uint256 rateInQuote) {
        rateInQuote = _rateFromBoringVaultRate(accountant.getRateInQuoteSafe(SolmateERC20(address(quote))));
    }

    // =========================================================================
    //                ERC4626 - share/asset conversion overrides
    // =========================================================================
    // Use simulated post-accrual state so off-chain previews match on-chain
    // execution even when _accrueFees() has not run recently.

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return assets.mulDiv(supply + 10 ** DECIMALS_OFFSET, totalAss + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return shares.mulDiv(totalAss + 1, supply + 10 ** DECIMALS_OFFSET, rounding);
    }

    // =========================================================================
    //                  ERC20 - wrapper share transfer hooks
    // =========================================================================

    /// @notice Transfer wrapper shares to `to`. Enforces denylist/allowlist compliance
    ///         and the sender's share-lock window before delegating to ERC20.
    function transfer(address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _enforceTransferPolicy(_msgSender(), to, _msgSender());
        _enforceShareLock(_msgSender());
        return super.transfer(to, amount);
    }

    /// @notice Transfer wrapper shares from `from` to `to` on behalf of the caller.
    ///         Enforces denylist/allowlist compliance and `from`'s share-lock window
    ///         before delegating to ERC20.
    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _enforceTransferPolicy(from, to, _msgSender());
        _enforceShareLock(from);
        return super.transferFrom(from, to, amount);
    }

    // =========================================================================
    //                       DIRECT ASSET DEPOSIT
    // =========================================================================

    /// @notice Deposit a raw asset (WETH, USDC, …) and receive wrapper shares in one
    ///         transaction. Routes through the Teller's bulkDeposit to obtain BV shares,
    ///         then mints wrapper shares proportional to the BV shares received:
    ///         wrapperShares = bvReceived * (supplyBefore + 10^offset) / (bvBefore + 1).
    /// @dev A compliance signature is required when the Teller's complianceSignerRole is
    ///      active. Replay protection is wrapper-scoped and independent from the Teller's
    ///      own signature tracking. Reverts if the Teller returns zero BV shares.
    ///      `receiver` must equal `msg.sender` — same share-lock rationale as deposit().
    ///      SETUP REQUIRED: `bulkDeposit` is `requiresAuth` (Solver role) on the Teller, so
    ///      this wrapper must be granted that role before depositAsset() will succeed.
    /// @param rawAsset    ERC20 token accepted by the underlying Teller.
    /// @param rawAmount   Amount of `rawAsset` to deposit.
    /// @param minBVShares Minimum BV shares the Teller must return; slippage guard.
    /// @param receiver    Recipient of the minted wrapper shares. Must equal msg.sender.
    /// @param compliance  Deadline and signature for the compliance check. Pass an empty
    ///                    struct when the Teller has compliance disabled.
    /// @return wrapperShares Number of wrapper shares minted to `receiver`.
    function depositAsset(
        SolmateERC20 rawAsset,
        uint256 rawAmount,
        uint256 minBVShares,
        address receiver,
        ComplianceData calldata compliance
    ) external nonReentrant returns (uint256 wrapperShares) {
        if (receiver != _msgSender()) revert BoringVaultWrapper__ReceiverMustBeCaller();

        TellerWithMultiAssetSupport teller = _getTeller();

        _enforceCallerPolicy(teller, _msgSender());
        _verifyComplianceSignature(teller, _msgSender(), receiver, address(rawAsset), rawAmount, compliance);

        _accrueFees();

        uint256 bvBefore = boringVault.balanceOf(address(this));
        uint256 supplyBefore = totalSupply();

        IERC20 asset_ = IERC20(address(rawAsset));
        asset_.safeTransferFrom(_msgSender(), address(this), rawAmount);
        asset_.forceApprove(address(boringVault), rawAmount);

        teller.bulkDeposit(rawAsset, rawAmount, minBVShares, address(this));

        uint256 bvReceived = boringVault.balanceOf(address(this)) - bvBefore;
        if (bvReceived == 0) revert BoringVaultWrapper__ZeroBVSharesReceived();

        wrapperShares = bvReceived.mulDiv(supplyBefore + 10 ** DECIMALS_OFFSET, bvBefore + 1, Math.Rounding.Floor);

        if (wrapperShares == 0) revert BoringVaultWrapper__ZeroBVSharesReceived();

        _mint(receiver, wrapperShares);
        _applyShareLock(receiver);

        emit Deposit(_msgSender(), receiver, bvReceived, wrapperShares);
        emit AssetDeposit(_msgSender(), receiver, address(rawAsset), rawAmount, bvReceived, wrapperShares);
    }

    // =========================================================================
    //                       DIRECT ASSET REDEEM
    // =========================================================================

    /// @notice Burn wrapper shares and withdraw a raw asset in one transaction. Routes
    ///         through the Teller's bulkWithdraw for synchronous exit. Disabled when a
    ///         withdrawal queue is configured (reverts with RedeemAssetDisabledWithQueue)
    ///         to prevent wrapper users from bypassing the queue.
    /// @dev Compliance and share lock are enforced before the burn. The caller must be
    ///      `shareOwner` or hold sufficient ERC20 allowance.
    ///      SETUP REQUIRED: `bulkWithdraw` is `requiresAuth` (Solver role) on the Teller, so
    ///      this wrapper must be granted that role before redeemAsset() will succeed.
    /// @param asset         ERC20 token to receive, must be supported by the Teller.
    /// @param wrapperShares Number of wrapper shares to burn.
    /// @param minAssetOut   Minimum raw-asset amount the Teller must return; slippage guard.
    /// @param receiver      Recipient of the withdrawn assets.
    /// @param shareOwner    Owner of the wrapper shares being redeemed.
    /// @return assetOut     Amount of `asset` delivered to `receiver`.
    function redeemAsset(
        SolmateERC20 asset,
        uint256 wrapperShares,
        uint256 minAssetOut,
        address receiver,
        address shareOwner
    ) external nonReentrant returns (uint256 assetOut) {
        if (queue != address(0)) revert BoringVaultWrapper__RedeemAssetDisabledWithQueue();

        TellerWithMultiAssetSupport teller = _getTeller();

        _enforceTransferPolicy(teller, shareOwner, receiver, _msgSender());
        _enforceShareLock(shareOwner);

        _accrueFees();

        if (_msgSender() != shareOwner) {
            _spendAllowance(shareOwner, _msgSender(), wrapperShares);
        }

        uint256 supply = totalSupply();
        uint256 totalBV = boringVault.balanceOf(address(this));

        uint256 bvToRedeem = wrapperShares.mulDiv(totalBV + 1, supply + 10 ** DECIMALS_OFFSET, Math.Rounding.Floor);

        _burn(shareOwner, wrapperShares);

        assetOut = teller.bulkWithdraw(asset, bvToRedeem, minAssetOut, receiver);

        emit Withdraw(_msgSender(), receiver, shareOwner, bvToRedeem, wrapperShares);
        emit AssetRedeem(_msgSender(), receiver, address(asset), shareOwner, wrapperShares, bvToRedeem, assetOut);
    }

    // =========================================================================
    //                         QUEUED ASSET REDEEM
    // =========================================================================

    /// @notice Burn wrapper shares and queue the resulting BV shares for withdrawal.
    /// @dev The configured queue must authorize this wrapper to call
    ///      requestOnChainWithdrawFor(). The queued request is owned by msg.sender,
    ///      so the user receives assets when solved and retains normal cancel/replace
    ///      rights. Wrapper share lock and Teller transfer policy are enforced before
    ///      burning.
    /// @param assetOut The asset to withdraw from the queue.
    /// @param wrapperShares Number of wrapper shares to burn.
    /// @param discount The discount to apply to the withdraw in bps.
    /// @param secondsToDeadline The time in seconds the request is valid for.
    /// @return requestId The queue request Id.
    /// @dev SETUP REQUIRED: the queue's `requestOnChainWithdrawFor` is `requiresAuth`, so
    ///      this wrapper must be granted a role on the queue's RolesAuthority authorizing
    ///      that call before this function will succeed -- setQueue() alone does not grant it.
    function requestOnChainWithdrawFromQueue(
        address assetOut,
        uint256 wrapperShares,
        uint16 discount,
        uint24 secondsToDeadline
    ) external nonReentrant returns (bytes32 requestId) {
        address queue_ = queue;
        if (queue_ == address(0)) revert BoringVaultWrapper__QueueNotSet();

        address user = _msgSender();
        // Single-party operation: `user` burns their own shares and is also the
        // eventual beneficiary of the queued request (from == to == operator == user
        // economically), so this uses the same optimised single-party compliance check
        // as depositAsset() rather than treating the queue escrow address as `to`.
        _enforceCallerPolicy(_getTeller(), user);
        _enforceShareLock(user);

        _accrueFees();

        uint256 supply = totalSupply();
        uint256 totalBV = boringVault.balanceOf(address(this));

        uint256 bvToQueue = wrapperShares.mulDiv(totalBV + 1, supply + 10 ** DECIMALS_OFFSET, Math.Rounding.Floor);
        if (bvToQueue > type(uint128).max) revert BoringVaultWrapper__Overflow();

        _burn(user, wrapperShares);

        IERC20(address(boringVault)).forceApprove(queue_, bvToQueue);
        requestId = IBoringQueueVault(queue_)
            .requestOnChainWithdrawFor(user, assetOut, uint128(bvToQueue), discount, secondsToDeadline);

        // receiver = user (not queue_): `user` is the economic beneficiary of the
        // eventual withdrawal, matching the ERC4626 Withdraw event's intended semantics.
        // The queue is only a mechanical escrow; QueuedWithdrawRequested below carries
        // that detail plus the request id for indexers.
        emit Withdraw(user, user, user, bvToQueue, wrapperShares);
        emit QueuedWithdrawRequested(user, queue_, assetOut, wrapperShares, bvToQueue, requestId);
    }

    // =========================================================================
    //                         INTERNAL - FEE ENGINE
    // =========================================================================

    function _pendingFeeShares() internal view returns (uint256 mgmtShares, uint256 perfShares, uint96 newHWM) {
        uint256 supply = totalSupply();
        if (supply == 0) return (0, 0, 0);

        uint16 mgmtFee = managementFee;
        uint256 elapsed = block.timestamp - lastFeeAccrual;

        if (mgmtFee > 0 && elapsed > 0) {
            mgmtShares = supply.mulDiv(uint256(mgmtFee) * elapsed, uint256(1e4) * 365 days, Math.Rounding.Floor);
        }

        // Always read the rate so the HWM advances even when performanceFee = 0;
        // otherwise re-enabling the fee would retroactively charge appreciation
        // accrued during the zero-fee window.
        try accountant.getRateSafe() returns (uint256 currentRate) {
            uint96 hwm = performanceHighWaterMark;

            if (currentRate > uint256(hwm)) {
                newHWM = SafeCast.toUint96(currentRate);

                uint16 perfFee = performanceFee;
                if (perfFee > 0) {
                    uint256 totalBV = totalAssets();

                    uint256 gainBV = totalBV.mulDiv(currentRate - uint256(hwm), currentRate, Math.Rounding.Floor);
                    uint256 feeBV = gainBV.mulDiv(perfFee, 1e4, Math.Rounding.Floor);

                    if (feeBV > 0 && totalBV > 0) {
                        perfShares = feeBV.mulDiv(supply + mgmtShares, totalBV, Math.Rounding.Floor);
                    }
                }
            }
        } catch {
            // Accountant paused: skip perf-fee + HWM tracking. Mgmt fee is unaffected.
        }
    }

    /// @notice Trigger a manual fee accrual. Settles pending management and performance
    ///         fees, mints the resulting shares, and advances the high-water mark.
    ///         Callable by anyone; no-ops when supply is zero or no management,
    ///         performance, or HWM update is pending.
    function accrueFees() external {
        _accrueFees();
    }

    function _accrueFees() internal {
        uint64 now_ = uint64(block.timestamp);

        if (totalSupply() == 0) {
            lastFeeAccrual = now_;
            // No shares exist to dilute, but the HWM must keep tracking the rate so
            // a later first depositor is not charged a performance fee on
            // appreciation that predates their deposit (mirrors the constructor's
            // HWM seeding and the zero-fee-window rationale in _pendingFeeShares).
            // Skipped while the accountant is paused.
            try accountant.getRateSafe() returns (uint256 currentRate) {
                uint96 cur = SafeCast.toUint96(currentRate);
                if (cur > performanceHighWaterMark) {
                    emit HighWaterMarkUpdated(performanceHighWaterMark, cur);
                    performanceHighWaterMark = cur;
                }
            } catch {}
            return;
        }

        (uint256 mgmtShares, uint256 perfShares, uint96 newHWM) = _pendingFeeShares();

        if (newHWM != 0) {
            emit HighWaterMarkUpdated(performanceHighWaterMark, newHWM);
            performanceHighWaterMark = newHWM;
        }

        lastFeeAccrual = now_;

        if (mgmtShares + perfShares == 0) return;

        // Management and performance portions are routed to their own recipients and
        // checked independently. A denyTo recipient forfeits that recipient's slice
        // (see _mintFeeShares) rather than reverting -- accrual must never be able to
        // freeze user withdraw/redeem/deposit/transfer, which all settle fees first.
        TellerWithMultiAssetSupport teller = _getTeller();
        uint256 mgmtMinted = _mintFeeShares(teller, managementFeeRecipient, mgmtShares);
        uint256 perfMinted = _mintFeeShares(teller, performanceFeeRecipient, perfShares);
        emit FeesAccrued(mgmtMinted, perfMinted);
    }

    function _isFeeRecipientBlocked(TellerWithMultiAssetSupport teller, address recipient) private view returns (bool) {
        if (address(teller) == address(0)) return false;
        (, bool denyTo,,) = teller.beforeTransferData(recipient);
        return denyTo;
    }

    /// @notice Validate a proposed fee configuration: non-zero recipients, fee caps,
    ///         and neither recipient currently denyTo on the live Teller.
    ///         The denylist check is a no-op when no hook is wired (address(0) teller).
    function _validateFeeConfig(address mgmtRecipient, address perfRecipient, uint16 mgmtFee, uint16 perfFee)
        internal
        view
    {
        if (mgmtRecipient == address(0) || perfRecipient == address(0)) {
            revert BoringVaultWrapper__ZeroAddress();
        }
        if (mgmtFee > MAX_MANAGEMENT_FEE) revert BoringVaultWrapper__FeeTooHigh();
        if (perfFee > MAX_PERFORMANCE_FEE) revert BoringVaultWrapper__FeeTooHigh();

        TellerWithMultiAssetSupport teller_ = _getTeller();
        if (_isFeeRecipientBlocked(teller_, mgmtRecipient)) {
            revert BoringVaultWrapper__FeeRecipientDenylisted(mgmtRecipient);
        }
        if (_isFeeRecipientBlocked(teller_, perfRecipient)) {
            revert BoringVaultWrapper__FeeRecipientDenylisted(perfRecipient);
        }
    }

    /// @notice Mint `shares` fee shares to `recipient`, or forfeit them if `recipient`
    ///         is currently denyTo on `teller`. Forfeiting (rather than reverting) keeps
    ///         fee collection from ever being able to block user-facing wrapper actions.
    /// @return minted The amount actually minted (0 if forfeited).
    function _mintFeeShares(TellerWithMultiAssetSupport teller, address recipient, uint256 shares)
        private
        returns (uint256 minted)
    {
        if (shares == 0) return 0;
        if (_isFeeRecipientBlocked(teller, recipient)) {
            emit FeeSharesForfeited(recipient, shares);
            return 0;
        }
        _mint(recipient, shares);
        return shares;
    }

    function _simulateAccruedState() internal view returns (uint256 supply, uint256 totalAss) {
        // Effective supply = real + still-pending for this block.
        supply = totalSupply();
        totalAss = totalAssets();

        if (supply == 0) return (supply, totalAss);

        (uint256 mgmtShares, uint256 perfShares,) = _pendingFeeShares();
        supply += mgmtShares + perfShares;
    }

    /// @dev Converts a BV-level rate into a wrapper-level rate.
    ///      Uses convertToAssets which incorporates simulated pending wrapper fees
    ///      (via _simulateAccruedState), so the result reflects the post-accrual rate.
    ///      Units: [BV shares / wrapper share] * [base asset / BV share] / [BV share unit]
    ///           = [base asset / wrapper share]
    function _rateFromBoringVaultRate(uint256 bvRate) internal view returns (uint256) {
        uint256 wrapperShareUnit = 10 ** decimals();
        uint256 bvSharesPerWrapperShare = convertToAssets(wrapperShareUnit);
        return bvSharesPerWrapperShare.mulDiv(bvRate, 10 ** boringVault.decimals(), Math.Rounding.Floor);
    }

    // =========================================================================
    //                       INTERNAL - COMPLIANCE
    // =========================================================================

    /// @dev Convenience wrapper that resolves the teller from the live BV hook before
    ///      delegating to the four-argument overload. See that overload for full semantics.
    function _enforceTransferPolicy(address from, address to, address operator) internal view {
        _enforceTransferPolicy(_getTeller(), from, to, operator);
    }

    /// @dev Optimised single-party compliance check for depositAsset(), where
    ///      receiver == msg.sender is enforced so from == to == operator == caller.
    ///      Issues one beforeTransferData call instead of three, and one
    ///      doesUserHaveRole lookup instead of three — fully equivalent behaviour.
    function _enforceCallerPolicy(TellerWithMultiAssetSupport teller, address caller) private view {
        if (address(teller) == address(0)) return;
        (bool denyFrom, bool denyTo, bool denyOperator,) = teller.beforeTransferData(caller);
        if (denyFrom || denyTo || denyOperator) {
            revert BoringVaultWrapper__TransferDenied(caller, caller, caller);
        }
        uint8 role;
        try teller.transferAllowedRole() returns (uint8 r) {
            role = r;
        } catch {
            return;
        }
        if (role == type(uint8).max) return;
        RolesAuthority a = RolesAuthority(address(teller.authority()));
        if (!a.doesUserHaveRole(caller, role)) {
            revert BoringVaultWrapper__TransferNotAllowed();
        }
    }

    /// @dev Enforces the Teller's denylist and transferAllowedRole on a wrapper-share
    ///      movement. Called on every transfer, transferFrom, withdraw, redeem, and
    ///      redeemAsset.
    ///
    ///      DENYLIST: any of from/to/operator being flagged blocks the operation
    ///      unconditionally.
    ///
    ///      TRANSFER ALLOWLIST (transferAllowedRole):
    ///      The check uses OR semantics — the operation is allowed if AT LEAST ONE of
    ///      operator, from, or to holds the role. This has two non-obvious consequences
    ///      that vault operators must understand:
    ///
    ///      1. One-way door: a role-holder can send their own shares to an address that
    ///         does NOT hold the role (from satisfies the OR). The recipient then cannot
    ///         move those shares by themselves — every subsequent transfer/redeem/withdraw
    ///         they initiate has only their own address in all three slots, and the OR
    ///         collapses to a single doesUserHaveRole check they will fail. Their funds
    ///         are locked until point (2) below applies.
    ///
    ///      2. Operator escape hatch: a role-holder who holds ERC20 approval from the
    ///         stuck address can call transferFrom(stuck, dest, amount). The role-holder
    ///         as operator satisfies the OR, so the transfer succeeds. This is the only
    ///         recovery path for a stuck non-role holder — they must have granted approval
    ///         to a role-holder BEFORE becoming stuck.
    ///
    ///      depositAsset enforces the same role check at mint time (_enforceCallerPolicy)
    ///      to prevent addresses from self-depositing into the locked state directly.
    function _enforceTransferPolicy(TellerWithMultiAssetSupport teller, address from, address to, address operator)
        private
        view
    {
        // No hook wired → no teller policy to enforce. Allow the transfer.
        if (address(teller) == address(0)) return;

        (bool fromDenyFrom,,,) = teller.beforeTransferData(from);
        (, bool toDenyTo,,) = teller.beforeTransferData(to);
        (,, bool opDenyOperator,) = teller.beforeTransferData(operator);
        if (fromDenyFrom || toDenyTo || opDenyOperator) {
            revert BoringVaultWrapper__TransferDenied(from, to, operator);
        }

        if (to == address(0)) return;

        // Legacy tellers pre-date transferAllowedRole.  If the call reverts
        // (no matching selector, no fallback), treat as unrestricted (same as
        // type(uint8).max) and return without blocking the transfer.
        uint8 role;
        try teller.transferAllowedRole() returns (uint8 r) {
            role = r;
        } catch {
            return;
        }
        if (role == type(uint8).max) return;

        RolesAuthority a = RolesAuthority(address(teller.authority()));
        if (!a.doesUserHaveRole(operator, role) && !a.doesUserHaveRole(from, role) && !a.doesUserHaveRole(to, role)) {
            revert BoringVaultWrapper__TransferNotAllowed();
        }
    }

    // =========================================================================
    //                       INTERNAL - SHARE LOCK
    // =========================================================================

    /// @notice Lock `receiver`'s wrapper shares for a snapshot of the period the
    ///         underlying BoringVault actually enforces. Extends but never shortens
    ///         an existing lock.
    function _applyShareLock(address receiver) internal {
        uint64 period = _bvShareLockPeriod();
        if (period == 0) return;

        uint64 newUnlock = SafeCast.toUint64(block.timestamp + period);
        if (newUnlock > shareUnlockTime[receiver]) {
            shareUnlockTime[receiver] = newUnlock;
            emit ShareLockSet(receiver, newUnlock);
        }
    }

    /// @notice Returns the BoringVault's live beforeTransfer hook cast as a Teller
    ///         interface. Callers tolerate zero / legacy hooks where needed.
    /// @dev Assumes boringVault.hook() is always set and Teller-shaped (implements
    ///      beforeTransferData, called unguarded throughout). Only the newer,
    ///      optional Teller functions are try/catch-guarded for legacy tellers.
    function _getTeller() private view returns (TellerWithMultiAssetSupport) {
        return TellerWithMultiAssetSupport(address(boringVault.hook()));
    }

    /// @notice The share-lock period actually enforced by the underlying BoringVault,
    ///         read from its live beforeTransfer hook. Returns 0 when no hook is wired
    ///         or the hook does not expose shareLockPeriod() (legacy / non-teller hooks).
    function _bvShareLockPeriod() internal view returns (uint64) {
        TellerWithMultiAssetSupport t = _getTeller();
        if (address(t) == address(0)) return 0;
        try t.shareLockPeriod() returns (uint64 p) {
            return p;
        } catch {
            return 0;
        }
    }

    /// @notice Revert if the caller is not the underlying BoringVault's owner.
    ///
    /// @dev Queue governance belongs to the BV operator. Only the BV owner may call
    ///      functions guarded by this check — no authority canCall or selector
    ///      registration is required.
    function _requiresBVAuth() internal view {
        if (msg.sender == boringVault.owner()) return;
        revert BoringVaultWrapper__NotBVAuthorized();
    }

    /// @notice Revert if `holder`'s wrapper shares are still within their lock window.
    function _enforceShareLock(address holder) internal view {
        if (shareUnlockTime[holder] > block.timestamp) revert BoringVaultWrapper__SharesLocked(holder);
    }

    function _verifyComplianceSignature(
        TellerWithMultiAssetSupport teller,
        address user,
        address receiver,
        address asset,
        uint256 amount,
        ComplianceData calldata compliance
    ) private {
        // Legacy tellers pre-date complianceSignerRole.  If the external call
        // reverts (function selector absent, no fallback), treat the teller as
        // having compliance disabled and skip the check entirely.
        uint8 role;
        try teller.complianceSignerRole() returns (uint8 r) {
            role = r;
        } catch {
            return;
        }
        if (role == type(uint8).max) return;

        bytes32 messageHash =
            keccak256(abi.encode(address(this), block.chainid, user, receiver, asset, amount, compliance.deadline));

        TellerWithMultiAssetSupportLib.verifyAndMark(
            usedComplianceSignatures,
            address(teller.authority()),
            role,
            teller.complianceWindow(),
            messageHash,
            compliance.deadline,
            compliance.signature
        );
    }
}
