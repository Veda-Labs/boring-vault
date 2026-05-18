// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
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

/**
 * @title  BoringVaultWrapper
 * @dev Asset model:
 *   asset() = BoringVault shares (IERC20)
 *
 *   No off-chain share-price updater is needed. The wrapper's exchange rate
 *   against BoringVault shares drifts only as fee dilution accumulates over time.
 *
 * @dev Inflation-attack protection:
 *   This contract inherits from OpenZeppelin's ERC4626 and overrides
 *   _decimalsOffset() = DECIMALS_OFFSET. That makes the share conversion
 *   formula `assets * (supply + 10^offset) / (totalAssets + 1)`, which makes
 *   the classic donation-style inflation attack always strictly unprofitable
 *   for the attacker — they can never recover more than they put in. The
 *   wrapper-share decimals become `boringVault.decimals() + DECIMALS_OFFSET`.
 *
 * @dev Fee model:
 *   Fees are realized as wrapper share dilution — the feeRecipient receives
 *   freshly minted shares and no underlying assets are ever extracted.
 *
 *   1. Management fee  — annualized % of AUM, accrued continuously.
 *   2. Performance fee — % of appreciation in the BoringVault exchange rate
 *                        (accountant.getRate()) above the high-water mark.
 *
 *   Both are settled before every user action so the exchange rate is always
 *   up-to-date when deposits/withdrawals are priced.
 *
 * @dev Direct asset deposit:
 *   depositAsset() accepts any Teller-supported ERC20 (e.g. USDC, WETH, etc.)
 *   using bulkDeposit so that BoringVault shares land in this contract in a single transaction
 *   and wrapper shares are issued to the caller.
 *
 *   Requirements:
 *   - The asset must be enabled for deposits on the Teller.
 *   - This contract must hold the bulkDeposit role on the Teller.
 *
 *   Share-lock: bulkDeposit skips _afterPublicDeposit so no lock is ever set
 *   on this contract's BoringVault shares, so any Teller shareLockPeriod is fully
 *   transparent to wrapper users.
 *
 * @dev Compliance:
 *   The wrapper enforces the Teller's compliance policy on its own entrypoints
 *   so that the real user identity (msg.sender / owner / receiver) — not the
 *   wrapper address — is what gets checked. Policy state is read live from the
 *   Teller (no duplication of config):
 *
 *     - Denylist: teller.beforeTransferData(user)
 *     - Transfer allowlist: teller.transferAllowedRole() resolved via teller.authority()
 *     - Compliance signature signer: teller.complianceSignerRole() + teller.complianceWindow()
 *
 *   Where applied:
 *     - depositAsset()        : denylist + allowlist + signature (wrapper-domain hash)
 *     - redeemAsset()         : denylist + allowlist
 *     - deposit/mint          : denylist + allowlist (BoringVault hook also fires on the BoringVault transfer in)
 *     - withdraw/redeem       : denylist + allowlist on owner/receiver (BoringVault hook also fires on the BoringVault transfer out)
 *     - wrapper share transfer: denylist + allowlist on every transfer / transferFrom
 *
 *   Signatures are wrapper-scoped: the hash includes address(this), not the Teller's
 *   address, so a Teller-issued signature cannot be replayed against the wrapper and
 *   vice versa. Replay protection is a wrapper-local mapping.
 *
 *   Note: the BoringVault share lock period is intentionally NOT enforced on wrapper-share
 *   transfers (it is a BoringVault-level deposit-refund window with no analog at the wrapper
 *   layer).
 *
 * @dev Fees-on-fees:
 *   The underlying BoringVault Accountant may already accrue platform / performance
 *   fees via exchange-rate updates. This wrapper's fees are additive — end
 *   users effectively pay both layers.
 *
 *   White-labeling: deploy one instance per partner with independent
 *   name / symbol / feeRecipient / fee rates, all backed by the same BoringVault.
 */
contract BoringVaultWrapper is ERC4626, Auth, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // =========================================================================
    //                              CONSTANTS
    // =========================================================================

    /// @notice Hard cap on the annual management fee: 5 % (500 bps).
    uint16 public constant MAX_MANAGEMENT_FEE = 500;

    /// @notice Hard cap on the performance fee: 50 % (5_000 bps).
    uint16 public constant MAX_PERFORMANCE_FEE = 5_000;

    /// @notice Minimum drawdown required before resetHighWaterMark() is permitted.
    ///         The current net rate must be at least this many basis points below
    ///         the HWM: rate ≤ hwm × (1 − MIN_HWM_RESET_DRAWDOWN_BPS / 10 000).
    ///         10 % (1 000 bps) prevents gaming small or transient dips.
    uint16 public constant MIN_HWM_RESET_DRAWDOWN_BPS = 1_000;

    /// @notice Virtual-share offset used for inflation-attack mitigation.
    ///         Wrapper decimals() = BoringVault decimals() + DECIMALS_OFFSET.
    uint8 public constant DECIMALS_OFFSET = 6;

    // =========================================================================
    //                              IMMUTABLES
    // =========================================================================

    /// @notice The BoringVault whose shares are held as this wrapper's underlying asset.
    BoringVault public immutable boringVault;

    /**
     * @notice Accountant that exposes the live BoringVault share price via getRate().
     * @dev    Used exclusively for tracking the performance-fee high-water mark.
     *         The wrapper does NOT need the accountant to be updated to function;
     *         management fees work independently of it.
     */
    AccountantWithRateProviders public immutable accountant;

    /// @notice 10**boringVault.decimals(), cached for the BV-fee netting math.
    /// @dev    The accountant's exchange rate is expressed in base-asset units per
    ///         `BV_ONE_SHARE` shares, so converting `feesOwedInBase` (in base) to a
    ///         per-share quantity in rate units requires multiplying by this constant.
    uint256 public immutable BV_ONE_SHARE;

    // =========================================================================
    //                               STATE
    // =========================================================================

    TellerWithMultiAssetSupport public teller;

    address public feeRecipient;

    /// @notice Annual management fee in basis points (e.g. 200 = 2 %).
    uint16 public managementFee;

    /// @notice Performance fee on BoringVault exchange-rate gains in bps (e.g. 1_000 = 10 %).
    uint16 public performanceFee;

    /// @notice Block timestamp of the last fee accrual.
    uint64 public lastFeeAccrual;

    /**
     * @notice BoringVault exchange rate recorded at the last fee accrual.
     * @dev    Performance fees are only charged on appreciation above this value.
     *         Stored as the same unit returned by accountant.getRate().
     */
    uint96 public performanceHighWaterMark;

    /**
     * @notice Fee shares accrued but not yet minted — held as a debt against the wrapper
     *         until admin calls `withdrawFees(to)`. Populated when `feeRecipient` is unset
     *         or when it currently has denyTo set on the Teller. Counted as supply by
     *         `_simulateAccruedState` and `_pendingFeeShares` so user-facing share math
     *         remains consistent with the eventual mint.
     */
    uint256 public pendingEscrowedFeeShares;

    /**
     * @notice Replay protection for wrapper-domain compliance signatures.
     * @dev    Wrapper-scoped: the message hash includes address(this), so a Teller
     *         signature cannot be replayed here and vice versa.
     */
    mapping(bytes32 messageHash => bool used) public usedComplianceSignatures;

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
    /// @dev Reverted by resetHighWaterMark() when the current rate is at or above
    ///      the HWM — normal accrual already handles that case.
    error BoringVaultWrapper__HWMResetNotNeeded();
    /// @dev Reverted by resetHighWaterMark() when the drawdown is too shallow
    ///      (rate is within MIN_HWM_RESET_DRAWDOWN_BPS of the HWM).
    error BoringVaultWrapper__DrawdownTooSmall();

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
    event HighWaterMarkUpdated(uint96 oldHighWaterMark, uint96 newHighWaterMark);

    /// @notice Emitted by depositAsset() to record the raw-asset entry path.
    /// @dev    Standard ERC4626 `Deposit` is also emitted, with `assets = bvReceived`
    ///         (asset() is BV shares). This event captures the user-facing rawAsset/rawAmount
    ///         that the ERC4626 event hides.
    event AssetDeposit(
        address indexed caller,
        address indexed receiver,
        address indexed rawAsset,
        uint256 rawAmount,
        uint256 bvReceived,
        uint256 wrapperShares
    );

    /// @notice Emitted by redeemAsset() to record the raw-asset exit path.
    /// @dev    Standard ERC4626 `Withdraw` is also emitted, with `assets = bvToRedeem`.
    event AssetRedeem(
        address indexed caller,
        address indexed receiver,
        address indexed rawAsset,
        address owner,
        uint256 wrapperShares,
        uint256 bvRedeemed,
        uint256 assetOut
    );

    /// @notice Emitted when fees are recorded as a dilution debt in
    ///         `pendingEscrowedFeeShares` instead of being minted to feeRecipient —
    ///         either because feeRecipient is unset (zero) or because it currently
    ///         cannot receive shares (denyTo). Admin claims the debt via
    ///         withdrawFees(to), which mints the accumulated shares to `to`.
    event FeesEscrowed(uint256 managementFeeShares, uint256 performanceFeeShares);

    /// @notice Emitted when admin mints accumulated escrowed fee shares to a recipient.
    event FeesWithdrawn(address indexed to, uint256 shares);

    // =========================================================================
    //                             CONSTRUCTOR
    // =========================================================================

    /**
     * @param _owner       Initial admin of this wrapper instance.
     * @param _boringVault BoringVault to wrap; its shares become asset().
     * @param _accountant  Provides the BoringVault share price for the performance-fee high-water mark.
     * @param _teller      Teller used by depositAsset() / redeemAsset(); must reference
     *                     the same BoringVault.
     * @param _name        ERC20 name of the wrapper shares.
     * @param _symbol      ERC20 symbol of the wrapper shares.
     */
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
        BV_ONE_SHARE = 10 ** BoringVault(payable(_boringVault)).decimals();
        emit TellerSet(address(0), _teller);

        uint256 initialGross = AccountantWithRateProviders(_accountant).getRateSafe();
        performanceHighWaterMark = SafeCast.toUint96(_applyBvFees(initialGross));
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

    function accrueFees() external {
        _accrueFees();
    }

    /**
     * @notice Reset the performance-fee high-water mark to the current net BoringVault
     *         rate. Intended for drawdown recovery: if the BV rate has fallen below the
     *         HWM, performance fees are permanently frozen until this is called.
     * @dev    Settles any outstanding fees at the old HWM first so no gains are
     *         silently skipped. When the current rate already equals the HWM (normal
     *         post-accrual state) this is a no-op. Reverts if the accountant is paused
     *         because the current rate cannot be determined.
     */
    function resetHighWaterMark() external requiresAuth {
        uint96 hwm = performanceHighWaterMark;
        uint96 newHWM_ = SafeCast.toUint96(_applyBvFees(accountant.getRateSafe()));

        // Rate at or above the HWM: the normal _accrueFees() path already advances
        // the HWM in this regime. Raising it further here would silently skip
        // performance-fee collection on already-realised gains.
        if (newHWM_ >= hwm) revert BoringVaultWrapper__HWMResetNotNeeded();

        // Require a minimum drawdown before allowing a reset. Without this an admin
        // could call during a minor, transient dip and then collect performance fees
        // on the near-term recovery — gains users expected to receive fee-free.
        // rate must be ≤ hwm × (1 − MIN_HWM_RESET_DRAWDOWN_BPS / 10 000).
        if (uint256(newHWM_) > uint256(hwm) * (1e4 - MIN_HWM_RESET_DRAWDOWN_BPS) / 1e4) {
            revert BoringVaultWrapper__DrawdownTooSmall();
        }

        // Settle any outstanding fees at the old HWM before lowering it.
        // rate < HWM here, so _accrueFees() will not advance the HWM.
        _accrueFees();

        emit HighWaterMarkUpdated(hwm, newHWM_);
        performanceHighWaterMark = newHWM_;
    }

    // =========================================================================
    //                         ERC4626 — totalAssets
    // =========================================================================

    function totalAssets() public view override returns (uint256) {
        return boringVault.balanceOf(address(this));
    }

    // =========================================================================
    //                       ERC4626 — virtual offset
    // =========================================================================

    function _decimalsOffset() internal pure override returns (uint8) {
        return DECIMALS_OFFSET;
    }

    // =========================================================================
    //                    ERC4626 — public entrypoints
    // =========================================================================
    //
    //  Each entrypoint:
    //    1. Enforces the Teller's denylist + transfer allowlist on the real
    //       user identity (operator/owner/receiver).
    //    2. Settles pending fees so the conversion ratio is current.
    //    3. Delegates to OZ's super, which uses _convertToShares/_convertToAssets
    //       (overridden below) to apply pending-fee simulation + virtual offset.
    //
    // =========================================================================

    function deposit(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        _enforceTransferPolicy(_msgSender(), receiver, _msgSender());
        _accrueFees();
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override nonReentrant returns (uint256) {
        _enforceTransferPolicy(_msgSender(), receiver, _msgSender());
        _accrueFees();
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant returns (uint256) {
        _enforceTransferPolicy(owner, receiver, _msgSender());
        _accrueFees();
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner) public override nonReentrant returns (uint256) {
        _enforceTransferPolicy(owner, receiver, _msgSender());
        _accrueFees();
        return super.redeem(shares, receiver, owner);
    }

    // =========================================================================
    //                ERC4626 — share/asset conversion overrides
    // =========================================================================
    //
    //  OZ's ERC4626 routes every preview/convert through these two internals.
    //  We replace `totalSupply()` and `totalAssets()` with their simulated
    //  post-fee-accrual values so off-chain quotes match on-chain execution
    //  even when _accrueFees() has not run recently.
    //
    // =========================================================================

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return assets.mulDiv(supply + 10 ** _decimalsOffset(), totalAss + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return shares.mulDiv(totalAss + 1, supply + 10 ** _decimalsOffset(), rounding);
    }

    // =========================================================================
    //                  ERC20 — wrapper share transfer hooks
    // =========================================================================

    function transfer(address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _enforceTransferPolicy(_msgSender(), to, _msgSender());
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _enforceTransferPolicy(from, to, _msgSender());
        return super.transferFrom(from, to, amount);
    }

    // =========================================================================
    //                       DIRECT ASSET DEPOSIT
    // =========================================================================

    /**
     * @notice Deposit a raw asset (e.g. USDC) and receive wrapper shares in one transaction.
     * @dev    Same virtual-offset share math as the standard ERC4626 path:
     *         wrapperShares = bvReceived * (supplyBefore + 10^offset) / (bvBefore + 1)
     *         which is identical to convertToShares(bvReceived) evaluated against
     *         the state snapshot taken before the BoringVault mint.
     */
    function depositAsset(
        SolmateERC20 rawAsset,
        uint256 rawAmount,
        uint256 minBVShares,
        address receiver,
        ComplianceData calldata compliance
    ) external nonReentrant returns (uint256 wrapperShares) {
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
        TellerWithMultiAssetSupport _teller = teller;

        _enforceTransferPolicy(owner, receiver, _msgSender());

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
    //                         INTERNAL — FEE ENGINE
    // =========================================================================

    function _pendingFeeShares() internal view returns (uint256 mgmtShares, uint256 perfShares, uint96 newHWM) {
        // Effective supply = real ERC20 supply + fees owed but not yet minted (escrowed).
        // Escrowed shares share dilution with real holders, so they must be included in the
        // base for mgmt/perf fee math; otherwise the rate-of-accrual would drift after the
        // first escrowed accrual.
        uint256 supply = totalSupply() + pendingEscrowedFeeShares;
        if (supply == 0) return (0, 0, 0);

        uint16 mgmtFee = managementFee;
        uint256 elapsed = block.timestamp - lastFeeAccrual;

        if (mgmtFee > 0 && elapsed > 0) {
            mgmtShares = supply.mulDiv(uint256(mgmtFee) * elapsed, uint256(1e4) * 365 days, Math.Rounding.Floor);
        }

        // Always read the rate so the HWM advances even when performanceFee = 0.
        // If we skipped this when perfFee == 0, a stale HWM would silently expose
        // all appreciation that occurred during the zero-fee window to a retroactive
        // performance fee the moment the fee is re-enabled.
        try accountant.getRateSafe() returns (uint256 currentRate) {
            // Use the *net* rate (after subtracting BV-level pending fees) so the
            // wrapper does not charge perf fee on appreciation the BV layer will claw
            // back via claimFees(). See _applyBvFees for the exact accounting.
            uint256 currentNetRate = _applyBvFees(currentRate);
            uint96 hwm = performanceHighWaterMark;

            if (currentNetRate > uint256(hwm)) {
                newHWM = SafeCast.toUint96(currentNetRate);

                uint16 perfFee = performanceFee;
                if (perfFee > 0) {
                    uint256 totalBV = totalAssets();

                    uint256 gainBV = totalBV.mulDiv(currentNetRate - uint256(hwm), currentNetRate, Math.Rounding.Floor);
                    uint256 feeBV = gainBV.mulDiv(perfFee, 1e4, Math.Rounding.Floor);

                    if (feeBV > 0 && totalBV > 0) {
                        perfShares = feeBV.mulDiv(supply + mgmtShares, totalBV, Math.Rounding.Floor);
                    }
                }
            }
        } catch {
            // Accountant paused or otherwise unavailable: skip both performance-fee
            // accrual and HWM tracking. Management fee already computed above is unaffected.
        }
    }

    /// @notice Net BoringVault rate: gross `accountant.getRateSafe()` minus pending
    ///         BV-level platform/performance fees expressed as base per BV share.
    /// @dev    Reverts if the accountant is paused (mirrors getRateSafe semantics).
    function netRate() external view returns (uint256) {
        return _applyBvFees(accountant.getRateSafe());
    }

    /// @dev Subtracts pending BV-level fees from a gross rate.
    ///      feesOwedInBase × BV_ONE_SHARE / bvSupply yields the per-share fee deduction
    ///      in the same units as the gross rate. Floors at zero if fees exceed gross.
    function _applyBvFees(uint256 grossRate) internal view returns (uint256) {
        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();
        if (feesOwed == 0) return grossRate;
        uint256 bvSupply = boringVault.totalSupply();
        if (bvSupply == 0) return grossRate;
        uint256 feesPerShare = uint256(feesOwed).mulDiv(BV_ONE_SHARE, bvSupply);
        unchecked {
            return grossRate > feesPerShare ? grossRate - feesPerShare : 0;
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

        // When no recipient is configured, or when the configured recipient cannot
        // currently receive shares (denyTo), accrue into pendingEscrowedFeeShares as a
        // dilution debt — no actual mint. Admin sweeps via withdrawFees(to). The shares
        // are still counted in _pendingFeeShares / _simulateAccruedState so user-facing
        // conversions reflect the dilution exactly as if the shares had been minted.
        if (recipient == address(0) || _isFeeRecipientBlocked(recipient)) {
            pendingEscrowedFeeShares += total;
            emit FeesEscrowed(mgmtShares, perfShares);
        } else {
            _mint(recipient, total);
            emit FeesAccrued(mgmtShares, perfShares);
        }
    }

    /// @notice Mint accumulated escrowed fee shares to `to` and reset the counter.
    /// @dev    Settles pending fees first, so the sweep includes the latest accrual.
    ///         Refuses to send to a denylisted address (denyTo) so admin cannot route
    ///         fees around the compliance policy.
    function withdrawFees(address to) external requiresAuth {
        if (to == address(0)) revert BoringVaultWrapper__ZeroAddress();

        (, bool toDenyTo,,) = teller.beforeTransferData(to);
        if (toDenyTo) revert BoringVaultWrapper__TransferDenied(address(this), to, _msgSender());

        _accrueFees();

        uint256 shares = pendingEscrowedFeeShares;
        if (shares == 0) return;

        // Clear the counter before minting; effective supply is unchanged across this
        // operation (real supply +shares, escrowed −shares).
        pendingEscrowedFeeShares = 0;
        _mint(to, shares);
        emit FeesWithdrawn(to, shares);
    }

    /// @dev True if `recipient` cannot currently receive wrapper shares
    ///      (denyTo is set on the Teller).
    function _isFeeRecipientBlocked(address recipient) internal view returns (bool) {
        (, bool denyTo,,) = teller.beforeTransferData(recipient);
        return denyTo;
    }

    function _simulateAccruedState() internal view returns (uint256 supply, uint256 totalAss) {
        // Effective supply for user-facing share math = real supply + accrued-not-minted
        // (escrowed) fees + still-pending fee shares for the current block.
        supply = totalSupply() + pendingEscrowedFeeShares;
        totalAss = totalAssets();

        if (supply == 0) return (supply, totalAss);

        (uint256 mgmtShares, uint256 perfShares,) = _pendingFeeShares();
        supply += mgmtShares + perfShares;
    }

    // =========================================================================
    //                       INTERNAL — COMPLIANCE
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

        uint8 role = _teller.transferAllowedRole();
        if (role == type(uint8).max) return;

        RolesAuthority a = RolesAuthority(address(_teller.authority()));
        if (!a.doesUserHaveRole(operator, role) && !a.doesUserHaveRole(from, role) && !a.doesUserHaveRole(to, role)) {
            revert BoringVaultWrapper__TransferNotAllowed();
        }
    }

    function _verifyComplianceSignature(
        address user,
        address receiver,
        address asset,
        uint256 amount,
        ComplianceData calldata compliance
    ) internal {
        TellerWithMultiAssetSupport _teller = teller;
        uint8 role = _teller.complianceSignerRole();
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
