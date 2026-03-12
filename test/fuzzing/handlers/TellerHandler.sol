// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Test and console unused but keeping for debugging if needed
import {CommonBase} from "@forge-std/Base.sol";
import {StdCheats} from "@forge-std/StdCheats.sol";
import {StdUtils} from "@forge-std/StdUtils.sol";

import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {AccountantHandler} from "./AccountantHandler.sol";

/**
 * @title TellerHandler
 * @notice Handler contract for fuzzing teller operations with ghost state tracking
 * @dev Tracks pre/post state for invariant verification
 */
contract TellerHandler is CommonBase, StdCheats, StdUtils {
    using FixedPointMathLib for uint256;

    // ============================================
    // CONSTANTS
    // ============================================
    
    uint256 public constant NUM_ALT_ASSETS = 5;
    
    // Decimals for each alternative asset (must match BaseSetup)
    // Index 0: 18 decimals (standard ERC20)
    // Index 1: 6 decimals (USDC-like)
    // Index 2: 6 decimals (USDT-like)
    // Index 3: 8 decimals (WBTC-like)
    // Index 4: 11 decimals (unusual, edge case)
    uint8[5] public ALT_ASSET_DECIMALS = [18, 6, 6, 8, 11];

    // ============================================
    // CONTRACTS
    // ============================================
    
    TellerWithMultiAssetSupport public tellerMAS;
    TellerWithYieldStreaming public tellerYS;
    BoringVault public vaultRP;  // Vault for RP system (MAS teller)
    BoringVault public vaultYS;  // Vault for YS system (YS teller)
    ERC20 public baseAsset;
    
    // Multiple alternative assets for RP multi-asset testing
    ERC20[] public alternativeAssets;
    
    AccountantHandler public accountantHandler;
    
    address public owner;
    address public solver;
    address public deniedUser;
    address[] public actors;
    
    // ============================================
    // GHOST STATE - Pre-call snapshots
    // ============================================
    
    struct TellerState {
        uint64 depositNonce;
        uint64 shareLockPeriod;
        bool isPaused;
        uint112 depositCap;
        uint256 vaultTotalSupply;
        uint256 vaultBaseBalance;
        uint256[5] vaultAltBalances;  // Balances for each alternative asset
        uint256 tellerBaseBalance;
        uint256[5] tellerAltBalances; // Balances for each alternative asset
    }
    
    struct UserState {
        uint256 shares;
        uint256 baseBalance;
        uint256 shareUnlockTime;
        bool denyFrom;
        bool denyTo;
        bool denyOperator;
    }
    
    TellerState public preMAS;
    TellerState public postMAS;
    TellerState public preYS;
    TellerState public postYS;
    
    mapping(address => UserState) public preUserState;
    mapping(address => UserState) public postUserState;
    
    // Current actor being used in operations
    address public currentActor;
    
    // ============================================
    // TRACKING VARIABLES
    // ============================================
    
    // Track the last selector called
    bytes4 public lastSelector;
    
    // External call tracking (always false - no unauthorized calls in handlers)
    bool public constant callMade = false;
    bool public constant delegatecallMade = false;
    
    // Counters for statistics (successful calls)
    uint256 public depositCalls;
    uint256 public withdrawCalls;
    uint256 public bulkDepositCalls;
    uint256 public bulkWithdrawCalls;
    
    // Track deposit history for refund testing
    struct DepositRecord {
        address receiver;
        address depositAsset;
        uint256 depositAmount;
        uint256 shareAmount;
        uint256 timestamp;
        uint256 shareLockPeriod;
        address referralAddress;
        bool refunded;
    }
    
    mapping(uint256 => DepositRecord) public depositHistory;
    uint256[] public depositNonces;
    
    // Round-trip tracking for no-free-assets invariant
    uint256 public lastDepositAssets;
    uint256 public lastDepositShares;
    uint256 public lastWithdrawAssets;
    uint256 public lastWithdrawShares;
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor(
        address _tellerMAS,
        address _tellerYS,
        address _vaultRP,
        address _vaultYS,
        address _baseAsset,
        address[] memory _alternativeAssets,
        address _owner,
        address _solver,
        address _deniedUser,
        address[] memory _actors
    ) {
        require(_alternativeAssets.length == NUM_ALT_ASSETS, "Must provide NUM_ALT_ASSETS alternative assets");
        
        tellerMAS = TellerWithMultiAssetSupport(_tellerMAS);
        tellerYS = TellerWithYieldStreaming(_tellerYS);
        vaultRP = BoringVault(payable(_vaultRP));
        vaultYS = BoringVault(payable(_vaultYS));
        baseAsset = ERC20(_baseAsset);
        
        // Initialize alternative assets array
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            alternativeAssets.push(ERC20(_alternativeAssets[i]));
        }
        
        owner = _owner;
        solver = _solver;
        deniedUser = _deniedUser;
        actors = _actors;
    }
    
    /**
     * @notice Set the AccountantHandler reference for vesting sync
     * @dev Called after construction to link TellerHandler with AccountantHandler
     */
    function setAccountantHandler(address _accountantHandler) external {
        accountantHandler = AccountantHandler(_accountantHandler);
    }
    
    // ============================================
    // SNAPSHOT FUNCTIONS
    // ============================================
    
    function _snapshotTellerMASState() internal view returns (TellerState memory state) {
        state.depositNonce = tellerMAS.depositNonce();
        state.shareLockPeriod = tellerMAS.shareLockPeriod();
        state.isPaused = tellerMAS.isPaused();
        state.depositCap = tellerMAS.depositCap();
        state.vaultTotalSupply = vaultRP.totalSupply();
        state.vaultBaseBalance = baseAsset.balanceOf(address(vaultRP));
        state.tellerBaseBalance = baseAsset.balanceOf(address(tellerMAS));
        
        // Snapshot all alternative asset balances
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            state.vaultAltBalances[i] = alternativeAssets[i].balanceOf(address(vaultRP));
            state.tellerAltBalances[i] = alternativeAssets[i].balanceOf(address(tellerMAS));
        }
    }
    
    function _snapshotTellerYSState() internal view returns (TellerState memory state) {
        state.depositNonce = tellerYS.depositNonce();
        state.shareLockPeriod = tellerYS.shareLockPeriod();
        state.isPaused = tellerYS.isPaused();
        state.depositCap = tellerYS.depositCap();
        state.vaultTotalSupply = vaultYS.totalSupply();
        state.vaultBaseBalance = baseAsset.balanceOf(address(vaultYS));
        state.tellerBaseBalance = baseAsset.balanceOf(address(tellerYS));
        
        // YS only uses base asset, but snapshot alt balances as 0 for consistency
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            state.vaultAltBalances[i] = 0;
            state.tellerAltBalances[i] = 0;
        }
    }
    
    function _snapshotUserState(address user) internal view returns (UserState memory state) {
        // Track shares in both vaults
        state.shares = vaultRP.balanceOf(user) + vaultYS.balanceOf(user);
        state.baseBalance = baseAsset.balanceOf(user);
        
        (bool denyFrom, bool denyTo, bool denyOperator, , uint256 unlockTime) = tellerMAS.beforeTransferData(user);
        state.shareUnlockTime = unlockTime;
        state.denyFrom = denyFrom;
        state.denyTo = denyTo;
        state.denyOperator = denyOperator;
    }
    
    function _beforeCall(bytes4 selector, address actor) internal {
        lastSelector = selector;
        currentActor = actor;
        
        // Reset operation tracking - only set if current call succeeds
        lastDepositAssets = 0;
        lastDepositShares = 0;
        lastWithdrawAssets = 0;
        lastWithdrawShares = 0;
        
        preMAS = _snapshotTellerMASState();
        preYS = _snapshotTellerYSState();
        
        for (uint256 i = 0; i < actors.length; i++) {
            preUserState[actors[i]] = _snapshotUserState(actors[i]);
        }
        preUserState[deniedUser] = _snapshotUserState(deniedUser);
        preUserState[solver] = _snapshotUserState(solver);
    }
    
    function _afterCall() internal {
        postMAS = _snapshotTellerMASState();
        postYS = _snapshotTellerYSState();
        
        for (uint256 i = 0; i < actors.length; i++) {
            postUserState[actors[i]] = _snapshotUserState(actors[i]);
        }
        postUserState[deniedUser] = _snapshotUserState(deniedUser);
        postUserState[solver] = _snapshotUserState(solver);
    }
    
    function _getRandomActor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }
    
    /**
     * @notice Find an actor with YS vault shares
     * @param seed Random seed for starting position
     * @return actor Address with shares, or address(0) if none found
     */
    function _getActorWithSharesYS(uint256 seed) internal view returns (address) {
        uint256 len = actors.length;
        uint256 startIdx = seed % len;
        for (uint256 i = 0; i < len; i++) {
            address candidate = actors[(startIdx + i) % len];
            if (vaultYS.balanceOf(candidate) > 0) {
                return candidate;
            }
        }
        return address(0);
    }
    
    // ============================================
    // MULTI-ASSET SUPPORT TELLER HANDLERS
    // ============================================
    
    /**
     * @notice Deposit into TellerWithMultiAssetSupport
     */
    function depositMAS(uint256 actorSeed, uint256 amount, uint256 minShares) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.deposit.selector, actor);
        
        amount = bound(amount, 1, 100_000e18);
        
        // Calculate expected shares based on current rate to set realistic minShares
        uint256 rate = accountantHandler.accountantRP().getRate();
        uint256 expectedShares = (amount * 1e18) / rate;
        // Bound minShares to 0-95% of expected to allow some slippage margin
        minShares = bound(minShares, 0, (expectedShares * 95) / 100);
        
        vm.startPrank(actor);
        baseAsset.approve(address(vaultRP), amount);
        
        uint256 shares = tellerMAS.deposit(baseAsset, amount, minShares, address(0));
        
        if (shares > 0) {
            depositCalls++;
            lastDepositAssets = amount;
            lastDepositShares = shares;
            
            uint64 nonce = tellerMAS.depositNonce();
            depositHistory[nonce] = DepositRecord({
                receiver: actor,
                depositAsset: address(baseAsset),
                depositAmount: amount,
                shareAmount: shares,
                timestamp: block.timestamp,
                shareLockPeriod: tellerMAS.shareLockPeriod(),
                referralAddress: address(0),
                refunded: false
            });
            depositNonces.push(nonce);
        }
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Withdraw from TellerWithMultiAssetSupport
     */
    function withdrawMAS(uint256 actorSeed, uint256 shareAmount, uint256 minAssets, uint256 timeDelta) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.withdraw.selector, actor);
        
        uint256 actorShares = vaultRP.balanceOf(actor);
        if (actorShares == 0) {
            _afterCall();
            return;
        }
        
        shareAmount = bound(shareAmount, 1, actorShares);
        minAssets = bound(minAssets, 0, shareAmount);
        timeDelta = bound(timeDelta, 0, 7 days);
        
        vm.warp(block.timestamp + timeDelta);
        if (address(accountantHandler) != address(0)) accountantHandler.syncVestedAssets();
        
        vm.startPrank(actor);
        uint256 assets = tellerMAS.withdraw(baseAsset, shareAmount, minAssets, actor);
        withdrawCalls++;
        lastWithdrawShares = shareAmount;
        lastWithdrawAssets = assets;
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Bulk deposit via solver
     */
    function bulkDepositMAS(uint256 amount, uint256 minShares, uint256 actorSeed) external {
        address recipient = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.bulkDeposit.selector, solver);
        
        amount = bound(amount, 1, 100_000e18);
        
        // Calculate expected shares based on current rate to set realistic minShares
        uint256 rate = accountantHandler.accountantRP().getRate();
        uint256 expectedShares = (amount * 1e18) / rate;
        // Bound minShares to 0-95% of expected to allow some slippage margin
        minShares = bound(minShares, 0, (expectedShares * 95) / 100);
        
        vm.startPrank(solver);
        baseAsset.approve(address(vaultRP), amount);
        
        uint256 shares = tellerMAS.bulkDeposit(baseAsset, amount, minShares, recipient);
        if (shares > 0) {
            bulkDepositCalls++;
            lastDepositAssets = amount;
            lastDepositShares = shares;
        }
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Bulk withdraw via solver
     */
    function bulkWithdrawMAS(uint256 shareAmount, uint256 minAssets, uint256 actorSeed) external {
        address recipient = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.bulkWithdraw.selector, solver);
        
        uint256 solverShares = vaultRP.balanceOf(solver);
        if (solverShares == 0) {
            _afterCall();
            return;
        }
        
        shareAmount = bound(shareAmount, 1, solverShares);
        minAssets = bound(minAssets, 0, shareAmount);
        
        vm.startPrank(solver);
        uint256 assets = tellerMAS.bulkWithdraw(baseAsset, shareAmount, minAssets, recipient);
        bulkWithdrawCalls++;
        lastWithdrawShares = shareAmount;
        lastWithdrawAssets = assets;
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Refund a deposit
     */
    function refundDepositMAS(uint256 nonceIndex) external {
        if (depositNonces.length == 0) return;
        
        nonceIndex = bound(nonceIndex, 0, depositNonces.length - 1);
        uint256 nonce = depositNonces[nonceIndex];
        DepositRecord storage record = depositHistory[nonce];
        
        if (record.refunded) return;
        
        _beforeCall(TellerWithMultiAssetSupport.refundDeposit.selector, owner);
        
        vm.prank(owner);
        try tellerMAS.refundDeposit(
            nonce,
            record.receiver,
            record.depositAsset,
            record.depositAmount,
            record.shareAmount,
            record.timestamp,
            record.shareLockPeriod,
            record.referralAddress
        ) {
            record.refunded = true;
        } catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Pause TellerWithMultiAssetSupport
     */
    function pauseMAS() external {
        _beforeCall(TellerWithMultiAssetSupport.pause.selector, owner);
        
        vm.prank(owner);
        try tellerMAS.pause() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Unpause TellerWithMultiAssetSupport
     */
    function unpauseMAS() external {
        _beforeCall(TellerWithMultiAssetSupport.unpause.selector, owner);
        
        vm.prank(owner);
        try tellerMAS.unpause() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Deny a user
     */
    function denyUserMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.denyAll.selector, owner);
        
        vm.prank(owner);
        tellerMAS.denyAll(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Allow a user
     */
    function allowUserMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.allowAll.selector, owner);
        
        vm.prank(owner);
        tellerMAS.allowAll(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Set share lock period
     */
    function setShareLockPeriodMAS(uint64 period) external {
        _beforeCall(TellerWithMultiAssetSupport.setShareLockPeriod.selector, owner);
        
        period = uint64(bound(period, 0, 3 days));
        
        vm.prank(owner);
        tellerMAS.setShareLockPeriod(period);
        
        _afterCall();
    }
    
    /**
     * @notice Set deposit cap
     */
    function setDepositCapMAS(uint112 cap) external {
        _beforeCall(TellerWithMultiAssetSupport.setDepositCap.selector, owner);
        
        cap = uint112(bound(cap, 1, type(uint112).max));
        
        vm.prank(owner);
        tellerMAS.setDepositCap(cap);
        
        _afterCall();
    }
    
    /**
     * @notice Update asset data (allowDeposits, allowWithdraws, sharePremium)
     */
    function updateAssetDataMAS(uint256 assetIndex, bool allowDeposits, bool allowWithdraws, uint16 sharePremium) external {
        _beforeCall(TellerWithMultiAssetSupport.updateAssetData.selector, owner);
        
        assetIndex = bound(assetIndex, 0, NUM_ALT_ASSETS);
        sharePremium = uint16(bound(sharePremium, 0, 1000));
        
        ERC20 asset;
        if (assetIndex == 0) {
            asset = baseAsset;
        } else {
            asset = alternativeAssets[assetIndex - 1];
        }
        
        vm.prank(owner);
        tellerMAS.updateAssetData(asset, allowDeposits, allowWithdraws, sharePremium);
        
        _afterCall();
    }
    
    /**
     * @notice Small deposit for edge case testing
     */
    function depositTinyMAS(uint256 actorSeed, uint256 amount) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.deposit.selector, actor);
        
        amount = bound(amount, 1, 1e18);
        
        vm.startPrank(actor);
        baseAsset.approve(address(vaultRP), amount);
        
        uint256 shares = tellerMAS.deposit(baseAsset, amount, 0, address(0));
        if (shares > 0) {
            depositCalls++;
            lastDepositAssets = amount;
            lastDepositShares = shares;
        }
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Withdraw with zero time delta to test locked shares
     */
    function withdrawLockedMAS(uint256 actorSeed, uint256 shareAmount, uint256 minAssets) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.withdraw.selector, actor);
        
        uint256 actorShares = vaultRP.balanceOf(actor);
        if (actorShares == 0) {
            _afterCall();
            return;
        }
        
        shareAmount = bound(shareAmount, 1, actorShares);
        minAssets = bound(minAssets, 0, shareAmount);
        
        vm.startPrank(actor);
        uint256 assets = tellerMAS.withdraw(baseAsset, shareAmount, minAssets, actor);
        withdrawCalls++;
        lastWithdrawShares = shareAmount;
        lastWithdrawAssets = assets;
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Withdraw with minAssets = 0 to test zero-output edge cases
     */
    function withdrawZeroMinMAS(uint256 actorSeed, uint256 shareAmount, uint256 timeDelta) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.withdraw.selector, actor);
        
        uint256 actorShares = vaultRP.balanceOf(actor);
        if (actorShares == 0) {
            _afterCall();
            return;
        }
        
        shareAmount = bound(shareAmount, 1, actorShares);
        timeDelta = bound(timeDelta, 0, 7 days);
        
        vm.warp(block.timestamp + timeDelta);
        if (address(accountantHandler) != address(0)) accountantHandler.syncVestedAssets();
        
        vm.startPrank(actor);
        uint256 assets = tellerMAS.withdraw(baseAsset, shareAmount, 0, actor);
        withdrawCalls++;
        lastWithdrawShares = shareAmount;
        lastWithdrawAssets = assets;
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Individual deny control - deny from only
     */
    function denyFromMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.denyFrom.selector, owner);
        
        vm.prank(owner);
        tellerMAS.denyFrom(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Individual deny control - deny to only
     */
    function denyToMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.denyTo.selector, owner);
        
        vm.prank(owner);
        tellerMAS.denyTo(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Individual allow control - allow from only
     */
    function allowFromMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.allowFrom.selector, owner);
        
        vm.prank(owner);
        tellerMAS.allowFrom(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Individual allow control - allow to only
     */
    function allowToMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.allowTo.selector, owner);
        
        vm.prank(owner);
        tellerMAS.allowTo(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Individual deny control - deny operator only
     */
    function denyOperatorMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.denyOperator.selector, owner);
        
        vm.prank(owner);
        tellerMAS.denyOperator(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Individual allow control - allow operator only
     */
    function allowOperatorMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.allowOperator.selector, owner);
        
        vm.prank(owner);
        tellerMAS.allowOperator(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Set permissioned transfers mode
     */
    function setPermissionedTransfersMAS(bool enabled) external {
        _beforeCall(TellerWithMultiAssetSupport.setPermissionedTransfers.selector, owner);
        
        vm.prank(owner);
        tellerMAS.setPermissionedTransfers(enabled);
        
        _afterCall();
    }
    
    /**
     * @notice Allow a permissioned operator
     */
    function allowPermissionedOperatorMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.allowPermissionedOperator.selector, owner);
        
        vm.prank(owner);
        tellerMAS.allowPermissionedOperator(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Deny a permissioned operator
     */
    function denyPermissionedOperatorMAS(uint256 actorSeed) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.denyPermissionedOperator.selector, owner);
        
        vm.prank(owner);
        tellerMAS.denyPermissionedOperator(actor);
        
        _afterCall();
    }
    
    /**
     * @notice Test deposit near cap boundary
     */
    function depositNearCapMAS(uint256 actorSeed, uint256 amount) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.deposit.selector, actor);
        
        uint112 cap = tellerMAS.depositCap();
        uint256 currentSupply = vaultRP.totalSupply();
        
        if (cap == type(uint112).max || currentSupply >= cap) {
            _afterCall();
            return;
        }
        
        uint256 remainingCap = cap - currentSupply;
        uint256 minAmount = remainingCap > 100 ? remainingCap - 100 : 1;
        uint256 maxAmount = remainingCap + 100;
        amount = bound(amount, minAmount, maxAmount);
        
        vm.startPrank(actor);
        baseAsset.approve(address(vaultRP), amount);
        
        uint256 shares = tellerMAS.deposit(baseAsset, amount, 0, address(0));
        if (shares > 0) {
            depositCalls++;
            lastDepositAssets = amount;
            lastDepositShares = shares;
        }
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Set deposit cap to a specific value near current supply
     */
    function setDepositCapNearSupplyMAS(uint256 offset) external {
        _beforeCall(TellerWithMultiAssetSupport.setDepositCap.selector, owner);
        
        uint256 currentSupply = vaultRP.totalSupply();
        offset = bound(offset, 0, 1000);
        uint112 cap = uint112(bound(currentSupply + offset, 1, type(uint112).max));
        
        vm.prank(owner);
        tellerMAS.setDepositCap(cap);
        
        _afterCall();
    }
    
    // ============================================
    // ALTERNATIVE ASSET HANDLERS (for multi-asset testing)
    // ============================================
    
    /**
     * @notice Deposit alternative asset into TellerWithMultiAssetSupport
     */
    function depositAltMAS(uint256 assetIndex, uint256 actorSeed, uint256 amount, uint256 minShares) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.deposit.selector, actor);
        
        assetIndex = bound(assetIndex, 0, NUM_ALT_ASSETS - 1);
        
        uint8 assetDecimals = ALT_ASSET_DECIMALS[assetIndex];
        uint256 minAmount = 1;
        uint256 maxAmount = 100_000 * (10 ** assetDecimals);
        
        amount = bound(amount, minAmount, maxAmount);
        
        // Calculate expected shares based on current rate to set realistic minShares
        uint256 rate = accountantHandler.accountantRP().getRate();
        uint256 amountIn18Dec = assetDecimals < 18 
            ? amount * (10 ** (18 - assetDecimals))
            : amount / (10 ** (assetDecimals - 18));
        uint256 expectedShares = (amountIn18Dec * 1e18) / rate;
        // Bound minShares to 0-95% of expected to allow some slippage margin
        minShares = bound(minShares, 0, (expectedShares * 95) / 100);
        
        ERC20 altAsset = alternativeAssets[assetIndex];
        
        vm.startPrank(actor);
        altAsset.approve(address(vaultRP), amount);
        
        uint256 shares = tellerMAS.deposit(altAsset, amount, minShares, address(0));
        if (shares > 0) {
            depositCalls++;
            lastDepositAssets = amount;
            lastDepositShares = shares;
        }
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Withdraw alternative asset from TellerWithMultiAssetSupport
     */
    function withdrawAltMAS(uint256 assetIndex, uint256 actorSeed, uint256 shareAmount, uint256 minAssets, uint256 timeDelta) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.withdraw.selector, actor);
        
        assetIndex = bound(assetIndex, 0, NUM_ALT_ASSETS - 1);
        
        uint256 actorShares = vaultRP.balanceOf(actor);
        if (actorShares == 0) {
            _afterCall();
            return;
        }
        
        shareAmount = bound(shareAmount, 1, actorShares);
        
        uint8 assetDecimals = ALT_ASSET_DECIMALS[assetIndex];
        uint256 shareAmountInAssetDecimals = assetDecimals < 18
            ? shareAmount / (10 ** (18 - assetDecimals))
            : shareAmount * (10 ** (assetDecimals - 18));
        
        uint256 maxMinAssets = shareAmountInAssetDecimals > 0 ? shareAmountInAssetDecimals : 1;
        minAssets = bound(minAssets, 0, maxMinAssets);
        
        timeDelta = bound(timeDelta, 0, 7 days);
        
        vm.warp(block.timestamp + timeDelta);
        if (address(accountantHandler) != address(0)) accountantHandler.syncVestedAssets();
        
        ERC20 altAsset = alternativeAssets[assetIndex];
        
        vm.startPrank(actor);
        uint256 assets = tellerMAS.withdraw(altAsset, shareAmount, minAssets, actor);
        withdrawCalls++;
        lastWithdrawShares = shareAmount;
        lastWithdrawAssets = assets;
        vm.stopPrank();

        _afterCall();
    }
    
    // ============================================
    // YIELD STREAMING TELLER HANDLERS
    // ============================================
    
    /**
     * @notice Deposit into TellerWithYieldStreaming
     */
    function depositYS(uint256 actorSeed, uint256 amount, uint256 minShares) external {
        address actor = _getRandomActor(actorSeed);
        _beforeCall(TellerWithMultiAssetSupport.deposit.selector, actor);
        
        amount = bound(amount, 1, 100_000e18);
        
        // Calculate expected shares based on current rate to set realistic minShares
        uint256 rate = accountantHandler.accountantYS().getRate();
        uint256 expectedShares = (amount * 1e18) / rate;
        // Bound minShares to 0-95% of expected to allow some slippage margin
        minShares = bound(minShares, 0, (expectedShares * 95) / 100);
        
        // Track if vault was empty before deposit (will trigger setFirstDepositTimestamp)
        bool vaultWasEmpty = vaultYS.totalSupply() == 0;
        
        // Capture YS state in AccountantHandler - deposits realize yield via _updateExchangeRate()
        if (address(accountantHandler) != address(0)) {
            accountantHandler.beginYSOperation(TellerWithMultiAssetSupport.deposit.selector);
        }
        
        vm.startPrank(actor);
        baseAsset.approve(address(vaultYS), amount);
        
        bool succeeded = false;
        uint256 shares = tellerYS.deposit(baseAsset, amount, minShares, address(0));
        if (shares > 0) {
            depositCalls++;
            lastDepositAssets = amount;
            lastDepositShares = shares;
            succeeded = true;
        }
        vm.stopPrank();
        
        // Fix stale vesting state if deposit to empty vault triggered setFirstDepositTimestamp bug
        if (vaultWasEmpty && succeeded && address(accountantHandler) != address(0)) {
            accountantHandler.fixVestingStateAfterFirstDeposit();
        }
        
        // Capture post-state in AccountantHandler
        if (address(accountantHandler) != address(0)) {
            accountantHandler.endYSOperation(succeeded);
        }
        
        _afterCall();
    }
    
    /**
     * @notice Withdraw from TellerWithYieldStreaming
     */
    function withdrawYS(uint256 actorSeed, uint256 shareAmount, uint256 minAssets, uint256 timeDelta) external {
        // Find an actor with shares
        address actor = _getActorWithSharesYS(actorSeed);
        if (actor == address(0)) {
            _afterCall();
            return;
        }
        
        _beforeCall(TellerWithMultiAssetSupport.withdraw.selector, actor);
        
        uint256 actorShares = vaultYS.balanceOf(actor);
        shareAmount = bound(shareAmount, 1, actorShares);
        minAssets = bound(minAssets, 0, shareAmount);
        timeDelta = bound(timeDelta, 0, 7 days);
        
        vm.warp(block.timestamp + timeDelta);
        if (address(accountantHandler) != address(0)) accountantHandler.syncVestedAssets();
        
        // Capture YS state in AccountantHandler - withdrawals realize yield via getRateInQuoteSafe -> _updateExchangeRate()
        if (address(accountantHandler) != address(0)) {
            accountantHandler.beginYSOperation(TellerWithMultiAssetSupport.withdraw.selector);
        }
        
        vm.startPrank(actor);
        uint256 assets = tellerYS.withdraw(baseAsset, shareAmount, minAssets, actor);
        withdrawCalls++;
        lastWithdrawShares = shareAmount;
        lastWithdrawAssets = assets;
        vm.stopPrank();
        
        // Capture post-state in AccountantHandler
        if (address(accountantHandler) != address(0)) {
            accountantHandler.endYSOperation(true);
        }
        
        _afterCall();
    }
    
    /**
     * @notice Bulk deposit via solver for YS teller
     * @dev Solver deposits assets, solver receives shares (so it can later bulkWithdraw)
     */
    function bulkDepositYS(uint256 amount, uint256 minShares) external {
        _beforeCall(TellerWithMultiAssetSupport.bulkDeposit.selector, solver);
        
        amount = bound(amount, 1, 100_000e18);
        
        // Calculate expected shares based on current rate to set realistic minShares
        uint256 rate = accountantHandler.accountantYS().getRate();
        uint256 expectedShares = (amount * 1e18) / rate;
        // Bound minShares to 0-95% of expected to allow some slippage margin
        minShares = bound(minShares, 0, (expectedShares * 95) / 100);
        
        // Track if vault was empty before deposit (will trigger setFirstDepositTimestamp)
        bool vaultWasEmpty = vaultYS.totalSupply() == 0;
        
        // Capture YS state in AccountantHandler - deposits realize yield via _updateExchangeRate()
        if (address(accountantHandler) != address(0)) {
            accountantHandler.beginYSOperation(TellerWithMultiAssetSupport.bulkDeposit.selector);
        }
        
        vm.startPrank(solver);
        baseAsset.approve(address(vaultYS), amount);
        
        bool succeeded = false;
        // Solver deposits and receives shares itself (can later bulkWithdraw)
        uint256 shares = tellerYS.bulkDeposit(baseAsset, amount, minShares, solver);
        if (shares > 0) {
            bulkDepositCalls++;
            lastDepositAssets = amount;
            lastDepositShares = shares;
            succeeded = true;
        }
        vm.stopPrank();
        
        // Fix stale vesting state if deposit to empty vault triggered setFirstDepositTimestamp bug
        if (vaultWasEmpty && succeeded && address(accountantHandler) != address(0)) {
            accountantHandler.fixVestingStateAfterFirstDeposit();
        }
        
        // Capture post-state in AccountantHandler
        if (address(accountantHandler) != address(0)) {
            accountantHandler.endYSOperation(succeeded);
        }
        
        _afterCall();
    }
    
    /**
     * @notice Bulk withdraw via solver for YS teller
     * @dev Solver burns its own shares, sends assets to a random actor
     */
    function bulkWithdrawYS(uint256 shareAmount, uint256 minAssets, uint256 actorSeed) external {
        _beforeCall(TellerWithMultiAssetSupport.bulkWithdraw.selector, solver);
        
        // Solver needs shares to withdraw (from previous bulkDepositYS calls)
        uint256 solverShares = vaultYS.balanceOf(solver);
        if (solverShares == 0) {
            _afterCall();
            return;
        }
        
        // Solver burns shares, assets go to a random actor
        address recipient = _getRandomActor(actorSeed);
        shareAmount = bound(shareAmount, 1, solverShares);
        minAssets = bound(minAssets, 0, shareAmount);
        
        // Capture YS state in AccountantHandler - withdrawals realize yield via getRateInQuoteSafe -> _updateExchangeRate()
        if (address(accountantHandler) != address(0)) {
            accountantHandler.beginYSOperation(TellerWithMultiAssetSupport.bulkWithdraw.selector);
        }
        
        vm.startPrank(solver);
        uint256 assets = tellerYS.bulkWithdraw(baseAsset, shareAmount, minAssets, recipient);
        bulkWithdrawCalls++;
        lastWithdrawShares = shareAmount;
        lastWithdrawAssets = assets;
        vm.stopPrank();
        
        // Capture post-state in AccountantHandler
        if (address(accountantHandler) != address(0)) {
            accountantHandler.endYSOperation(true);
        }
        
        _afterCall();
    }
    
    /**
     * @notice Pause TellerWithYieldStreaming
     */
    function pauseYS() external {
        _beforeCall(TellerWithMultiAssetSupport.pause.selector, owner);
        
        vm.prank(owner);
        try tellerYS.pause() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Unpause TellerWithYieldStreaming
     */
    function unpauseYS() external {
        _beforeCall(TellerWithMultiAssetSupport.unpause.selector, owner);
        
        vm.prank(owner);
        try tellerYS.unpause() {} catch {}
        
        _afterCall();
    }
    
    // ============================================
    // DENIED USER OPERATIONS (for testing deny list invariants)
    // ============================================
    
    /**
     * @notice Attempt deposit with denied user
     */
    function depositAsDeniedUser(uint256 amount) external {
        _beforeCall(TellerWithMultiAssetSupport.deposit.selector, deniedUser);
        
        amount = bound(amount, 1e6, 100_000e18);
        
        vm.startPrank(deniedUser);
        baseAsset.approve(address(vaultRP), amount);
        tellerMAS.deposit(baseAsset, amount, 0, address(0));
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Attempt transfer from denied user (using RP vault where deny is configured)
     */
    function transferFromDeniedUser(uint256 amount, uint256 actorSeed) external {
        address recipient = _getRandomActor(actorSeed);
        _beforeCall(BoringVault.transfer.selector, deniedUser);
        
        uint256 deniedShares = vaultRP.balanceOf(deniedUser);
        if (deniedShares == 0) {
            _afterCall();
            return;
        }
        
        amount = bound(amount, 1, deniedShares);
        
        vm.prank(deniedUser);
        vaultRP.transfer(recipient, amount);
        
        _afterCall();
    }
    
    // ============================================
    // STRUCT GETTERS (needed because public structs return tuples)
    // ============================================
    
    function getPreMAS() external view returns (TellerState memory) {
        return preMAS;
    }
    
    function getPostMAS() external view returns (TellerState memory) {
        return postMAS;
    }
    
    function getPreYS() external view returns (TellerState memory) {
        return preYS;
    }
    
    function getPostYS() external view returns (TellerState memory) {
        return postYS;
    }
    
    function getPreUserState(address user) external view returns (UserState memory) {
        return preUserState[user];
    }
    
    function getPostUserState(address user) external view returns (UserState memory) {
        return postUserState[user];
    }
    
}

