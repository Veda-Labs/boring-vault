// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

/**
 * @title  BoringVaultWrapper
 * @dev Asset model:
 *   asset()       = BoringVault shares (ERC20)
 *   totalAssets() = boringVault.balanceOf(address(this))
 *
 *   No off-chain share-price updater is needed. The wrapper's exchange rate
 *   against BV shares drifts only as fee dilution accumulates over time.
 *
 * @dev Fee model:
 *   Fees are realised as wrapper share dilution — the feeRecipient receives
 *   freshly minted shares and no underlying assets are ever extracted.
 *
 *   1. Management fee  — annualised % of AUM, accrued continuously.
 *   2. Performance fee — % of appreciation in the BV exchange rate
 *                        (accountant.getRate()) above the high-water mark.
 *
 *   Both are settled before every user action so the exchange rate is always
 *   up-to-date when deposits/withdrawals are priced.
 *
 * @dev Direct asset deposit:
 *   depositAsset() accepts any Teller-supported ERC20 (e.g. USDC, WETH, etc.)
 *   using bulkDeposit so that BV shares land in this contract in a single tx
 *   and wrapper shares are issued to the caller.
 *
 *   Requirements:
 *   - setTeller() must be called with a valid Teller address.
 *   - The asset must be enabled for deposits on the Teller.
 *   - This contract must hold the bulkDeposit role on the Teller.
 *   - The BoringVault approval is set automatically (vault.enter() pulls
 *     tokens from this contract directly).
 *
 *   Share-lock: bulkDeposit skips _afterPublicDeposit so no lock is ever set
 *   on this contract's BV shares, so any Teller shareLockPeriod is fully
 *   transparent to wrapper users.
 *
 * @dev Compliance:
 *   Standard 4626 path: safeTransferFrom(user to this) triggers the BV's
 *   BeforeTransferHook, so BV-level compliance is automatically enforced.
 *
 *   Direct-asset path: compliance is delegated to the Teller's own auth
 *   gating; the BV hook is not triggered because enter() mints directly.
 *
 *   Wrapper-share transfers have no compliance hook by default. A
 *   BeforeTransferHook can be wired in (mirroring the BoringVault pattern)
 *   if needed, at the cost of strict ERC4626 composability.
 *
 * @dev Fees-on-fees:
 *   The underlying BV Accountant may already accrue platform / performance
 *   fees via exchange-rate updates. This wrapper's fees are additive — end
 *   users effectively pay both layers.
 *
 *   White-labelling: deploy one instance per partner with independent
 *   name / symbol / feeRecipient / fee rates, all backed by the same BV.
 */
contract BoringVaultWrapper is ERC4626, Auth, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // =========================================================================
    //                              CONSTANTS
    // =========================================================================

    /// @notice Hard cap on the annual management fee: 5 % (500 bps).
    uint16 public constant MAX_MANAGEMENT_FEE = 500;

    /// @notice Hard cap on the performance fee: 50 % (5_000 bps).
    uint16 public constant MAX_PERFORMANCE_FEE = 5_000;

    // =========================================================================
    //                              IMMUTABLES
    // =========================================================================

    /// @notice The BoringVault whose shares are held as this wrapper's underlying asset.
    BoringVault public immutable boringVault;

    /**
     * @notice Accountant that exposes the live BV share price via getRate().
     * @dev    Used exclusively for tracking the performance-fee high-water mark.
     *         The wrapper does NOT need the accountant to be updated to function;
     *         management fees work independently of it.
     */
    AccountantWithRateProviders public immutable accountant;

    // =========================================================================
    //                               STATE
    // =========================================================================

    /**
     * @notice Optional Teller used by depositAsset().
     */
    TellerWithMultiAssetSupport public teller;

    /// @notice Address that receives all accrued fee shares.
    address public feeRecipient;

    /// @notice Annual management fee in basis points (e.g. 200 = 2 %).
    uint16 public managementFee;

    /// @notice Performance fee on BV exchange-rate gains in bps (e.g. 1_000 = 10 %).
    uint16 public performanceFee;

    /// @notice Block timestamp of the last fee accrual.
    uint64 public lastFeeAccrual;

    /**
     * @notice BV exchange rate recorded at the last fee accrual.
     * @dev    Performance fees are only charged on appreciation above this value.
     *         Stored as the same unit returned by accountant.getRate().
     */
    uint96 public performanceHighWaterMark;

    // =========================================================================
    //                               ERRORS
    // =========================================================================

    error BoringVaultWrapper__ZeroAddress();
    error BoringVaultWrapper__FeeTooHigh();
    error BoringVaultWrapper__TellerNotSet();
    error BoringVaultWrapper__ZeroBVSharesReceived();
    error BoringVaultWrapper__BadTeller();
    error BoringVaultWrapper__BadAccountant();

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
    event HighWaterMarkUpdated(uint96 oldHWM, uint96 newHWM);

    // =========================================================================
    //                             CONSTRUCTOR
    // =========================================================================

    /**
     * @param _owner       Initial admin of this wrapper instance.
     * @param _boringVault BoringVault to wrap; its shares become asset().
     * @param _accountant  Provides BV share price for performance-fee HWM.
     * @param _teller      Teller used by depositAsset() / redeemAsset(); must reference
     *                     the same BoringVault. Fee configuration (recipient and rates)
     *                     starts at zero and must be set via setFeeConfig().
     * @param _name        ERC20 name  of the wrapper shares (partner-branded).
     * @param _symbol      ERC20 symbol of the wrapper shares (partner-branded).
     */
    constructor(
        address _owner,
        address _boringVault,
        address _accountant,
        address _teller,
        string memory _name,
        string memory _symbol
    ) ERC4626(ERC20(_boringVault), _name, _symbol) Auth(_owner, Authority(address(0))) {
        if (address(TellerWithMultiAssetSupport(_teller).vault()) != address(_boringVault)) {
            revert BoringVaultWrapper__BadTeller();
        }
        if (address(AccountantWithRateProviders(_accountant).vault()) != address(_boringVault)) {
            revert BoringVaultWrapper__BadAccountant();
        }

        boringVault = BoringVault(payable(_boringVault));
        accountant = AccountantWithRateProviders(_accountant);
        lastFeeAccrual = uint64(block.timestamp);

        // feeRecipient, managementFee, and performanceFee start at zero.
        // Call setFeeConfig() after deployment to enable fee accrual.

        teller = TellerWithMultiAssetSupport(_teller);
        emit TellerSet(address(0), _teller);

        // Seed HWM from the live rate so no retroactive performance fees are charged
        // on appreciation that occurred before this wrapper was deployed.
        performanceHighWaterMark = uint96(AccountantWithRateProviders(_accountant).getRate());
    }

    // =========================================================================
    //                              ADMIN
    // =========================================================================

    /**
     * @notice Update all three fee configuration parameters atomically.
     * @dev    Accrues pending fees at the *current* rates before applying new values
     *         so no earnings are mis-attributed. Pass the current value for any
     *         parameter you do not wish to change.
     * @param _feeRecipient   Address that receives accrued fee shares. Must be non-zero.
     * @param _managementFee  Annual management fee in bps (≤ MAX_MANAGEMENT_FEE).
     * @param _performanceFee Performance fee in bps (≤ MAX_PERFORMANCE_FEE).
     */
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

    /**
     * @notice Set the Teller. In rare ocasions the Teller can be changed on some BoringVault
     * @dev    The wrapper vault must be granted the SOLVER_ROLE role on the Teller
     */
    function setTeller(address newTeller) external requiresAuth {
        if (address(TellerWithMultiAssetSupport(newTeller).vault()) != address(boringVault)) revert BoringVaultWrapper__BadTeller();
        emit TellerSet(address(teller), newTeller);
        teller = TellerWithMultiAssetSupport(newTeller);
    }

    /**
     * @notice Manually trigger a fee accrual without performing a deposit/withdraw.
     */
    function accrueFees() external {
        _accrueFees();
    }

    // =========================================================================
    //                         ERC4626 — totalAssets
    // =========================================================================

    /**
     * @notice Total BoringVault shares held by this wrapper.
     */
    function totalAssets() public view override returns (uint256) {
        return boringVault.balanceOf(address(this));
    }

    // =========================================================================
    //                    ERC4626 — deposit / mint / withdraw / redeem
    // =========================================================================
    //
    //  Each public entry-point calls _accrueFees() first so the exchange rate is
    //  always current before any share arithmetic runs.  After accrual,
    //  lastFeeAccrual == block.timestamp, so the preview functions (which call
    //  _simulateAccruedState) will see zero pending fees and agree with the
    //  actual execution path.
    //
    // =========================================================================

    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        _accrueFees();
        shares = super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        _accrueFees();
        assets = super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 shares)
    {
        _accrueFees();
        shares = super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        returns (uint256 assets)
    {
        _accrueFees();
        assets = super.redeem(shares, receiver, owner);
    }

    // =========================================================================
    //                    ERC4626 — preview / convert overrides
    // =========================================================================
    //
    //  All preview and convert functions simulate the pending fee accrual so that
    //  off-chain quotes match on-chain execution even if _accrueFees() has not
    //  been called recently.
    //
    //  Solmate's previewDeposit delegates to convertToShares, and previewRedeem
    //  delegates to convertToAssets, so overriding those two is sufficient for
    //  those directions.  previewMint and previewWithdraw use mulDivUp directly
    //  against raw state, so they need their own overrides.
    //
    // =========================================================================

    /// @dev Rounds down (in the vault's favour) per ERC4626 spec.
    function convertToShares(uint256 assets) public view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return supply == 0 ? assets : assets.mulDivDown(supply, totalAss);
    }

    /// @dev Rounds down (in the vault's favour) per ERC4626 spec.
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return supply == 0 ? shares : shares.mulDivDown(totalAss, supply);
    }

    /// @dev Rounds up (in the vault's favour) per ERC4626 spec.
    function previewMint(uint256 shares) public view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return supply == 0 ? shares : shares.mulDivUp(totalAss, supply);
    }

    /// @dev Rounds up (in the vault's favour) per ERC4626 spec.
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        (uint256 supply, uint256 totalAss) = _simulateAccruedState();
        return supply == 0 ? assets : assets.mulDivUp(supply, totalAss);
    }

    // =========================================================================
    //                       DIRECT ASSET DEPOSIT
    // =========================================================================

    /**
     * @notice Deposit a raw asset (e.g. USDC) and receive wrapper shares in one tx.
     *
     * @dev    Execution flow:
     *           1. Accrue pending fees (snapshot the correct pre-deposit BV balance).
     *           2. Pull rawAsset from caller into this contract.
     *           3. Approve the BoringVault — not the Teller — because vault.enter()
     *              pulls tokens from msg.sender (= this contract) directly.
     *           4. Call teller.bulkDeposit(rawAsset, rawAmount, minBVShares, address(this))
     *              so BV shares are minted here without setting a share lock.
     *           5. Compute wrapper shares proportional to BV shares received and mint.
     *
     * @dev    Role requirement: this contract must hold the bulkDeposit role on the
     *         configured Teller.
     *
     * @param rawAsset     ERC20 to deposit (must be supported by the Teller).
     * @param rawAmount    Amount of rawAsset to deposit.
     * @param minBVShares  Minimum BV shares to receive (slippage guard passed to Teller).
     * @param receiver     Address that receives the minted wrapper shares.
     * @return wrapperShares  Wrapper shares minted to receiver.
     */
    function depositAsset(
        ERC20 rawAsset,
        uint256 rawAmount,
        uint256 minBVShares,
        address receiver
    ) external nonReentrant returns (uint256 wrapperShares) {
        TellerWithMultiAssetSupport _teller = teller;
        if (address(_teller) == address(0)) revert BoringVaultWrapper__TellerNotSet();

        // Settle fees before snapshotting the pre-deposit BV balance so the
        // per-share ratio used below reflects the true current state.
        _accrueFees();

        uint256 bvBefore = boringVault.balanceOf(address(this));
        uint256 supplyBefore = totalSupply;

        // Pull the raw asset from the caller.
        rawAsset.safeTransferFrom(msg.sender, address(this), rawAmount);

        // vault.enter() pulls from msg.sender (= this contract), so the BoringVault
        // needs the approval, not the Teller.  Reset before setting to handle
        // non-standard tokens that revert on non-zero → non-zero approvals.
        rawAsset.safeApprove(address(boringVault), 0);
        rawAsset.safeApprove(address(boringVault), rawAmount);

        // bulkDeposit mints BV shares to this contract without setting a share
        // lock or requiring a compliance signature.
        _teller.bulkDeposit(rawAsset, rawAmount, minBVShares, address(this));

        uint256 bvReceived = boringVault.balanceOf(address(this)) - bvBefore;
        if (bvReceived == 0) revert BoringVaultWrapper__ZeroBVSharesReceived();

        // Mint wrapper shares proportional to BV shares received.
        // First deposit seeds at 1 : 1 (supply == 0 branch).
        wrapperShares = supplyBefore == 0 ? bvReceived : bvReceived.mulDivDown(supplyBefore, bvBefore);

        _mint(receiver, wrapperShares);

        emit Deposit(msg.sender, receiver, bvReceived, wrapperShares);
    }

    // =========================================================================
    //                       DIRECT ASSET REDEEM
    // =========================================================================

    /**
     * @notice Burn wrapper shares and receive any Teller-supported asset.
     *
     * @dev    Execution flow:
     *           1. Accrue pending fees so the BV-share ratio is current.
     *           2. Spend caller's allowance when msg.sender != owner.
     *           3. Compute bvToRedeem = wrapperShares × totalBV / totalSupply.
     *           4. Burn wrapper shares from owner (before the external Teller call
     *              to prevent reentrancy double-spend).
     *           5. Call teller.bulkWithdraw(asset, bvToRedeem, minAssetOut, receiver).
     *              The Teller burns bvToRedeem BV shares from this contract and
     *              transfers the asset directly to receiver.
     *           6. Return the asset amount received.
     *
     * @dev    Role requirement: this contract must hold the bulkWithdraw role on
     *         the configured Teller.
     *
     * @param asset          ERC20 to receive (must be supported for withdrawal by the Teller).
     * @param wrapperShares  Wrapper shares to burn.
     * @param minAssetOut    Minimum asset amount to receive (slippage guard, passed to Teller).
     * @param receiver       Address that receives the asset.
     * @param owner          Address whose wrapper shares are burned.
     * @return assetOut      Amount of asset sent to receiver.
     */
    function redeemAsset(
        ERC20 asset,
        uint256 wrapperShares,
        uint256 minAssetOut,
        address receiver,
        address owner
    ) external nonReentrant returns (uint256 assetOut) {
        TellerWithMultiAssetSupport _teller = teller;
        if (address(_teller) == address(0)) revert BoringVaultWrapper__TellerNotSet();

        _accrueFees();

        // Spend allowance when the caller is acting on behalf of owner,
        // mirroring the ERC4626 redeem() allowance pattern.
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) {
                allowance[owner][msg.sender] = allowed - wrapperShares; // underflow → revert
            }
        }

        // Snapshot state after fee accrual but before burning.
        uint256 supply = totalSupply;
        uint256 totalBV = boringVault.balanceOf(address(this));

        // Proportional BV shares owed to the owner (rounds down, vault-favourable).
        uint256 bvToRedeem = wrapperShares.mulDivDown(totalBV, supply);

        // Burn wrapper shares BEFORE the external Teller call to prevent any
        // reentrancy from double-spending the same wrapper shares.
        _burn(owner, wrapperShares);

        // bulkWithdraw burns bvToRedeem BV shares from this contract and sends
        // the asset directly to receiver.
        assetOut = _teller.bulkWithdraw(asset, bvToRedeem, minAssetOut, receiver);

        emit Withdraw(msg.sender, receiver, owner, bvToRedeem, wrapperShares);
    }

    // =========================================================================
    //                         INTERNAL — FEE ENGINE
    // =========================================================================

    /**
     * @notice Computes pending management and performance fee shares without touching state.
     * @dev    Single source of truth for fee arithmetic, shared by the mutating
     *         _accrueFees() and the view-only _simulateAccruedState().
     *
     * @dev    Management fee
     *         ──────────────
     *         Continuously dilutes existing holders at an annualised rate:
     *
     *           mgmtShares = supply × feeRate × elapsed / (1e4 × 365 days)
     *
     *         Performance fee
     *         ───────────────
     *         Charges a % of the appreciation in the BV exchange rate (accountant.getRate())
     *         above the stored high-water mark, expressed as wrapper-share dilution:
     *
     *           gainBV     = totalBVShares × (currentRate − hwm) / currentRate
     *           feeBV      = gainBV × perfFee / 1e4
     *           perfShares = feeBV × supply / totalBVShares
     *
     *         The perfShares calculation slightly under-charges (the denominator ignores
     *         the dilution from mgmtShares itself).  The error is O(fee²) and negligible
     *         at realistic fee rates, but using `supply + mgmtShares` in the numerator
     *         partially corrects for it.
     *
     * @return mgmtShares  Wrapper shares owed as management fee.
     * @return perfShares  Wrapper shares owed as performance fee.
     * @return newHWM      New high-water mark to commit (0 = no update needed).
     */
    function _pendingFeeShares()
        internal
        view
        returns (uint256 mgmtShares, uint256 perfShares, uint96 newHWM)
    {
        uint256 supply = totalSupply;
        if (supply == 0) return (0, 0, 0);

        // ── Management fee ────────────────────────────────────────────────────
        uint16 mgmtFee = managementFee;
        uint256 elapsed = block.timestamp - lastFeeAccrual;

        if (mgmtFee > 0 && elapsed > 0) {
            mgmtShares = supply.mulDivDown(uint256(mgmtFee) * elapsed, uint256(1e4) * 365 days);
        }

        // ── Performance fee ───────────────────────────────────────────────────
        uint16 perfFee = performanceFee;
        if (perfFee > 0) {
            uint256 currentRate = accountant.getRate(); // BV share price in base
            uint96 hwm = performanceHighWaterMark;

            if (currentRate > uint256(hwm)) {
                newHWM = uint96(currentRate);
                uint256 totalBV = totalAssets(); // boringVault.balanceOf(this)

                // How many BV shares represent the price-appreciation gain at
                // today's price:  totalBV × (currentRate − hwm) / currentRate
                uint256 gainBV = totalBV.mulDivDown(currentRate - uint256(hwm), currentRate);
                uint256 feeBV = gainBV.mulDivDown(perfFee, 1e4);

                // Convert the BV-share fee into wrapper shares so we can mint
                // instead of extracting underlying assets.
                // Use (supply + mgmtShares) to partially account for the mgmt
                // dilution that is about to happen in the same accrual.
                if (feeBV > 0 && totalBV > 0) {
                    perfShares = feeBV.mulDivDown(supply + mgmtShares, totalBV);
                }
            }
        }
    }

    /**
     * @notice Mint all pending management and performance fee shares to feeRecipient.
     * @dev    Called at the top of every deposit / mint / withdraw / redeem so the
     *         exchange rate is always settled before any share arithmetic.
     */
    function _accrueFees() internal {
        uint64 now_ = uint64(block.timestamp);

        if (totalSupply == 0) {
            lastFeeAccrual = now_;
            return;
        }

        (uint256 mgmtShares, uint256 perfShares, uint96 newHWM) = _pendingFeeShares();

        if (newHWM != 0) {
            emit HighWaterMarkUpdated(performanceHighWaterMark, newHWM);
            performanceHighWaterMark = newHWM;
        }

        // Commit timestamp before minting to keep state consistent if a
        // reentrant call somehow triggers here (guarded by nonReentrant above).
        lastFeeAccrual = now_;

        uint256 total = mgmtShares + perfShares;
        if (total > 0 && feeRecipient != address(0)) {
            _mint(feeRecipient, total);
            emit FeesAccrued(mgmtShares, perfShares);
        }
    }

    /**
     * @notice View mirror of _accrueFees(): returns what supply and totalAssets
     *         would be if fees were settled right now.
     * @dev    Used by convertToShares / convertToAssets / previewMint / previewWithdraw
     *         so off-chain quotes and on-chain execution always agree.
     * @return supply    Post-accrual total supply (pre-accrual supply + fee shares).
     * @return totalAss  Total assets — unchanged, because fees are dilution not extraction.
     */
    function _simulateAccruedState() internal view returns (uint256 supply, uint256 totalAss) {
        supply = totalSupply;
        totalAss = totalAssets();

        if (supply == 0) return (supply, totalAss);

        (uint256 mgmtShares, uint256 perfShares,) = _pendingFeeShares();
        supply += mgmtShares + perfShares;
        // totalAss deliberately unchanged — fees are dilution, not extraction.
    }
}
