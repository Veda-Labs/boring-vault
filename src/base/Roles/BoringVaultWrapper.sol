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
import {Auth, Authority} from "@solmate/auth/Auth.sol";
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
 * @dev Fees-on-fees: BV-level and wrapper-level fees are additive. End users
 *      pay both layers.
 *
 * @dev White-labeling: deploy one instance per partner with independent
 *      name / symbol / feeRecipient / fee rates over the same BoringVault.
 */
contract BoringVaultWrapper is ERC4626, Auth, ReentrancyGuard {
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

    TellerWithMultiAssetSupport public teller;

    /// @notice Optional withdrawal queue associated with the BoringVault. When set
    ///         (non-zero), the privileged synchronous redeemAsset() path is disabled
    ///         so wrapper users cannot jump the queue via bulkWithdraw.
    address public queue;

    address public feeRecipient;

    /// @notice Annual management fee in basis points (e.g. 200 = 2%).
    uint16 public managementFee;

    /// @notice Performance fee in basis points (e.g. 1_000 = 10%).
    uint16 public performanceFee;

    /// @notice Block timestamp of the last fee accrual.
    uint64 public lastFeeAccrual;

    /// @notice BV exchange rate above which the performance fee fires, in the
    ///         same unit as accountant.getRate().
    uint96 public performanceHighWaterMark;

    /// @notice Fee shares accrued but not minted, held as a dilution debt until
    ///         admin calls withdrawFees(to). Populated when feeRecipient is
    ///         unset or currently has denyTo on the Teller. Counted as supply
    ///         by the fee/preview math so user-facing conversions stay
    ///         consistent with the eventual mint.
    uint256 public pendingEscrowedFeeShares;

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
    error BoringVaultWrapper__BadTeller();
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
    /// @dev deposit/mint/depositAsset with receiver != caller. The share lock is a
    ///      per-holder window keyed on the receiver; allowing a third party to mint
    ///      to an arbitrary receiver would let anyone refresh that receiver's lock
    ///      (grief). Requiring receiver == caller makes the lock self-imposed only.
    error BoringVaultWrapper__ReceiverMustBeCaller();

    // =========================================================================
    //                               EVENTS
    // =========================================================================

    event FeesAccrued(uint256 managementFeeShares, uint256 performanceFeeShares);
    event FeeConfigSet(
        address indexed oldRecipient,
        address indexed newRecipient,
        uint16 oldManagementFee,
        uint16 newManagementFee,
        uint16 oldPerformanceFee,
        uint16 newPerformanceFee
    );
    event TellerSet(address oldTeller, address newTeller);
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

    /// @notice Emitted when fees are recorded as a dilution debt instead of minted.
    event FeesEscrowed(uint256 managementFeeShares, uint256 performanceFeeShares);

    /// @notice Emitted when admin mints accumulated escrowed fees to `to`.
    event FeesWithdrawn(address indexed to, uint256 shares);

    // =========================================================================
    //                             CONSTRUCTOR
    // =========================================================================

    constructor(
        address _owner,
        address _boringVault,
        address _accountant,
        address _teller,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_boringVault)) ERC20(_name, _symbol) Auth(_owner, Authority(address(0))) {
        if (address(TellerWithMultiAssetSupport(_teller).vault()) != address(_boringVault)) {
            revert BoringVaultWrapper__BadTeller();
        }
        if (address(AccountantWithRateProviders(_accountant).vault()) != address(_boringVault)) {
            revert BoringVaultWrapper__BadAccountant();
        }

        boringVault = BoringVault(payable(_boringVault));
        accountant = AccountantWithRateProviders(_accountant);
        teller = TellerWithMultiAssetSupport(_teller);
        emit TellerSet(address(0), _teller);

        // Seed HWM at the current gross rate.
        performanceHighWaterMark = SafeCast.toUint96(AccountantWithRateProviders(_accountant).getRateSafe());
    }

    // =========================================================================
    //                              ADMIN
    // =========================================================================

    function setFeeConfig(address _feeRecipient, uint16 _managementFee, uint16 _performanceFee) external requiresAuth {
        if (_feeRecipient == address(0)) revert BoringVaultWrapper__ZeroAddress();
        if (_managementFee > MAX_MANAGEMENT_FEE) revert BoringVaultWrapper__FeeTooHigh();
        if (_performanceFee > MAX_PERFORMANCE_FEE) revert BoringVaultWrapper__FeeTooHigh();
        _accrueFees();
        emit FeeConfigSet(feeRecipient, _feeRecipient, managementFee, _managementFee, performanceFee, _performanceFee);
        feeRecipient = _feeRecipient;
        managementFee = _managementFee;
        performanceFee = _performanceFee;
    }

    function setTeller(address newTeller) external requiresAuth {
        if (address(TellerWithMultiAssetSupport(newTeller).vault()) != address(boringVault)) {
            revert BoringVaultWrapper__BadTeller();
        }
        emit TellerSet(address(teller), newTeller);
        teller = TellerWithMultiAssetSupport(newTeller);
    }

    /// @notice Associate (or clear) a withdrawal queue. While a non-zero queue is
    ///         set, redeemAsset() reverts so wrapper users cannot bypass the queue
    ///         via the privileged synchronous bulkWithdraw path. Pass address(0) to
    ///         re-enable redeemAsset (only for vaults that have no queue).
    function setQueue(address newQueue) external requiresAuth {
        if (newQueue != address(0) && IBoringQueueVault(newQueue).boringVault() != address(boringVault)) {
            revert BoringVaultWrapper__BadQueue();
        }
        emit QueueSet(queue, newQueue);
        queue = newQueue;
    }

    function accrueFees() external {
        _accrueFees();
    }

    /**
     * @notice Reset the performance-fee HWM to the current BV rate. Intended
     *         for drawdown recovery: while the rate is below the HWM, perf
     *         fees are frozen until this is called. Settles outstanding fees
     *         at the old HWM first. Reverts if the accountant is paused.
     */
    function resetHighWaterMark() external requiresAuth {
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

    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        if (receiver != _msgSender()) revert BoringVaultWrapper__ReceiverMustBeCaller();
        _enforceTransferPolicy(_msgSender(), receiver, _msgSender());
        _accrueFees();
        uint256 shares = super.deposit(assets, receiver);
        _applyShareLock(receiver);
        return shares;
    }

    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256) {
        if (receiver != _msgSender()) revert BoringVaultWrapper__ReceiverMustBeCaller();
        _enforceTransferPolicy(_msgSender(), receiver, _msgSender());
        _accrueFees();
        uint256 assets = super.mint(shares, receiver);
        _applyShareLock(receiver);
        return assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant returns (uint256) {
        _enforceTransferPolicy(owner, receiver, _msgSender());
        _enforceShareLock(owner);
        _accrueFees();
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public override nonReentrant returns (uint256) {
        _enforceTransferPolicy(owner, receiver, _msgSender());
        _enforceShareLock(owner);
        _accrueFees();
        return super.redeem(shares, receiver, owner);
    }

    // =========================================================================
    //                ERC4626 - share/asset conversion overrides
    // =========================================================================
    // Use simulated post-accrual state so off-chain previews match on-chain
    // execution even when _accrueFees() has not run recently.

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return assets.mulDiv(supply + 10 ** _decimalsOffset(), totalAss + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return shares.mulDiv(totalAss + 1, supply + 10 ** _decimalsOffset(), rounding);
    }

    // =========================================================================
    //                  ERC20 - wrapper share transfer hooks
    // =========================================================================

    function transfer(address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _enforceTransferPolicy(_msgSender(), to, _msgSender());
        _enforceShareLock(_msgSender());
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _enforceTransferPolicy(from, to, _msgSender());
        _enforceShareLock(from);
        return super.transferFrom(from, to, amount);
    }

    // =========================================================================
    //                       DIRECT ASSET DEPOSIT
    // =========================================================================

    /// @notice Deposit a raw asset and receive wrapper shares in one tx.
    ///         wrapperShares = bvReceived * (supplyBefore + 10^offset) / (bvBefore + 1).
    function depositAsset(
        SolmateERC20 rawAsset,
        uint256 rawAmount,
        uint256 minBVShares,
        address receiver,
        ComplianceData calldata compliance
    ) external nonReentrant returns (uint256 wrapperShares) {
        if (receiver != _msgSender()) revert BoringVaultWrapper__ReceiverMustBeCaller();

        TellerWithMultiAssetSupport _teller = teller;

        _enforceTransferPolicy(_msgSender(), receiver, _msgSender());
        _verifyComplianceSignature(_msgSender(), receiver, address(rawAsset), rawAmount, compliance);

        _accrueFees();

        uint256 bvBefore = boringVault.balanceOf(address(this));
        uint256 supplyBefore = totalSupply() + pendingEscrowedFeeShares;

        IERC20 asset_ = IERC20(address(rawAsset));
        asset_.safeTransferFrom(_msgSender(), address(this), rawAmount);
        asset_.forceApprove(address(boringVault), rawAmount);

        _teller.bulkDeposit(rawAsset, rawAmount, minBVShares, address(this));

        uint256 bvReceived = boringVault.balanceOf(address(this)) - bvBefore;
        if (bvReceived == 0) revert BoringVaultWrapper__ZeroBVSharesReceived();

        wrapperShares = bvReceived.mulDiv(supplyBefore + 10 ** _decimalsOffset(), bvBefore + 1, Math.Rounding.Floor);

        if (wrapperShares == 0) revert BoringVaultWrapper__ZeroBVSharesReceived();

        _mint(receiver, wrapperShares);
        _applyShareLock(receiver);

        emit Deposit(_msgSender(), receiver, bvReceived, wrapperShares);
        emit AssetDeposit(_msgSender(), receiver, address(rawAsset), rawAmount, bvReceived, wrapperShares);
    }

    // =========================================================================
    //                       DIRECT ASSET REDEEM
    // =========================================================================

    function redeemAsset(
        SolmateERC20 asset,
        uint256 wrapperShares,
        uint256 minAssetOut,
        address receiver,
        address owner
    ) external nonReentrant returns (uint256 assetOut) {
        if (queue != address(0)) revert BoringVaultWrapper__RedeemAssetDisabledWithQueue();

        TellerWithMultiAssetSupport _teller = teller;

        _enforceTransferPolicy(owner, receiver, _msgSender());
        _enforceShareLock(owner);

        _accrueFees();

        if (_msgSender() != owner) {
            _spendAllowance(owner, _msgSender(), wrapperShares);
        }

        uint256 supply = totalSupply() + pendingEscrowedFeeShares;
        uint256 totalBV = boringVault.balanceOf(address(this));

        uint256 bvToRedeem = wrapperShares.mulDiv(totalBV + 1, supply + 10 ** _decimalsOffset(), Math.Rounding.Floor);

        _burn(owner, wrapperShares);

        assetOut = _teller.bulkWithdraw(asset, bvToRedeem, minAssetOut, receiver);

        emit Withdraw(_msgSender(), receiver, owner, bvToRedeem, wrapperShares);
        emit AssetRedeem(_msgSender(), receiver, address(asset), owner, wrapperShares, bvToRedeem, assetOut);
    }

    // =========================================================================
    //                         INTERNAL - FEE ENGINE
    // =========================================================================

    function _pendingFeeShares() internal view returns (uint256 mgmtShares, uint256 perfShares, uint96 newHWM) {
        // Effective supply includes escrowed fee shares so they share dilution
        // with real holders.
        uint256 supply = totalSupply() + pendingEscrowedFeeShares;
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

    function _accrueFees() internal {
        uint64 now_ = uint64(block.timestamp);

        if (totalSupply() + pendingEscrowedFeeShares == 0) {
            lastFeeAccrual = now_;
            return;
        }

        (uint256 mgmtShares, uint256 perfShares, uint96 newHWM) = _pendingFeeShares();

        if (newHWM != 0) {
            emit HighWaterMarkUpdated(performanceHighWaterMark, newHWM);
            performanceHighWaterMark = newHWM;
        }

        lastFeeAccrual = now_;

        uint256 total = mgmtShares + perfShares;
        if (total == 0) return;

        address recipient = feeRecipient;

        // No recipient set, or recipient currently denyTo: accrue into escrow as
        // a dilution debt; admin sweeps via withdrawFees(to). Escrowed shares are
        // still counted in user-facing share math.
        if (recipient == address(0) || _isFeeRecipientBlocked(recipient)) {
            pendingEscrowedFeeShares += total;
            emit FeesEscrowed(mgmtShares, perfShares);
        } else {
            _mint(recipient, total);
            emit FeesAccrued(mgmtShares, perfShares);
        }
    }

    /// @notice Mint accumulated escrowed fee shares to `to` and reset the counter.
    ///         Refuses denyTo destinations so admin cannot route fees around the
    ///         compliance policy.
    function withdrawFees(address to) external requiresAuth {
        if (to == address(0)) revert BoringVaultWrapper__ZeroAddress();

        (, bool toDenyTo,,) = teller.beforeTransferData(to);
        if (toDenyTo) revert BoringVaultWrapper__TransferDenied(address(this), to, _msgSender());

        _accrueFees();

        uint256 shares = pendingEscrowedFeeShares;
        if (shares == 0) return;

        // Effective supply is unchanged: real +shares, escrowed -shares.
        pendingEscrowedFeeShares = 0;
        _mint(to, shares);
        emit FeesWithdrawn(to, shares);
    }

    function _isFeeRecipientBlocked(address recipient) internal view returns (bool) {
        (, bool denyTo,,) = teller.beforeTransferData(recipient);
        return denyTo;
    }

    function _simulateAccruedState() internal view returns (uint256 supply, uint256 totalAss) {
        // Effective supply = real + escrowed + still-pending for this block.
        supply = totalSupply() + pendingEscrowedFeeShares;
        totalAss = totalAssets();

        if (supply == 0) return (supply, totalAss);

        (uint256 mgmtShares, uint256 perfShares,) = _pendingFeeShares();
        supply += mgmtShares + perfShares;
    }

    // =========================================================================
    //                       INTERNAL - COMPLIANCE
    // =========================================================================

    function _enforceTransferPolicy(address from, address to, address operator) internal view {
        TellerWithMultiAssetSupport _teller = teller;

        (bool fromDenyFrom,,,) = _teller.beforeTransferData(from);
        (, bool toDenyTo,,) = _teller.beforeTransferData(to);
        (,, bool opDenyOperator,) = _teller.beforeTransferData(operator);
        if (fromDenyFrom || toDenyTo || opDenyOperator) {
            revert BoringVaultWrapper__TransferDenied(from, to, operator);
        }

        if (to == address(0)) return;

        // Legacy tellers pre-date transferAllowedRole.  If the call reverts
        // (no matching selector, no fallback), treat as unrestricted (same as
        // type(uint8).max) and return without blocking the transfer.
        uint8 role;
        try _teller.transferAllowedRole() returns (uint8 r) {
            role = r;
        } catch {
            return;
        }
        if (role == type(uint8).max) return;

        RolesAuthority a = RolesAuthority(address(_teller.authority()));
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

    /// @notice The share-lock period actually enforced by the underlying BoringVault,
    ///         read from its live beforeTransfer hook. Binding the wrapper's lock to
    ///         the BV's authoritative enforcer means the two can never be configured
    ///         to different periods, regardless of the wrapper's `teller` reference.
    ///         Returns 0 when no hook is wired or the hook does not expose
    ///         shareLockPeriod() (legacy / non-teller hooks) — i.e. exactly when the
    ///         BV itself enforces no lock.
    function _bvShareLockPeriod() internal view returns (uint64) {
        address bvHook = address(boringVault.hook());
        if (bvHook == address(0)) return 0;
        try TellerWithMultiAssetSupport(bvHook).shareLockPeriod() returns (uint64 p) {
            return p;
        } catch {
            return 0;
        }
    }

    /// @notice Revert if `holder`'s wrapper shares are still within their lock window.
    function _enforceShareLock(address holder) internal view {
        if (shareUnlockTime[holder] > block.timestamp) revert BoringVaultWrapper__SharesLocked(holder);
    }

    function _verifyComplianceSignature(
        address user,
        address receiver,
        address asset,
        uint256 amount,
        ComplianceData calldata compliance
    ) internal {
        TellerWithMultiAssetSupport _teller = teller;

        // Legacy tellers pre-date complianceSignerRole.  If the external call
        // reverts (function selector absent, no fallback), treat the teller as
        // having compliance disabled and skip the check entirely.
        uint8 role;
        try _teller.complianceSignerRole() returns (uint8 r) {
            role = r;
        } catch {
            return;
        }
        if (role == type(uint8).max) return;

        bytes32 messageHash =
            keccak256(abi.encode(address(this), block.chainid, user, receiver, asset, amount, compliance.deadline));

        TellerWithMultiAssetSupportLib.verifyAndMark(
            usedComplianceSignatures,
            address(_teller.authority()),
            role,
            _teller.complianceWindow(),
            messageHash,
            compliance.deadline,
            compliance.signature
        );
    }
}
