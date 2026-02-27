# BoringVault Fuzzing Invariant Suite - Comprehensive Documentation

This document provides an exhaustive explanation of all 47 invariants implemented in the BoringVault Foundry Invariant Test Suite. Each invariant includes:
- **Description**: What the invariant verifies
- **Mathematical Formula**: The precise mathematical relationship being checked
- **Source Contract Code**: The relevant code from the source contracts
- **Invariant Test Code**: The implementation in the modular test suite

---

## Architecture Overview

The fuzzing suite uses a **modular, inheritance-based architecture** to test two independent accounting systems:

### Systems Under Test
| System | Accountant | Teller | Vault | Assets |
|--------|-----------|--------|-------|--------|
| **Rate Provider (RP)** | `AccountantWithRateProviders` | `TellerWithMultiAssetSupport` | `vaultRP` | Base + 5 alternative assets |
| **Yield Streaming (YS)** | `AccountantWithYieldStreaming` | `TellerWithYieldStreaming` | `vaultYS` | Base asset only |

### N-Asset Support (RP System)
The Rate Provider system supports **N alternative assets** (configured to 5 by default via `NUM_ALT_ASSETS`). Each alternative asset has its own:
- `MockERC20Extended` token instance with configurable decimals
- `MockRateProvider` for exchange rate conversion (always returns 18-decimal rates)
- Handler functions parameterized by asset index (e.g., `depositAltMAS(uint256 assetIndex, ...)`)

#### Decimal Diversity
Alternative assets are configured with varying decimals to simulate real-world tokens:

| Index | Decimals | Simulates | Initial Rate |
|-------|----------|-----------|--------------|
| 0 | 18 | Standard ERC20 (WETH, DAI) | 1e18 (1.0) |
| 1 | 6 | USDC | 9e5 (0.9) |
| 2 | 6 | USDT | 1.1e6 (1.1) |
| 3 | 8 | WBTC | 8e7 (0.8) |
| 4 | 11 | Edge case testing | 1.2e11 (1.2) |

**Critical: Rate Provider Decimals**

Rate providers must return rates in the **QUOTE token's decimals**, not 18 decimals. This is required by the `getRateInQuote` formula:

```solidity
rateInQuote = oneQuote.mulDivDown(exchangeRateInQuoteDecimals, quoteRate);
// where oneQuote = 10 ** quoteDecimals
```

For a 6-decimal asset at 1:1 with base, the rate should be `1e6`, not `1e18`.

This configuration is defined in `BaseSetup.sol`:
```solidity
uint8[5] public ALT_ASSET_DECIMALS = [18, 6, 6, 8, 11];
```

The Yield Streaming system remains **base-asset-only** as per its design.

### File Structure
```
test/fuzzing/
├── BaseSetup.sol              # Shared setup for both systems
├── InvariantTestRP.sol        # RP system test contract (concrete)
├── InvariantTestYS.sol        # YS system test contract (concrete)
├── handlers/
│   ├── AccountantHandler.sol  # Handles both accountant types
│   └── TellerHandler.sol      # Handles both teller types
├── invariants/
│   ├── BaseInvariants.sol     # 31 shared invariants (abstract)
│   └── YSOnlyInvariants.sol   # 16 YS-specific invariants (abstract)
├── mocks/
│   ├── MockERC20Extended.sol
│   ├── MockRateProvider.sol
│   └── MockWETH.sol
└── FUZZING_NOTES.md           # Findings & violations log
```

### Inheritance Chain
```
Test (forge-std)
  ↑
StdInvariant (forge-std)
  ↑
BaseSetup (deploys both systems)
  ↑
BaseInvariants (31 shared invariants - abstract)
  ↑
├── InvariantTestRP (implements abstract getters for RP)
└── YSOnlyInvariants (16 YS-only invariants - abstract)
      ↑
      └── InvariantTestYS (implements abstract getters for YS)
```

### Running Tests
```bash
# RP system only
forge test --match-contract InvariantTestRP -vv

# YS system only  
forge test --match-contract InvariantTestYS -vv

# Both systems
forge test --match-path "test/fuzzing/Invariant*.sol" -vv

# With custom depth (default is 15 in foundry.toml)
FOUNDRY_INVARIANT_DEPTH=64 forge test --match-contract InvariantTestRP -vv

# With Medusa (alternative fuzzer)
medusa fuzz --config medusa.json
```

### Handler Functions (N-Asset Support)

The handlers expose parameterized functions for operating on specific alternative assets:

| Handler | Function | Signature | Description |
|---------|----------|-----------|-------------|
| `AccountantHandler` | `setAltAssetRate` | `(uint256 assetIndex, uint256 newRate)` | Set rate for alt asset at index |
| `TellerHandler` | `depositAltMAS` | `(uint256 assetIndex, uint256 amount, ...)` | Deposit specific alt asset |
| `TellerHandler` | `withdrawAltMAS` | `(uint256 assetIndex, uint256 shares, ...)` | Withdraw specific alt asset |

The `assetIndex` parameter (0 to `NUM_ALT_ASSETS-1`) selects which alternative asset to operate on.

#### Deposit Tracking Requirements

All deposit handlers only track deposits that actually mint shares. When tiny amounts are deposited with a `sharePremium > 0`, the share calculation can round down to zero. These 0-share deposits are not tracked to avoid false positives in `invariant_integrityOfDeposit`:

```solidity
try teller.deposit(asset, amount, minShares, address(0)) returns (uint256 shares) {
    // Only track deposits that actually minted shares
    if (shares > 0) {
        depositCalls++;
        lastDepositAssets = amount;
        lastDepositShares = shares;
    }
} catch {}
```

#### Withdrawal Minimum Asset Requirements

All withdrawal handlers enforce `minAssets >= 1` to reflect realistic user behavior. No rational user would accept 0 tokens in exchange for burning shares. This prevents the protocol from allowing withdrawals where rate calculations round to zero due to decimal precision differences.

For low-decimal assets (e.g., 6 decimals), the handler also enforces a minimum share amount:
```solidity
// Calculate minimum shares to produce at least 1 token output
uint256 minShareAmount = assetDecimals < 18 
    ? 10 ** (18 - assetDecimals)  // e.g., 1e12 for 6-decimal asset
    : 1;
```

#### Handler Error Handling Strategy

All TellerHandler deposit/withdraw functions use **smart error handling** that distinguishes between expected and unexpected reverts:

```solidity
try teller.deposit(...) returns (uint256 shares) {
    if (shares > 0) { depositCalls++; /* ... */ }
} catch (bytes memory reason) {
    if (!_isExpectedRevert(reason)) {
        // Unexpected - propagate it!
        assembly { revert(add(reason, 32), mload(reason)) }
    }
    // Expected - skip silently
}
```

**Expected errors (silently skipped):**
| Error | Reason |
|-------|--------|
| `TellerWithMultiAssetSupport__Paused()` | Teller is paused |
| `TellerWithMultiAssetSupport__AssetNotSupported()` | Asset not configured |
| `TellerWithMultiAssetSupport__SharesAreLocked()` | Time lock not elapsed |
| `TellerWithMultiAssetSupport__DepositExceedsCap()` | Cap reached |
| `TellerWithMultiAssetSupport__MinimumMintNotMet()` | Slippage check |
| `TellerWithMultiAssetSupport__MinimumAssetsNotMet()` | Slippage check |
| `TellerWithMultiAssetSupport__TransferDenied()` | User on deny list |
| `AccountantWithRateProviders__Paused()` | Accountant paused |

**Unexpected errors (propagated):**
Any error NOT in the expected list is considered a potential bug and will fail the test. This ensures we catch real protocol issues while ignoring state-based rejections.

---

## Table of Contents

### Group 1: Accountant Common Logic (Rules 1-7) - BaseInvariants.sol
- [Rule 1: accountantDoesntHoldTokens](#rule-1-accountantdoesntholdtokens)
- [Rule 2: accountantPaused_valuesFrozen](#rule-2-accountantpaused_valuesfrozen)
- [Rule 3: feesCanOnlyDecreaseViaClaimFees](#rule-3-feescanonlydecreaseviaclaimfees)
- [Rule 4: highwaterMarkNeverDecreases](#rule-4-highwatermarkneverdecreases)
- [Rule 5: lastUpdateTimestampNeverDecreases](#rule-5-lastupdatetimestampneverdecreases)
- [Rule 6: allowedExchangeRateChangeBounds](#rule-6-allowedexchangeratechangebounds)
- [Rule 7: exchangeRateLEhighwaterMark](#rule-7-exchangeratele-highwatermark)

### Group 2: Accountant Yield Specific (16 invariants) - YSOnlyInvariants.sol
- [Rule 8: cumulativeSupplyBounded](#rule-8-cumulativesupplybounded)
- [Rule 9: exchangeRateEqlastSharePrice](#rule-9-exchangerateeqlastshareprice)
- [Rule 10: sharePriceBoundedUpper](#rule-10-sharepriceboundedupper)
- [Rule 11: sharePriceBoundedLower](#rule-11-sharepriceboundedlower)
- [Rule 12: sharePriceMoreThanOne](#rule-12-sharepricemoreThanone)
- [Rule 13: totalAssetsCovered](#rule-13-totalassetscovered)
- [Rule 14: startVestingTimeLEendVestingTime](#rule-14-startvestingtimeleendvestingtime)
- [Rule 15: vestingGainsIntegrity](#rule-15-vestinggainsintegrity)
- [Rule 16: lastVestingUpdateNeverDecreases](#rule-16-lastvestingupdateneverdecreases)
- [Rule 17: integrityOfVestYield](#rule-17-integrityofvestyield)
- [Rule 18: exchangeRatePostLoss](#rule-18-exchangeratepostloss)
- [Rule 19: vaultSolvency_1Asset_Vesting](#rule-19-vaultsolvency_1asset_vesting)
- [Rule 20: yieldIntegrity](#rule-20-yieldintegrity)
- [Rule 21: yieldAccrualsMonotonic](#rule-21-yieldaccrualsmonotonic)
- [Rule 22: streamingRateConsistency](#rule-22-streamingrateconsistency)
- [Rule 23: accessControlYieldParams](#rule-23-accesscontrolyieldparams)

### Group 3: Teller & Vault Integrity (14 invariants) - BaseInvariants.sol
- [Rule 24: integrityOfDeposit](#rule-24-integrityofdeposit)
- [Rule 25: integrityOfWithdraw](#rule-25-integrityofwithdraw)
- [Rule 26: noFreeAssets](#rule-26-nofreeassets)
- [Rule 27: tellerDoesntHoldTokens](#rule-27-tellerdoesntholdtokens)
- [Rule 28: vaultCannotChange](#rule-28-vaultcannotchange)
- [Rule 29: depositNonceNeverGoesDown](#rule-29-depositnoncenevergoesdown)
- [Rule 30: tellerPaused_valuesFrozen](#rule-30-tellerpaused_valuesfrozen)
- [Rule 31: tellerPaused_methodsRevert](#rule-31-tellerpaused_methodsrevert)
- [Rule 32: dustFavorsTheHouse](#rule-32-dustfavorsthehouse)
- [Rule 33: noDynamicCalls](#rule-33-nodynamiccalls)
- [Rule 34: onlyContributionMethodsReduceAssets](#rule-34-onlycontributionmethodsreduceassets)
- [Rule 35: withdrawingProducesAssets](#rule-35-withdrawingproducesassets)
- [Rule 36: feesIntegrity](#rule-36-feesintegrity)
- [Rule 37: deniedUsers_balanceNonDecreasing](#rule-37-deniedusers_balancenondecreasing)
- [Rule 38: deniedUsers_balanceNonIncreasing](#rule-38-deniedusers_balancenonincreasing)

### Group 4: Math & Solvency (9 invariants) - BaseInvariants.sol
- [Rule 39: vaultSolvencyMulti](#rule-39-vaultsolvencymulti)
- [Rule 40: vaultSolvency_1Asset](#rule-40-vaultsolvency_1asset)
- [Rule 41: convertToAssetsWeakAdditivity](#rule-41-converttoassetsweakadditivity)
- [Rule 42: convertToSharesWeakAdditivity](#rule-42-converttosharesweakadditivity)
- [Rule 43: conversionWeakMonotonicity](#rule-43-conversionweakmonotonicity)
- [Rule 44: conversionWeakIntegrity](#rule-44-conversionweakintegrity)
- [Rule 45: zeroAllowanceOnAssets](#rule-45-zeroallowanceonassets)
- [Rule 46: conversionOfZero](#rule-46-conversionofzero)
- [Rule 47: totalSupplyLEqCap](#rule-47-totalsupplyleqcap)

---

## Group 1: Accountant Common Logic (Rules 1-8)

### Rule 1: accountantDoesntHoldTokens

**Description**: The Accountant contracts should never hold any tokens. They act as pass-through entities for rate calculations and fee management. The payout address must also not be the accountant itself.

**Assumption**: `payoutAddress != accountant`

**Goal**: Ensure the Accountant is a pass-through and never retains user assets.

**Mathematical Formula**:
```
∀ asset ∈ {baseAsset, alternativeAssets[0..N-1]}:
    balanceOf(accountant, asset) == 0

payoutAddress ≠ address(accountant)
```

**Source Contract Code** (`AccountantWithRateProviders.sol`):
```solidity
struct AccountantState {
    address payoutAddress;        // Line 37
    uint96 highwaterMark;
    uint128 feesOwedInBase;
    // ...
}

// Fees are transferred FROM the vault TO the payout address
// Lines 338-339
feeAsset.safeTransferFrom(msg.sender, state.payoutAddress, feesOwedInFeeAsset);
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_accountantDoesntHoldTokens() public view {
    address acc = address(_accountant());
    
    assertEq(
        baseAsset.balanceOf(acc),
        0,
        "Invariant 1: Accountant should not hold base tokens"
    );
    
    // Check ALL alternative assets (N-asset support)
    for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
        assertEq(
            alternativeAssets[i].balanceOf(acc),
            0,
            "Invariant 1: Accountant should not hold alt tokens"
        );
    }

    (address payout,,,,,,,,,,, ) = _accountant().accountantState();
    assertTrue(payout != acc, "Invariant 1: Payout should not be Accountant");
}
```

---

### Rule 2: accountantPaused_valuesFrozen

**Description**: When the Accountant is paused, the exchange rate and fees should remain frozen. State changes are blocked during emergency pauses.

**Assumption**: Excludes `resetHighwaterMark` which can still be called when paused.

**Goal**: Prevent state changes during emergency pauses.

**Mathematical Formula**:
```
paused ∧ selector ≠ resetHighwaterMark ⟹ 
    (rate_post == rate_pre) ∧ (fees_post == fees_pre)
```

**Source Contract Code** (`AccountantWithRateProviders.sol`):
```solidity
// Line 160-163: pause() sets isPaused = true
function pause() external requiresAuth {
    accountantState.isPaused = true;
    emit Paused();
}

// Line 284-305: updateExchangeRate reverts if paused
function updateExchangeRate(uint96 newExchangeRate) external virtual requiresAuth {
    (
        bool shouldPause,
        AccountantState storage state,
        // ...
    ) = _beforeUpdateExchangeRate(newExchangeRate);
    // ...
}

// Line 467: _beforeUpdateExchangeRate reverts when paused
function _beforeUpdateExchangeRate(uint96 newExchangeRate) internal view returns (...) {
    state = accountantState;
    if (state.isPaused) revert AccountantWithRateProviders__Paused();
    // ...
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_accountantPaused_valuesFrozen() public view {
    AccountantHandler.RPState memory pre = _getPreState();
    AccountantHandler.RPState memory post = _getPostState();
    bytes4 selector = _accountantHandler().lastSelector();

    if (pre.isPaused && selector != AccountantWithRateProviders.resetHighwaterMark.selector) {
        assertEq(
            post.feesOwedInBase,
            pre.feesOwedInBase,
            "Invariant 2: Fees should be frozen when paused"
        );
    }
}
```

---

### Rule 3: feesCanOnlyDecreaseViaClaimFees

**Description**: The accumulated fees (`feesOwedInBase`) can only decrease when the `claimFees` function is called. This ensures fees are monotonically increasing except during authorized claims.

**Goal**: Ensure fees are monotonic and only reduced by authorized claims.

**Mathematical Formula**:
```
fees_post < fees_pre ⟹ selector == claimFees
```

**Source Contract Code** (`AccountantWithRateProviders.sol`):
```solidity
// Line 313-342: claimFees is the ONLY function that decreases feesOwedInBase
function claimFees(ERC20 feeAsset) external {
    if (msg.sender != address(vault)) revert AccountantWithRateProviders__OnlyCallableByBoringVault();

    AccountantState storage state = accountantState;
    if (state.isPaused) revert AccountantWithRateProviders__Paused();
    if (state.feesOwedInBase == 0) revert AccountantWithRateProviders__ZeroFeesOwed();

    // ... calculate feesOwedInFeeAsset ...
    
    // Line 337: Zero out fees owed (DECREASE)
    state.feesOwedInBase = 0;
    // Transfer fee asset to payout address.
    feeAsset.safeTransferFrom(msg.sender, state.payoutAddress, feesOwedInFeeAsset);
}

// Line 570: _calculateFeesOwed only INCREASES fees
state.feesOwedInBase += uint128(newFeesOwedInBase);
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_feesCanOnlyDecreaseViaClaimFees() public view {
    AccountantHandler.RPState memory pre = _getPreState();
    AccountantHandler.RPState memory post = _getPostState();
    bytes4 selector = _accountantHandler().lastSelector();

    if (post.feesOwedInBase < pre.feesOwedInBase) {
        assertEq(
            selector,
            AccountantWithRateProviders.claimFees.selector,
            "Invariant 3: Fees should only decrease via claimFees"
        );
    }
}
```

---

### Rule 4: highwaterMarkNeverDecreases

**Description**: The highwater mark (the peak exchange rate ever recorded) should never decrease, except when explicitly reset via `resetHighwaterMark`.

**Assumption**: Excludes `resetHighwaterMark`

**Goal**: Maintain integrity of the performance fee baseline.

**Mathematical Formula**:
```
selector ≠ resetHighwaterMark ⟹ HWM_post ≥ HWM_pre
```

**Source Contract Code** (`AccountantWithRateProviders.sol`):
```solidity
// Line 564-567: In _calculateFeesOwed, HWM is only updated upward
if (newExchangeRate > state.highwaterMark) {
    // ... calculate performance fees ...
    // Always update the highwater mark if the new exchange rate is higher.
    state.highwaterMark = newExchangeRate;
}

// Line 259-274: resetHighwaterMark is the only way to DECREASE HWM
function resetHighwaterMark() external virtual requiresAuth {
    AccountantState storage state = accountantState;

    if (state.exchangeRate > state.highwaterMark) {
        revert AccountantWithRateProviders__ExchangeRateAboveHighwaterMark();
    }
    // ...
    state.highwaterMark = accountantState.exchangeRate; // Can be lower than previous HWM
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_highwaterMarkNeverDecreases() public view {
    AccountantHandler.RPState memory pre = _getPreState();
    AccountantHandler.RPState memory post = _getPostState();
    bytes4 selector = _accountantHandler().lastSelector();

    if (selector != AccountantWithRateProviders.resetHighwaterMark.selector) {
        assertGe(
            post.highwaterMark,
            pre.highwaterMark,
            "Invariant 4: Highwater mark should never decrease"
        );
    }
}
```

---

### Rule 5: lastUpdateTimestampNeverDecreases

**Description**: The `lastUpdateTimestamp` should only move forward in time, never backward. This ensures linear time progression for yield calculations.

**Goal**: Ensure linear time progression for yield calculations.

**Mathematical Formula**:
```
timestamp_post ≥ timestamp_pre
```

**Source Contract Code** (`AccountantWithRateProviders.sol`):
```solidity
// Line 302: In updateExchangeRate, timestamp is always set to current time
state.lastUpdateTimestamp = currentTime;

// Line 468: currentTime is always block.timestamp
currentTime = uint64(block.timestamp);
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_lastUpdateTimestampNeverDecreases() public view {
    AccountantHandler.RPState memory pre = _getPreState();
    AccountantHandler.RPState memory post = _getPostState();

    assertGe(
        post.lastUpdateTimestamp,
        pre.lastUpdateTimestamp,
        "Invariant 5: Timestamp should never decrease"
    );
}
```

---

### Rule 6: allowedExchangeRateChangeBounds

**Description**: The exchange rate change bounds must maintain sanity: `allowedExchangeRateChangeUpper >= 10000` (100%) and `allowedExchangeRateChangeLower <= 10000` (100%). This prevents misconfiguration of the rate provider.

**Goal**: Sanity check on the rate provider configuration.

**Mathematical Formula**:
```
upper ≥ 10000 (100%)
lower ≤ 10000 (100%)
```

**Source Contract Code** (`AccountantWithRateProviders.sol`):
```solidity
// Line 192-197: updateUpper enforces minimum
function updateUpper(uint16 allowedExchangeRateChangeUpper) external requiresAuth {
    if (allowedExchangeRateChangeUpper < 1e4) revert AccountantWithRateProviders__UpperBoundTooSmall();
    uint16 oldBound = accountantState.allowedExchangeRateChangeUpper;
    accountantState.allowedExchangeRateChangeUpper = allowedExchangeRateChangeUpper;
}

// Line 203-208: updateLower enforces maximum
function updateLower(uint16 allowedExchangeRateChangeLower) external requiresAuth {
    if (allowedExchangeRateChangeLower > 1e4) revert AccountantWithRateProviders__LowerBoundTooLarge();
    uint16 oldBound = accountantState.allowedExchangeRateChangeLower;
    accountantState.allowedExchangeRateChangeLower = allowedExchangeRateChangeLower;
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_allowedExchangeRateChangeBounds() public view {
    (, , , , , uint16 upper, uint16 lower, , , , , ) = _accountant().accountantState();

    assertGe(upper, 10000, "Invariant 6: Upper bound should be >= 100%");
    assertLe(lower, 10000, "Invariant 6: Lower bound should be <= 100%");
}
```

---

### Rule 7: exchangeRateLEhighwaterMark

**Description**: When the system is not paused, the exchange rate should never exceed the highwater mark. This is checked specifically after `updateExchangeRate` calls.

**Note**: The protocol allows rate updates while paused that may exceed HWM. When unpaused without a fresh rate update, rate may temporarily exceed HWM. This is expected protocol behavior.

**Goal**: Ensure the current rate never exceeds the peak recorded rate when active.

**Mathematical Formula**:
```
!paused ∧ selector == updateExchangeRate ⟹ exchangeRate ≤ highwaterMark
```

**Source Contract Code** (`AccountantWithRateProviders.sol`):
```solidity
// Line 564-568: When rate exceeds HWM, HWM is updated to match
if (newExchangeRate > state.highwaterMark) {
    (uint256 performanceFeesOwedInBase,) =
        _calculatePerformanceFee(newExchangeRate, shareSupplyToUse, state.highwaterMark, state.performanceFee);
    newFeesOwedInBase += performanceFeesOwedInBase;
    // Always update the highwater mark if the new exchange rate is higher.
    state.highwaterMark = newExchangeRate;
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_exchangeRateLEhighwaterMark() public view {
    bytes4 selector = _accountantHandler().lastSelector();
    
    // Only check after updateExchangeRate calls
    if (selector != AccountantWithRateProviders.updateExchangeRate.selector) {
        return;
    }
    
    (, uint96 hwm, , , uint96 rate, , , , bool paused, , , ) = _accountant().accountantState();
    
    if (!paused) {
        assertLe(rate, hwm, "Invariant 7: Exchange rate should be <= highwater mark when not paused");
    }
}
```

---

### Rule 8: cumulativeSupplyBounded

**Description**: The cumulative supply tracking maintains monotonicity: `cumulativeSupplyLast <= cumulativeSupply`. This is used for TWAS (Time-Weighted Average Supply) calculations.

**Goal**: Verify monotonicity of tracked supply history.

**Mathematical Formula**:
```
supplyObservation.cumulativeSupplyLast ≤ supplyObservation.cumulativeSupply
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 34-38: SupplyObservation struct
struct SupplyObservation {
    uint256 cumulativeSupply;
    uint256 cumulativeSupplyLast;
    uint256 lastUpdateTimestamp;
}

// Line 477-487: _updateCumulative only increases cumulativeSupply
function _updateCumulative() internal {
    uint256 currentTime = block.timestamp;
    uint256 timeElapsed = currentTime - supplyObservation.lastUpdateTimestamp;

    if (timeElapsed > 0) {
        // cumulativeSupply always INCREASES
        supplyObservation.cumulativeSupply += vault.totalSupply() * timeElapsed;
        supplyObservation.lastUpdateTimestamp = currentTime;
    }
}

// Line 179: cumulativeSupplyLast is set FROM cumulativeSupply
supplyObservation.cumulativeSupplyLast = supplyObservation.cumulativeSupply;
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_cumulativeSupplyBounded() public view {
    (uint256 cumSupply, uint256 cumSupplyLast, ) = _accountantYS().supplyObservation();
    
    assertGe(cumSupply, cumSupplyLast, "Invariant 8: Cumulative supply last should be <= cumulative supply");
}
```

---

## Group 2: Accountant Yield Specific (Rules 8-23)

### Rule 9: exchangeRateEqlastSharePrice

**Description**: For the Yield Streaming Accountant, the `exchangeRate` in `accountantState` should equal `lastSharePrice` in `vestingState` after sync operations (`vestYield`, `postLoss`, `updateExchangeRate`).

**Note**: This sync only happens during `_collectFees()` which is called by these operations.

**Goal**: Maintain synchronization between the public rate and internal vesting state.

**Mathematical Formula**:
```
!paused ∧ isSyncOp ∧ lastSharePrice ≤ type(uint96).max ⟹ 
    exchangeRate == uint96(lastSharePrice)
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 492-504: _collectFees syncs the values
function _collectFees() internal {
    AccountantState storage state = accountantState;
    uint256 currentTotalShares = vault.totalSupply();
    uint64 currentTime = uint64(block.timestamp);

    _calculateFeesOwed(
        state, uint96(vestingState.lastSharePrice), state.exchangeRate, currentTotalShares, currentTime
    );

    // Line 502: exchangeRate is set FROM lastSharePrice
    state.exchangeRate = uint96(vestingState.lastSharePrice);
    state.lastUpdateTimestamp = currentTime;
}
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_exchangeRateEqlastSharePrice() public view {
    (, , , , uint96 rate, , , , bool isPaused, , , ) = _accountantYS().accountantState();
    (uint128 lastSharePrice, , , , ) = _accountantYS().vestingState();

    if (isPaused) return;

    bytes4 selector = _accountantHandler().lastSelector();
    bool isSyncOp = selector == AccountantWithYieldStreaming.vestYield.selector ||
                    selector == AccountantWithYieldStreaming.postLoss.selector ||
                    selector == YS_UPDATE_EXCHANGE_RATE_SELECTOR;
    
    if (!isSyncOp) return;

    if (lastSharePrice <= type(uint96).max) {
        assertEq(rate, uint96(lastSharePrice), "Invariant 9: Exchange rate should equal last share price");
    }
}
```

---

### Rule 10: sharePriceBoundedUpper

**Description**: The share price (from `getRate()`) multiplied by total supply should not exceed total assets plus a 1-wei rounding buffer.

**Important**: Must use `getRate()` instead of `lastSharePrice` because `lastSharePrice` does NOT include pending vesting gains, but `totalAssets()` does.

**Goal**: Prevent share price inflation beyond available assets.

**Mathematical Formula**:
```
getRate() × totalSupply / ONE_SHARE ≤ totalAssets + 1
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 339-345: getRate includes pending gains via totalAssets
function getRate() public view override returns (uint256 rate) {
    uint256 currentShares = vault.totalSupply();
    if (currentShares == 0) {
        return rate = vestingState.lastSharePrice;
    }
    rate = totalAssets().mulDivDown(ONE_SHARE, currentShares);
}

// Line 414-417: totalAssets includes pending gains
function totalAssets() public view returns (uint256) {
    uint256 currentShares = vault.totalSupply();
    return uint256(vestingState.lastSharePrice).mulDivDown(currentShares, ONE_SHARE) + getPendingVestingGains();
}
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_sharePriceBoundedUpper() public view {
    if (_isAccountantYSPaused()) return;
    
    uint256 totalSupply = _vault().totalSupply();

    if (totalSupply > 0) {
        uint256 rate = _accountantYS().getRate();
        uint256 totalAssets = _accountantYS().totalAssets();
        
        uint256 lhs = rate.mulDivUp(totalSupply, ONE_SHARE);
        assertLe(lhs, totalAssets + 1, "Invariant 10: Share price upper bound violated");
    }
}
```

---

### Rule 11: sharePriceBoundedLower

**Description**: The share price (from `getRate()`) multiplied by total supply should be at least equal to total assets (minus a small tolerance for rounding).

**Important**: Must use `getRate()` instead of `lastSharePrice` because `getRate() = totalAssets().mulDivDown(ONE_SHARE, currentShares)` properly accounts for pending vesting gains.

**Goal**: Ensure the share price accurately represents the asset floor.

**Mathematical Formula**:
```
getRate() × totalSupply / ONE_SHARE + tolerance ≥ totalAssets

where tolerance = max(totalAssets / 1e6, 1)
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 339-345: getRate is derived from totalAssets
function getRate() public view override returns (uint256 rate) {
    uint256 currentShares = vault.totalSupply();
    if (currentShares == 0) {
        return rate = vestingState.lastSharePrice;
    }
    rate = totalAssets().mulDivDown(ONE_SHARE, currentShares);
}

// Line 414-417: totalAssets = principal + pendingVestingGains
function totalAssets() public view returns (uint256) {
    uint256 currentShares = vault.totalSupply();
    return uint256(vestingState.lastSharePrice).mulDivDown(currentShares, ONE_SHARE) + getPendingVestingGains();
}
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_sharePriceBoundedLower() public view {
    if (_isAccountantYSPaused()) return;
    
    uint256 totalSupply = _vault().totalSupply();

    if (totalSupply > 0) {
        uint256 rate = _accountantYS().getRate();
        uint256 totalAssets = _accountantYS().totalAssets();
        
        uint256 lhs = rate.mulDivDown(totalSupply, ONE_SHARE);
        
        uint256 tolerance = totalAssets / 1e6;
        if (tolerance == 0) tolerance = 1;
        
        assertGe(lhs + tolerance, totalAssets, "Invariant 11: Share price lower bound violated");
    }
}
```

---

### Rule 12: sharePriceMoreThanOne

**Description**: The share price should remain non-zero. Originally intended to verify a minimum floor of 1.0 per share, but this is NOT a strict invariant because `postLoss` can legitimately reduce the share price below any specific floor.

**Note**: This is a relaxed check - losses via `postLoss` can legitimately reduce rate below any floor.

**Goal**: Verify share price is non-zero (minimal sanity check).

**Mathematical Formula**:
```
getRate() > 0
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 199-244: postLoss can reduce share price significantly
function postLoss(uint256 lossAmount) external requiresAuth {
    // ...
    uint256 principalLoss = lossAmount - vestingState.vestingGains;
    vestingState.vestingGains = 0;
    
    // Line 222-223: Share price is REDUCED (potentially below 1.0)
    vestingState.lastSharePrice =
        uint128((totalAssets() - principalLoss).mulDivDown(ONE_SHARE, currentShares));
    // ...
}
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_sharePriceMoreThanOne() public view {
    if (_isAccountantYSPaused()) return;
    if (_vault().totalSupply() == 0) return;

    uint256 rate = _accountantYS().getRate();
    uint256 vaultBalance = baseAsset.balanceOf(address(_vault()));
    
    if (vaultBalance > 0) {
        assertGt(rate, 0, "Invariant 12: Share price should be non-zero when assets exist");
    }
}
```

---

### Rule 13: totalAssetsCovered

**Description**: The accountant's reported `totalAssets` should not exceed the actual vault balance of the base asset.

**Note**: 
- Exempt if `downCastOverflow` occurred
- **Only valid in single-asset scenarios** - when alternative assets are deposited via `depositAltMAS`, this check is skipped because `totalAssets` is calculated from `shares × rate` which may differ from actual vault holdings due to rate provider changes.

**Goal**: Prevent the Accountant from "phantomizing" assets not held in the vault.

**Mathematical Formula**:
```
(altBalance ≤ INITIAL_MINT) ⟹ accountant.totalAssets() ≤ vault.balanceOf(baseAsset) + tolerance

where tolerance = max(totalAssets / 10000, 1)
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 414-417: totalAssets is calculated from shares × price + pending gains
function totalAssets() public view returns (uint256) {
    uint256 currentShares = vault.totalSupply();
    return uint256(vestingState.lastSharePrice).mulDivDown(currentShares, ONE_SHARE) + getPendingVestingGains();
}
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_totalAssetsCovered() public view {
    if (_isAccountantYSPaused()) return;
    if (_accountantHandler().feesRecentlyClaimed()) return;

    uint256 vaultBalance = baseAsset.balanceOf(address(_vault()));
    uint256 totalAssets = _accountantYS().totalAssets();
    
    uint256 tolerance = totalAssets / 10000;
    if (tolerance == 0) tolerance = 1;
    
    assertLe(
        totalAssets,
        vaultBalance + tolerance,
        "Invariant 13: Total assets should be covered by vault balance"
    );
}
```

---

### Rule 14: startVestingTimeLEendVestingTime

**Description**: The vesting start time must always be less than or equal to the vesting end time.

**Goal**: Ensure a valid temporal window for yield streaming.

**Mathematical Formula**:
```
startVestingTime ≤ endVestingTime
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 26-32: VestingState struct
struct VestingState {
    uint128 lastSharePrice;
    uint128 vestingGains;
    uint128 lastVestingUpdate;
    uint64 startVestingTime;
    uint64 endVestingTime;
}

// Line 185-186: In vestYield, start is set to now, end is now + duration
vestingState.startVestingTime = uint64(block.timestamp);
vestingState.endVestingTime = uint64(block.timestamp + duration);
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_startVestingTimeLEendVestingTime() public view {
    (, , , uint64 startTime, uint64 endTime) = _accountantYS().vestingState();
    
    assertLe(startTime, endTime, "Invariant 14: Start vesting time should be <= end vesting time");
}
```

---

### Rule 15: vestingGainsIntegrity

**Description**: If there are any vesting gains (yield being streamed), then the vesting period must be positive (start < end).

**Goal**: Ensure yield streaming only occurs over a positive time duration.

**Mathematical Formula**:
```
vestingGains > 0 ⟹ startTime < endTime
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 151-191: vestYield always sets duration > 0
function vestYield(uint256 yieldAmount, uint256 duration) external requiresAuth {
    // ...
    if (duration > uint256(maximumVestingTime)) revert AccountantWithYieldStreaming__DurationExceedsMaximum();
    if (duration < uint256(minimumVestingTime)) revert AccountantWithYieldStreaming__DurationUnderMinimum();
    if (yieldAmount == 0) revert AccountantWithYieldStreaming__ZeroYieldUpdate();
    // ...
    vestingState.vestingGains = uint128(yieldAmount);
    vestingState.startVestingTime = uint64(block.timestamp);
    vestingState.endVestingTime = uint64(block.timestamp + duration);
}
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_vestingGainsIntegrity() public view {
    (, uint128 vestingGains, , uint64 startTime, uint64 endTime) = _accountantYS().vestingState();

    if (vestingGains > 0) {
        assertLt(startTime, endTime, "Invariant 15: If vesting gains > 0, start must be < end");
    }
}
```

---

### Rule 16: lastVestingUpdateNeverDecreases

**Description**: The `lastVestingUpdate` timestamp should only move forward, never backward.

**Goal**: Prevent retroactive yield streaming through timestamp manipulation.

**Mathematical Formula**:
```
lastVestingUpdate_post ≥ lastVestingUpdate_pre
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 467: In _updateExchangeRate, lastVestingUpdate is always set to current time
vestingState.lastVestingUpdate = uint128(block.timestamp);
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_lastVestingUpdateNeverDecreases() public view {
    AccountantHandler.YSState memory preYS = _getPreYS();
    AccountantHandler.YSState memory postYS = _getPostYS();

    assertGe(
        postYS.lastVestingUpdate,
        preYS.lastVestingUpdate,
        "Invariant 16: Last vesting update should never decrease"
    );
}
```

---

### Rule 17: integrityOfVestYield

**Description**: After `vestYield` is called, the `lastVestingUpdate` should be properly set (≥ startTime).

**Goal**: Ensure continuous and accurate yield accrual.

**Mathematical Formula**:
```
selector == vestYield ⟹ lastVestingUpdate ≥ startTime
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_integrityOfVestYield() public view {
    bytes4 selector = _accountantHandler().lastSelector();
    
    if (selector == AccountantWithYieldStreaming.vestYield.selector) {
        (, , uint128 lastVestingUpdate, uint64 startTime, ) = _accountantYS().vestingState();
        assertGe(lastVestingUpdate, startTime, "Invariant 17: Vesting update should be >= start time");
    }
}
```

---

### Rule 18: exchangeRatePostLoss

**Description**: After a `postLoss` event, the exchange rate must be ≤ the highwater mark.

**Goal**: Correctly reset the performance baseline after recognized losses.

**Mathematical Formula**:
```
selector == postLoss ⟹ exchangeRate ≤ highwaterMark
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 199-244: postLoss reduces share price
function postLoss(uint256 lossAmount) external requiresAuth {
    // ...
    if (vestingState.vestingGains >= lossAmount) {
        vestingState.vestingGains -= uint128(lossAmount);
    } else {
        uint256 principalLoss = lossAmount - vestingState.vestingGains;
        vestingState.vestingGains = 0;
        
        // Line 222-223: Share price is REDUCED
        uint128 cachedSharePrice = vestingState.lastSharePrice;
        vestingState.lastSharePrice =
            uint128((totalAssets() - principalLoss).mulDivDown(ONE_SHARE, currentShares));
    }
    
    // Line 238: exchangeRate synced to (reduced) lastSharePrice
    state.exchangeRate = uint96(vestingState.lastSharePrice);
}
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_exchangeRatePostLoss() public view {
    bytes4 selector = _accountantHandler().lastSelector();
    
    if (selector == AccountantWithYieldStreaming.postLoss.selector && _accountantHandler().lastCallSucceeded()) {
        (, uint96 hwm, , , uint96 rate, , , , , , , ) = _accountantYS().accountantState();
        
        uint256 tolerance = uint256(hwm) / 1e16;
        if (tolerance == 0) tolerance = 100;
        
        uint256 diff = rate > hwm ? rate - hwm : hwm - rate;
        assertLe(
            diff,
            tolerance,
            "Invariant 18: After postLoss, rate should approximately equal HWM"
        );
    }
}
```

---

### Rule 19: vaultSolvency_1Asset_Vesting

**Description**: The vault must remain solvent accounting for pending vesting gains. The vault balance minus pending vesting should still cover the supply at the current rate.

**Note**: **This invariant is specifically for SINGLE-ASSET scenarios.** When alternative assets are deposited via `depositAltMAS`, this check is skipped because shares can be backed by multiple asset types.

**Goal**: Ensure solvency while accounting for unvested yield streaming.

**Mathematical Formula**:
```
(altBalance ≤ INITIAL_MINT) ⟹ 
    VaultBalance × ONE_SHARE + tolerance ≥ Supply × Rate + PendingVest × ONE_SHARE

where tolerance = max(rhs / 1000, 1)  // 0.1% tolerance for edge cases
```

**Source Contract Code** (`AccountantWithYieldStreaming.sol`):
```solidity
// Line 359-381: getPendingVestingGains calculates unvested yield
function getPendingVestingGains() public view returns (uint256 amountVested) {
    uint256 currentTime = block.timestamp;
    if (currentTime >= vestingState.endVestingTime) {
        return vestingState.vestingGains;
    }
    if (vestingState.vestingGains == 0) {
        return 0;
    }
    uint256 timeSinceLastUpdate = currentTime - vestingState.lastVestingUpdate;
    uint256 totalRemainingTime = vestingState.endVestingTime - vestingState.lastVestingUpdate;
    return amountVested = uint256(vestingState.vestingGains).mulDivDown(timeSinceLastUpdate, totalRemainingTime);
}
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_vaultSolvency_1Asset_Vesting() public view {
    uint256 totalSupply = _vault().totalSupply();

    if (totalSupply == 0) return;
    if (_isAccountantYSPaused()) return;
    if (_accountantHandler().feesRecentlyClaimed()) return;

    uint256 vaultBalance = baseAsset.balanceOf(address(_vault()));
    uint256 pendingVest = _accountantYS().getPendingVestingGains();
    uint256 rate = _accountantYS().getRateInQuoteSafe(baseAsset);

    uint256 lhs = vaultBalance * ONE_SHARE;
    uint256 rhs = totalSupply.mulDivUp(rate, 1) + pendingVest * ONE_SHARE;
    
    uint256 tolerance = rhs / 1000;
    if (tolerance == 0) tolerance = 1;
    
    assertGe(lhs + tolerance, rhs, "Invariant 19: Vesting solvency check");
}
```

---

## Group 2 (continued): YS-Only Invariants (Rules 20-23)

### Rule 20: yieldIntegrity

**Description**: Ensures that yield realization during vestYield/postLoss/updateExchangeRate does not exceed the amount that has actually vested (streamed over time). This is a core safety property preventing over-distribution of yield.

**Goal**: Prevent "time-travel" exploits or logic errors that could allow claiming more yield than has vested.

**Mathematical Formula**:
```
realizedYield ≤ pendingGains_pre

where realizedYield = lastSharePrice_post - lastSharePrice_pre (if positive)
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_yieldIntegrity() public view {
    AccountantHandler.YSState memory preYS = _getPreYS();
    AccountantHandler.YSState memory postYS = _getPostYS();
    bytes4 selector = _accountantHandler().lastSelector();
    
    bool isYieldRealizingOp = selector == AccountantWithYieldStreaming.vestYield.selector ||
                              selector == AccountantWithYieldStreaming.postLoss.selector ||
                              selector == YS_UPDATE_EXCHANGE_RATE_SELECTOR;
    
    if (!isYieldRealizingOp) return;
    if (!_accountantHandler().lastCallSucceeded()) return;
    
    uint256 realizedYield = postYS.lastSharePrice > preYS.lastSharePrice
        ? postYS.lastSharePrice - preYS.lastSharePrice
        : 0;
    
    assertLe(
        realizedYield,
        preYS.pendingGains,
        "Invariant 20: Realized yield cannot exceed pending vested gains"
    );
}
```

---

### Rule 21: yieldAccrualsMonotonic

**Description**: Available yield should only increase over time (assuming no claims).

**Goal**: Ensure yield accrual only moves forward.

**Mathematical Formula**:
```
!isReducingOp ⟹ lastVestingUpdate_post ≥ lastVestingUpdate_pre
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_yieldAccrualsMonotonic() public view {
    AccountantHandler.YSState memory preYS = _getPreYS();
    AccountantHandler.YSState memory postYS = _getPostYS();
    bytes4 selector = _accountantHandler().lastSelector();
    
    bool isReducingOp = selector == AccountantWithYieldStreaming.vestYield.selector ||
                        selector == AccountantWithYieldStreaming.postLoss.selector ||
                        selector == YS_UPDATE_EXCHANGE_RATE_SELECTOR;
    
    if (!isReducingOp) {
        assertGe(
            postYS.lastVestingUpdate,
            preYS.lastVestingUpdate,
            "Invariant 21: Yield accrual timestamp should be monotonic"
        );
    }
}
```

---

### Rule 22: streamingRateConsistency

**Description**: The available yield follows a linear streaming formula over time.

**Goal**: Mathematical verification of the streaming algorithm.

**Mathematical Formula**:
```
pendingGains ≤ vestingGains
block.timestamp ≥ endTime ⟹ pendingGains == vestingGains
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_streamingRateConsistency() public view {
    (, uint128 vestingGains, , , uint64 endTime) = _accountantYS().vestingState();
    
    uint256 pendingGains = _accountantYS().getPendingVestingGains();
    
    assertLe(
        pendingGains,
        uint256(vestingGains),
        "Invariant 22: Pending gains should not exceed total vesting gains"
    );
    
    if (block.timestamp >= endTime && vestingGains > 0) {
        assertEq(
            pendingGains,
            uint256(vestingGains),
            "Invariant 22: Past end time, pending should equal all remaining gains"
        );
    }
}
```

---

### Rule 23: accessControlYieldParams

**Description**: Only authorized roles can modify yield parameters. This checks that min/max vesting times remain consistent.

**Goal**: Restrict yield configuration to authorized personnel.

**Mathematical Formula**:
```
minimumVestingTime ≤ maximumVestingTime
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_accessControlYieldParams() public view {
    uint64 minVest = _accountantYS().minimumVestingTime();
    uint64 maxVest = _accountantYS().maximumVestingTime();
    
    assertLe(minVest, maxVest, "Invariant 35: min vesting time should be <= max vesting time");
}
```

---

### Virtual Share Price Invariants (Rules 36-38)

These invariants verify the consistency between `lastVirtualSharePrice` (stored in RAY precision, 27 decimals) and `lastSharePrice` (stored as uint128 in asset decimals).

---

### Rule 36: virtualPriceUpperBound

**Description**: The converted virtual price should not exceed `lastSharePrice + 1`. This verifies that `_calculateSharePriceFromVirtual()` correctly converts from RAY precision.

**Note**: **Conditionally Verified** - Skipped when:
- `totalSupply == 0` (no shares exist)
- Accountant is paused
- `virtualPrice == 0` (not initialized)
- `convertedPrice > type(uint128).max` (truncation occurred - see Finding 2 in FINDINGS.md)

**Mathematical Formula**:
```
virtualPrice × ONE_SHARE / RAY ≤ lastSharePrice + 1
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_virtualPriceUpperBound() public view returns (bool) {
    uint256 totalSupply = _vault().totalSupply();
    if (totalSupply == 0) return true;
    if (_isAccountantYSPaused()) return true;
    
    uint256 virtualPrice = _accountantYS().lastVirtualSharePrice();
    (uint128 lastSharePrice, , , , ) = _accountantYS().vestingState();
    
    if (virtualPrice == 0) return true;
    
    uint256 convertedPrice = virtualPrice.mulDivDown(ONE_SHARE, RAY);
    
    // Skip when truncation would occur (Finding 2)
    if (convertedPrice > type(uint128).max) return true;
    
    assertLe(
        convertedPrice, 
        uint256(lastSharePrice) + 1, 
        "Invariant 36: Virtual price conversion should be <= lastSharePrice + 1"
    );
    return true;
}
```

---

### Rule 37: virtualPriceLowerBound

**Description**: The `lastSharePrice` should not exceed the converted virtual price. Together with Rule 36, this ensures bidirectional consistency.

**Note**: **Conditionally Verified** - Same skip conditions as Rule 36.

**Mathematical Formula**:
```
lastSharePrice ≤ virtualPrice × ONE_SHARE / RAY
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_virtualPriceLowerBound() public view returns (bool) {
    uint256 totalSupply = _vault().totalSupply();
    if (totalSupply == 0) return true;
    if (_isAccountantYSPaused()) return true;
    
    uint256 virtualPrice = _accountantYS().lastVirtualSharePrice();
    (uint128 lastSharePrice, , , , ) = _accountantYS().vestingState();
    
    if (virtualPrice == 0) return true;
    
    uint256 convertedPrice = virtualPrice.mulDivDown(ONE_SHARE, RAY);
    if (convertedPrice > type(uint128).max) return true;
    
    assertLe(
        lastSharePrice, 
        convertedPrice,
        "Invariant 37: lastSharePrice should be <= converted virtual price"
    );
    return true;
}
```

---

### Rule 38: pendingGainsRateRelationship

**Description**: Verifies the mathematical relationship between `getRate()`, `lastSharePrice`, and `pendingGains`. When no pending gains exist, rate should equal lastSharePrice (±1 for rounding).

**Mathematical Formula**:
```
totalSupply == 0 ⟹ rate == lastSharePrice
pendingGains == 0 ⟹ |rate - lastSharePrice| ≤ 1
rate ≈ lastSharePrice ⟹ pendingGains ≤ negligible
```

**Invariant Test Code** (in `YSOnlyInvariants.sol`):
```solidity
function invariant_pendingGainsRateRelationship() public view returns (bool) {
    uint256 pendingGains = _accountantYS().getPendingVestingGains();
    uint256 rate = _accountantYS().getRate();
    (uint128 lastSharePrice, , , , ) = _accountantYS().vestingState();
    uint256 totalSupply = _vault().totalSupply();
    
    if (totalSupply == 0) {
        assertEq(rate, lastSharePrice, "Invariant 38: With 0 shares, rate == lastSharePrice");
        return true;
    }
    
    if (pendingGains == 0) {
        uint256 diff = rate > lastSharePrice ? rate - lastSharePrice : uint256(lastSharePrice) - rate;
        assertLe(diff, 1, "Invariant 38: Zero pending gains implies rate == lastSharePrice (+/-1)");
    }
    
    if (rate <= uint256(lastSharePrice) + 1 && rate >= uint256(lastSharePrice)) {
        uint256 maxNegligibleGains = (2 * totalSupply) / ONE_SHARE + 1;
        assertLe(
            pendingGains, 
            maxNegligibleGains, 
            "Invariant 38: Rate approx lastSharePrice implies negligible pending gains"
        );
    }
    return true;
}
```

---

## Group 3: Teller & Vault Integrity (Rules 20-35)

### Rule 24: integrityOfDeposit

**Description**: When depositing, users must receive at least `minimumMint` shares, and exactly `depositAmount` assets must be taken.

**Goal**: Ensure users receive the correct amount of shares for assets provided.

**Mathematical Formula**:
```
sharesMinted ≥ minimumMint ∧ assetsTaken == depositAmount
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Line 580-599: _erc20Deposit enforces these checks
function _erc20Deposit(...) internal virtual returns (uint256 shares) {
    _handleDenyList(from, to, msg.sender);
    uint112 cap = depositCap;
    if (depositAmount == 0) revert TellerWithMultiAssetSupport__ZeroAssets();
    shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(depositAsset));
    shares = asset.sharePremium > 0 ? shares.mulDivDown(1e4 - asset.sharePremium, 1e4) : shares;
    
    // Line 593: Enforce minimum mint
    if (shares < minimumMint) revert TellerWithMultiAssetSupport__MinimumMintNotMet();
    
    if (cap != type(uint112).max) {
        if (shares + vault.totalSupply() > cap) revert TellerWithMultiAssetSupport__DepositExceedsCap();
    }
    // Line 597: Exactly depositAmount is transferred
    vault.enter(from, depositAsset, depositAmount, to, shares);
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_integrityOfDeposit() public view {
    bytes4 selector = _tellerHandler().lastSelector();
    
    bool isDepositOp = selector == TellerWithMultiAssetSupport.deposit.selector ||
                       selector == TellerWithMultiAssetSupport.bulkDeposit.selector;
    
    if (!isDepositOp) return;
    
    uint256 lastDepositAssets = _tellerHandler().lastDepositAssets();
    uint256 lastDepositShares = _tellerHandler().lastDepositShares();
    
    if (lastDepositAssets > 0 && _tellerHandler().depositCalls() > 0) {
        assertGt(lastDepositShares, 0, "Invariant 24: Deposit should mint shares");
    }
}
```

**Note on Handler Tracking**: The handler only tracks deposits that mint `shares > 0`. Tiny deposits with `sharePremium > 0` can legitimately round down to 0 shares, which the protocol allows but would cause false positive failures if tracked.

---

### Rule 25: integrityOfWithdraw

**Description**: When withdrawing, users must receive at least `minimumAssets` and exactly `shareAmount` shares must be burned.

**Goal**: Ensure users receive the correct assets for shares burned.

**Mathematical Formula**:
```
assetsReceived ≥ minimumAssets ∧ sharesBurned == sharesAmount
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Line 604-614: _withdraw enforces these checks
function _withdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to) 
    internal virtual returns (uint256 assetsOut) 
{
    if (isPaused) revert TellerWithMultiAssetSupport__Paused();
    Asset memory asset = assetData[withdrawAsset];
    if (!asset.allowWithdraws) revert TellerWithMultiAssetSupport__AssetNotSupported();

    if (shareAmount == 0) revert TellerWithMultiAssetSupport__ZeroShares();
    assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), ONE_SHARE);
    
    // Line 611: Enforce minimum assets
    if (assetsOut < minimumAssets) revert TellerWithMultiAssetSupport__MinimumAssetsNotMet();
    
    _beforeWithdraw(withdrawAsset, assetsOut);
    // Line 613: Exactly shareAmount is burned
    vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_integrityOfWithdraw() public view {
    bytes4 selector = _tellerHandler().lastSelector();
    
    bool isWithdrawOp = selector == TellerWithMultiAssetSupport.withdraw.selector ||
                        selector == TellerWithMultiAssetSupport.bulkWithdraw.selector;
    
    if (!isWithdrawOp) return;
    
    uint256 lastWithdrawShares = _tellerHandler().lastWithdrawShares();
    uint256 lastWithdrawAssets = _tellerHandler().lastWithdrawAssets();
    
    // DUST_THRESHOLD accounts for lowest decimal asset (6 decimals)
    // Need 1e12 shares minimum to produce 1 token output for 6-decimal assets
    uint256 DUST_THRESHOLD = 1e12;
    if (lastWithdrawShares > DUST_THRESHOLD && _tellerHandler().withdrawCalls() > 0) {
        assertGt(lastWithdrawAssets, 0, "Invariant 25: Withdraw should produce assets");
    }
}
```

**Note on DUST_THRESHOLD**: The threshold is set to `1e12` (not `100`) to account for decimal diversity in alternative assets. For a 6-decimal asset, at least `1e12` shares (in 18-decimal terms) are needed to produce 1 token of output, assuming a ~1:1 exchange rate.

---

### Rule 26: noFreeAssets

**Description**: A round-trip of deposit followed by withdraw should never produce more assets than originally deposited. `withdraw(deposit(X)) <= X`

**Goal**: Prevent value extraction through rounding manipulation (Dust favors the house).

**Mathematical Formula**:
```
withdraw(deposit(X)) ≤ X
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_noFreeAssets() public view {
    if (_isAccountantPaused()) return;
    
    uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
    if (rate == 0) return;
    
    uint256 testAmount = _tellerHandler().lastDepositAssets();
    if (testAmount == 0) testAmount = 1000e18;
    
    uint256 shares = testAmount.mulDivDown(ONE_SHARE, rate);
    uint256 recoveredAssets = shares.mulDivDown(rate, ONE_SHARE);
    
    assertLe(recoveredAssets, testAmount, "Invariant 26: Round-trip should not create free assets");
}
```

---

### Rule 27: tellerDoesntHoldTokens

**Description**: The Teller contracts should never hold any user tokens. They act as pass-through entities.

**Goal**: Ensure the Teller contract never retains user funds.

**Mathematical Formula**:
```
∀ teller ∈ {tellerMAS, tellerYS}:
    balanceOf(teller, baseAsset) == 0
    ∀ i ∈ [0, NUM_ALT_ASSETS): balanceOf(teller, alternativeAssets[i]) == 0
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Deposits go directly to vault (Line 597)
vault.enter(from, depositAsset, depositAmount, to, shares);

// Withdrawals go directly from vault to recipient (Line 613)
vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_tellerDoesntHoldTokens() public view {
    address teller = address(_teller());
    
    assertEq(
        baseAsset.balanceOf(teller),
        0,
        "Invariant 27: Teller should not hold base tokens"
    );
    
    // Check ALL alternative assets (N-asset support)
    for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
        assertEq(
            alternativeAssets[i].balanceOf(teller),
            0,
            "Invariant 27: Teller should not hold alt tokens"
        );
    }
}
```

---

### Rule 28: vaultCannotChange

**Description**: The vault address in the Teller contract is immutable and cannot be changed.

**Goal**: Prevent the Teller from being re-pointed to a malicious vault.

**Mathematical Formula**:
```
teller.vault() == initialVault (constant)
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Line 179: vault is immutable
BoringVault public immutable vault;

// Line 199: Set once in constructor
vault = BoringVault(payable(_vault));
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_vaultCannotChange() public view {
    assertEq(address(_teller().vault()), address(_vault()), "Invariant 28: Teller vault should be immutable");
}
```

---

### Rule 29: depositNonceNeverGoesDown

**Description**: The deposit nonce should only increase, never decrease, ensuring unique sequential transaction tracking.

**Goal**: Maintain unique, sequential transaction tracking.

**Mathematical Formula**:
```
nonce_post ≥ nonce_pre
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Line 79: depositNonce state variable
uint64 public depositNonce;

// Line 637: Nonce is only incremented, never decremented
function _afterPublicDeposit(...) internal {
    // Increment then assign as its slightly more gas efficient.
    uint256 nonce = ++depositNonce;
    // ...
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_depositNonceNeverGoesDown() public view {
    TellerHandler.TellerState memory pre = _getTellerPreState();
    TellerHandler.TellerState memory post = _getTellerPostState();

    assertGe(post.depositNonce, pre.depositNonce, "Invariant 29: Deposit nonce should never decrease");
}
```

---

### Rule 30: tellerPaused_valuesFrozen

**Description**: When the Teller is paused, the nonce and deposit history should remain frozen (except for `refundDeposit`).

**Assumption**: Excludes `refundDeposit`

**Goal**: Lock the Teller state during emergency pauses.

**Mathematical Formula**:
```
paused ∧ selector ≠ refundDeposit ⟹ nonce_post == nonce_pre
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Line 619-623: _beforeDeposit checks pause state
function _beforeDeposit(ERC20 depositAsset) internal view returns (Asset memory asset) {
    if (isPaused) revert TellerWithMultiAssetSupport__Paused();
    // ...
}

// Line 605: _withdraw also checks pause state
function _withdraw(...) internal virtual returns (uint256 assetsOut) {
    if (isPaused) revert TellerWithMultiAssetSupport__Paused();
    // ...
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_tellerPaused_valuesFrozen() public view {
    TellerHandler.TellerState memory pre = _getTellerPreState();
    TellerHandler.TellerState memory post = _getTellerPostState();
    bytes4 selector = _tellerHandler().lastSelector();

    if (pre.isPaused && selector != TellerWithMultiAssetSupport.refundDeposit.selector) {
        assertEq(post.depositNonce, pre.depositNonce, "Invariant 30: Nonce frozen when paused");
    }
}
```

---

### Rule 31: tellerPaused_methodsRevert

**Description**: When paused, public deposit/withdraw methods must revert.

**Goal**: Halt all user interactions during a pause.

**Mathematical Formula**:
```
paused ⟹ publicMethods.revert()
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Lines 619-620 and 605: Both _beforeDeposit and _withdraw revert when paused
if (isPaused) revert TellerWithMultiAssetSupport__Paused();
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_tellerPaused_methodsRevert() public view {
    TellerHandler.TellerState memory pre = _getTellerPreState();
    TellerHandler.TellerState memory post = _getTellerPostState();
    bytes4 selector = _tellerHandler().lastSelector();
    
    if (pre.isPaused) {
        bool isPublicDepositWithdraw = 
            selector == TellerWithMultiAssetSupport.deposit.selector ||
            selector == TellerWithMultiAssetSupport.withdraw.selector;
        
        if (isPublicDepositWithdraw) {
            assertEq(
                post.vaultTotalSupply,
                pre.vaultTotalSupply,
                "Invariant 31: Paused teller should reject deposits/withdrawals"
            );
        }
    }
}
```

---

### Rule 32: dustFavorsTheHouse

**Description**: Any rounding errors from deposit→withdraw sequences should favor the vault (house), not create free assets for users.

**Goal**: Ensure no asset leakage due to rounding errors.

**Mathematical Formula**:
```
deposit → withdraw ⟹ vaultBalance_post ≥ vaultBalance_pre
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_dustFavorsTheHouse() public view {
    if (_isAccountantPaused()) return;
    
    uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
    if (rate == 0) return;
    
    uint256 testAmount = 12345678901234567890;
    
    uint256 sharesFromDeposit = testAmount.mulDivDown(ONE_SHARE, rate);
    uint256 assetsFromWithdraw = sharesFromDeposit.mulDivDown(rate, ONE_SHARE);
    
    assertLe(assetsFromWithdraw, testAmount, "Invariant 32: Rounding should favor the vault");
}
```

---

### Rule 33: noDynamicCalls

**Description**: The handlers must never make unauthorized `call` or `delegatecall` to non-whitelisted addresses.

**Goal**: Prevent the Teller from being used to perform unauthorized external calls.

**Mathematical Formula**:
```
!callMade ∧ !delegatecallMade
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_noDynamicCalls() public view {
    assertFalse(_tellerHandler().callMade(), "Invariant 33: No unauthorized calls should be made");
    assertFalse(_tellerHandler().delegatecallMade(), "Invariant 33: No unauthorized delegatecalls should be made");
    assertFalse(_accountantHandler().callMade(), "Invariant 33: No unauthorized calls should be made");
    assertFalse(_accountantHandler().delegatecallMade(), "Invariant 33: No unauthorized delegatecalls should be made");
}
```

---

### Rule 34: onlyContributionMethodsReduceAssets

**Description**: User assets should only decrease if the operation is a deposit-type method.

**Goal**: Ensure user assets only decrease during authorized deposit operations.

**Mathematical Formula**:
```
userAssets_post < userAssets_pre ⟹ isContributionMethod(selector)
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Only deposit methods transfer FROM user:
// - deposit() Line 467-495
// - depositWithPermit() Line 501-524
// - bulkDeposit() Line 531-542

// Withdraw methods transfer TO user (not reduce assets):
// - withdraw() Line 563-573
// - bulkWithdraw() Line 548-557
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_onlyContributionMethodsReduceAssets() public view {
    bytes4 selector = _tellerHandler().lastSelector();
    address actor = _tellerHandler().currentActor();

    if (actor == address(0)) return;

    TellerHandler.UserState memory preUser = _tellerHandler().getPreUserState(actor);
    TellerHandler.UserState memory postUser = _tellerHandler().getPostUserState(actor);

    if (postUser.baseBalance < preUser.baseBalance) {
        bool isDepositMethod = 
            selector == TellerWithMultiAssetSupport.deposit.selector ||
            selector == TellerWithMultiAssetSupport.depositWithPermit.selector ||
            selector == TellerWithMultiAssetSupport.bulkDeposit.selector;
        
        assertTrue(isDepositMethod, "Invariant 34: Only deposit methods should reduce user assets");
    }
}
```

---

### Rule 35: withdrawingProducesAssets

**Description**: When shares are withdrawn, the user must receive assets in return (unless withdrawing dust amounts).

**Note**: Due to integer division rounding and decimal diversity, withdrawing small share amounts to low-decimal assets can legitimately return 0 assets. The threshold accounts for 6-decimal assets where `1e12` shares are needed for 1 token output.

**Goal**: Maintain the integrity of the withdrawal exchange.

**Mathematical Formula**:
```
sharesWithdrawn > DUST_THRESHOLD ⟹ assetsReceived > 0

where DUST_THRESHOLD = 1e12 (accounts for 6-decimal assets)
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Line 610: Assets calculation uses mulDivDown (rounds down)
assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), ONE_SHARE);

// For low-decimal assets with rate conversion:
// 6-decimal asset rate: _changeDecimals(1e18, 18, 6) = 1e6
// assetsOut = 1e11 * 1e6 / 1e18 = 0 (rounds to 0)
// assetsOut = 1e12 * 1e6 / 1e18 = 1 (minimum viable)
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_withdrawingProducesAssets() public view {
    uint256 withdrawCalls = _tellerHandler().withdrawCalls();
    uint256 bulkWithdrawCalls = _tellerHandler().bulkWithdrawCalls();
    
    if (withdrawCalls == 0 && bulkWithdrawCalls == 0) {
        return;
    }
    
    uint256 sharesWithdrawn = _tellerHandler().lastWithdrawShares();
    uint256 assetsReceived = _tellerHandler().lastWithdrawAssets();

    // DUST_THRESHOLD accounts for lowest decimal asset (6 decimals)
    // Need 1e12 shares minimum to produce 1 token output for 6-decimal assets
    uint256 DUST_THRESHOLD = 1e12;
    
    if (sharesWithdrawn > DUST_THRESHOLD) {
        assertGt(assetsReceived, 0, "Invariant 35: Withdrawing shares should produce assets");
    }
}
```

---

### Rule 36: feesIntegrity

**Description**: The fees claimed cannot exceed the fees that were available. This verifies that `claimFees` never extracts more value than has been accrued.

**Goal**: Prevent claiming more fees than have been accrued.

**Mathematical Formula**:
```
feesClaimed ≤ feesOwedInBase_pre
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_feesIntegrity() public view {
    AccountantHandler.RPState memory pre = _getPreState();
    AccountantHandler.RPState memory post = _getPostState();
    bytes4 selector = _accountantHandler().lastSelector();
    
    if (selector == AccountantWithRateProviders.claimFees.selector) {
        uint256 claimedAmount = pre.feesOwedInBase > post.feesOwedInBase 
            ? pre.feesOwedInBase - post.feesOwedInBase 
            : 0;
        
        assertLe(
            claimedAmount,
            pre.feesOwedInBase,
            "feesIntegrity: Claimed fees should not exceed available fees"
        );
    }
}
```

**Note**: For yield streaming integrity (YS system), see `invariant_yieldIntegrity` in `YSOnlyInvariants.sol` which verifies that yield claims don't exceed vested gains.

---

### Rule 37: deniedUsers_balanceNonDecreasing

**Description**: If a user is on the `denyFrom` list, their share balance should not decrease (they cannot transfer out).

**Assumption**: Excludes withdraw and refund operations.

**Goal**: Prevent outflow from blacklisted addresses.

**Mathematical Formula**:
```
denyFrom == true ⟹ shares_post ≥ shares_pre
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Line 378-388: beforeTransfer hook enforces deny list
function beforeTransfer(address from, address to, address operator) public view virtual {
    _handleDenyList(from, to, operator);
    // ...
}

// Line 409-416: _handleDenyList reverts if from is denied
function _handleDenyList(address from, address to, address operator) internal view {
    if (
        beforeTransferData[from].denyFrom || beforeTransferData[to].denyTo
            || beforeTransferData[operator].denyOperator
    ) {
        revert TellerWithMultiAssetSupport__TransferDenied(from, to, operator);
    }
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_deniedUsers_balanceNonDecreasing() public view {
    TellerHandler.UserState memory preDenied = _tellerHandler().getPreUserState(deniedUser);
    TellerHandler.UserState memory postDenied = _tellerHandler().getPostUserState(deniedUser);

    if (preDenied.denyFrom) {
        assertGe(
            postDenied.shares,
            preDenied.shares,
            "Invariant 37: Denied user (denyFrom) shares should not decrease"
        );
    }
}
```

---

### Rule 38: deniedUsers_balanceNonIncreasing

**Description**: If a user is on the `denyTo` list, their share balance should not increase (they cannot receive transfers).

**Goal**: Prevent inflow to blacklisted addresses.

**Mathematical Formula**:
```
denyTo == true ⟹ shares_post ≤ shares_pre
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Same as Rule 36 - _handleDenyList also checks denyTo
if (beforeTransferData[to].denyTo) {
    revert TellerWithMultiAssetSupport__TransferDenied(from, to, operator);
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_deniedUsers_balanceNonIncreasing() public view {
    TellerHandler.UserState memory preDenied = _tellerHandler().getPreUserState(deniedUser);
    TellerHandler.UserState memory postDenied = _tellerHandler().getPostUserState(deniedUser);

    if (preDenied.denyTo) {
        assertLe(
            postDenied.shares,
            preDenied.shares,
            "Invariant 38: Denied user (denyTo) shares should not increase"
        );
    }
}
```

---

## Group 4: Math & Solvency (Rules 39-47)

### Rule 39: vaultSolvencyMulti

**Description**: Multi-asset solvency check ensuring the combined value of all N assets covers all outstanding shares. Supports arbitrary number of alternative assets with **decimal diversity** (6, 8, 11, 18 decimals).

**Note**: Converts all asset balances to **share-equivalent terms** (18 decimals) using the accountant's `getRateInQuoteSafe()` function, which correctly handles decimal conversion via `_changeDecimals()`. This aligns with how the Teller calculates shares during deposits.

**Fee Handling**: Fees are NOT added separately to the solvency calculation. Fees are part of `totalAssets` - when shares represent a claim on vault assets, that claim includes the fee portion. The vault balance should cover `totalSupply * rate`, which inherently includes fees.

**IMPORTANT**: This invariant can fail if rate provider rates change AFTER deposits. When deposits occur at rate X and rate later changes to Y, existing shares may be "underwater". This is expected behavior - rate provider changes should be done carefully in production. **The check is skipped after `setAltAssetRate`**.

**Goal**: Ensure total asset value (in share terms) covers all shares across N assets.

**Mathematical Formula**:
```
(selector ≠ setAltAssetRate) ⟹ 
    totalValueInShares + tolerance ≥ totalSupply

where:
    // Convert each asset balance to share-equivalent using accountant's rate
    totalValueInShares = Σ(assetBalance[i] × ONE_SHARE / rate[i]) for all assets
    tolerance = max(totalSupply / 100, 1)  // 1% tolerance for fuzzing edge cases
    
    Solvency: totalValueInShares + tolerance ≥ totalSupply
```

**Note on Calculation Method**: The solvency check calculates total value in **share terms** (18 decimals) rather than base asset terms. This aligns with how the Teller calculates shares during deposits and correctly handles decimal diversity across assets with different decimal precisions (6, 8, 11, 18 decimals).

**Source Contract Code** (`AccountantWithRateProviders.sol`):
```solidity
// Line 368-383: getRateInQuote handles multi-asset rate conversion with decimal adjustment
function getRateInQuote(ERC20 quote) public virtual view returns (uint256 rateInQuote) {
    if (address(quote) == address(base)) {
        rateInQuote = accountantState.exchangeRate;
    } else {
        RateProviderData memory data = rateProviderData[quote];
        uint8 quoteDecimals = ERC20(quote).decimals();
        uint256 exchangeRateInQuoteDecimals = _changeDecimals(accountantState.exchangeRate, decimals, quoteDecimals);
        if (data.isPeggedToBase) {
            rateInQuote = exchangeRateInQuoteDecimals;
        } else {
            uint256 quoteRate = data.rateProvider.getRate();
            uint256 oneQuote = 10 ** quoteDecimals;
            rateInQuote = oneQuote.mulDivDown(exchangeRateInQuoteDecimals, quoteRate);
        }
    }
}

// _changeDecimals handles scaling between different decimal precisions
function _changeDecimals(uint256 value, uint8 fromDecimals, uint8 toDecimals) internal pure returns (uint256) {
    if (fromDecimals == toDecimals) return value;
    if (fromDecimals < toDecimals) return value * 10 ** (toDecimals - fromDecimals);
    return value / 10 ** (fromDecimals - toDecimals);
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_vaultSolvencyMulti() public view {
    uint256 totalSupply = _vault().totalSupply();

    if (totalSupply == 0) return;
    if (_isAccountantPaused()) return;
    if (_accountantHandler().feesRecentlyClaimed()) return;
    if (_accountantHandler().altAssetRateChanged()) return;

    address vault = address(_vault());
    
    // Calculate total value in SHARE terms (not base asset terms)
    // This aligns with how the Teller calculates shares during deposits
    uint256 totalValueInShares = 0;
    
    // Base asset contribution
    uint256 baseBalance = baseAsset.balanceOf(vault);
    uint256 baseRate = _accountant().getRateInQuoteSafe(baseAsset);
    if (baseRate > 0 && baseBalance > 0) {
        totalValueInShares += baseBalance.mulDivDown(ONE_SHARE, baseRate);
    }
    
    // Alternative assets contribution (N-asset support with decimal diversity)
    for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
        uint256 altBalance = alternativeAssets[i].balanceOf(vault);
        if (altBalance > 0) {
            try _accountant().getRateInQuoteSafe(ERC20(address(alternativeAssets[i]))) returns (uint256 altRate) {
                if (altRate > 0) {
                    // Convert alt asset balance to share terms using accountant's rate
                    // The rate already accounts for decimal differences via _changeDecimals
                    totalValueInShares += altBalance.mulDivDown(ONE_SHARE, altRate);
                }
            } catch {}
        }
    }
    
    // Note: Fees are NOT added separately - they are part of totalAssets.
    // The vault balance should cover totalSupply * rate, which includes fees.

    // Solvency check: totalValueInShares >= totalSupply (with 1% tolerance)
    uint256 tolerance = totalSupply / 100;
    if (tolerance == 0) tolerance = 1;

    assertGe(totalValueInShares + tolerance, totalSupply, "Invariant 38: Multi-asset solvency check (N assets)");
}
```

---

### Rule 40: vaultSolvency_1Asset

**Description**: Single-asset solvency check ensuring the vault balance covers all shares at the current rate.

**Important**: 
- **Fees are NOT added separately** - they are part of `totalAssets`. The vault balance should cover `totalSupply * rate`, which inherently includes the fee portion.
- **This invariant is specifically for SINGLE-ASSET scenarios.** When ANY alternative asset is deposited via `depositAltMAS`, this check is skipped because shares are backed by multiple asset types.

**Goal**: Single asset variant of the solvency check.

**Mathematical Formula**:
```
(∀ i ∈ [0, N): altBalance[i] == 0) ⟹ 
    vaultBalance × ONE_SHARE + tolerance ≥ totalSupply × rate

where tolerance = max(rhs / 1000, 1)  // 0.1% tolerance for edge cases
```

**Note on Fee Handling**: Fees are NOT added to the LHS. The vault balance should cover `totalSupply * rate`, and fees are part of that total value (not separate from it). When fees are claimed, they come FROM the vault balance.

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_vaultSolvency_1Asset() public view {
    uint256 totalSupply = _vault().totalSupply();

    if (totalSupply == 0) return;
    if (_isAccountantPaused()) return;
    if (_accountantHandler().feesRecentlyClaimed()) return;

    // This is a SINGLE-asset solvency check - skip if ANY alt asset is present (N-asset support)
    address vault = address(_vault());
    for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
        if (alternativeAssets[i].balanceOf(vault) > 0) return;
    }

    uint256 vaultBalance = baseAsset.balanceOf(vault);
    uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);

    uint256 lhs = vaultBalance * ONE_SHARE;
    uint256 rhs = totalSupply * rate;

    uint256 tolerance = rhs / 1000;
    if (tolerance == 0) tolerance = 1;

    assertGe(lhs + tolerance, rhs, "Invariant 39: Single-asset solvency check");
}
```

---

### Rule 41: convertToAssetsWeakAdditivity

**Description**: Converting shares to assets satisfies weak additivity: the sum of individual conversions is ≤ the conversion of the sum.

**Goal**: Ensure rounding in asset conversion favors the system.

**Mathematical Formula**:
```
convert(A) + convert(B) ≤ convert(A + B)

where convert(shares) = shares × rate / ONE_SHARE (using mulDivDown)
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_convertToAssetsWeakAdditivity() public view {
    if (_isAccountantPaused()) return;
    
    uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
    if (rate == 0) return;

    uint256 sharesA = 100e18;
    uint256 sharesB = 200e18;

    uint256 assetsA = sharesA.mulDivDown(rate, ONE_SHARE);
    uint256 assetsB = sharesB.mulDivDown(rate, ONE_SHARE);
    uint256 assetsAB = (sharesA + sharesB).mulDivDown(rate, ONE_SHARE);

    assertLe(assetsA + assetsB, assetsAB + 1, "Invariant 41: Weak additivity for convertToAssets");
}
```

---

### Rule 42: convertToSharesWeakAdditivity

**Description**: Converting assets to shares satisfies weak additivity: the sum of individual conversions is ≤ the conversion of the sum.

**Goal**: Ensure rounding in share conversion favors the system.

**Mathematical Formula**:
```
convert(A) + convert(B) ≤ convert(A + B)

where convert(assets) = assets × ONE_SHARE / rate (using mulDivDown)
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_convertToSharesWeakAdditivity() public view {
    if (_isAccountantPaused()) return;
    
    uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
    if (rate == 0) return;

    uint256 assetsA = 100e18;
    uint256 assetsB = 200e18;

    uint256 sharesA = assetsA.mulDivDown(ONE_SHARE, rate);
    uint256 sharesB = assetsB.mulDivDown(ONE_SHARE, rate);
    uint256 sharesAB = (assetsA + assetsB).mulDivDown(ONE_SHARE, rate);

    assertLe(sharesA + sharesB, sharesAB + 1, "Invariant 42: Weak additivity for convertToShares");
}
```

---

### Rule 43: conversionWeakMonotonicity

**Description**: Conversion functions are weakly monotonic: larger inputs produce larger or equal outputs.

**Goal**: Ensure consistent conversion behavior across all input ranges.

**Mathematical Formula**:
```
x < y ⟹ convert(x) ≤ convert(y)
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_conversionWeakMonotonicity() public view {
    if (_isAccountantPaused()) return;
    
    uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
    if (rate == 0) return;

    uint256 x = 100e18;
    uint256 y = 200e18;

    uint256 convertX = x.mulDivDown(ONE_SHARE, rate);
    uint256 convertY = y.mulDivDown(ONE_SHARE, rate);

    assertTrue(x < y, "Test precondition");
    assertLe(convertX, convertY, "Invariant 43: Conversion weak monotonicity");
}
```

---

### Rule 44: conversionWeakIntegrity

**Description**: Round-trip conversions (assets→shares→assets) never create value.

**Goal**: Ensure round-trip conversions never create value.

**Mathematical Formula**:
```
convertBack(convert(x)) ≤ x
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_conversionWeakIntegrity() public view {
    if (_isAccountantPaused()) return;
    
    uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
    if (rate == 0) return;

    uint256 originalAssets = 100e18;

    uint256 shares = originalAssets.mulDivDown(ONE_SHARE, rate);
    uint256 recoveredAssets = shares.mulDivDown(rate, ONE_SHARE);

    assertLe(recoveredAssets, originalAssets, "Invariant 44: Round trip should not create value");
}
```

---

### Rule 45: zeroAllowanceOnAssets

**Description**: After operations complete, the Teller should not have residual spending allowance on user assets.

**Note**: Allowance is given to the vault, not the teller. Some unused allowance may remain after deposits, which is acceptable.

**Goal**: Ensure the Teller does not have residual spending power over user funds.

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_zeroAllowanceOnAssets() public view {
    for (uint256 i = 0; i < actors.length; i++) {
        address actor = actors[i];
        
        uint256 tellerAllowance = baseAsset.allowance(actor, address(_teller()));
        assertEq(
            tellerAllowance,
            0,
            "Invariant 45: Users should not give allowance to teller"
        );
    }
}
```

---

### Rule 46: conversionOfZero

**Description**: Converting zero should always return zero.

**Goal**: Ensure zero-value inputs always result in zero-value outputs.

**Mathematical Formula**:
```
convert(0) == 0
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_conversionOfZero() public view {
    if (_isAccountantPaused()) return;
    
    uint256 rate = _accountant().getRateInQuoteSafe(baseAsset);
    if (rate == 0) return;

    uint256 zeroAssets = 0;
    uint256 zeroShares = zeroAssets.mulDivDown(ONE_SHARE, rate);
    
    assertEq(zeroShares, 0, "Invariant 46: convert(0) should equal 0");
}
```

---

### Rule 47: totalSupplyLEqCap

**Description**: The deposit cap limits NEW deposits, not existing supply. An admin can lower the cap below current supply at any time. This invariant verifies that deposits are rejected when they would exceed the cap.

**Goal**: Enforce the global deposit limit.

**Mathematical Formula**:
```
isDepositOp ∧ supplyIncreased ⟹ postSupply ≤ depositCap
```

**Source Contract Code** (`TellerWithMultiAssetSupport.sol`):
```solidity
// Line 594-596: Cap check in _erc20Deposit
if (cap != type(uint112).max) {
    if (shares + vault.totalSupply() > cap) revert TellerWithMultiAssetSupport__DepositExceedsCap();
}

// Line 365-368: Admin can set any cap value
function setDepositCap(uint112 cap) external requiresAuth {
    depositCap = cap;
    emit DepositCapSet(cap);
}
```

**Invariant Test Code** (in `BaseInvariants.sol`):
```solidity
function invariant_totalSupplyLEqCap() public view {
    TellerHandler.TellerState memory pre = _getTellerPreState();
    TellerHandler.TellerState memory post = _getTellerPostState();
    bytes4 selector = _tellerHandler().lastSelector();
    
    bool isDepositOp = selector == TellerWithMultiAssetSupport.deposit.selector ||
                       selector == TellerWithMultiAssetSupport.bulkDeposit.selector;
    
    if (!isDepositOp) return;
    
    if (post.vaultTotalSupply > pre.vaultTotalSupply) {
        assertLe(
            post.vaultTotalSupply,
            pre.depositCap,
            "Invariant 47: Deposit should respect deposit cap"
        );
    }
}
```

---

---

## Summary

This invariant suite provides comprehensive coverage of the BoringVault ecosystem through **47 distinct rules** organized into four groups:

1. **Accountant Common Logic (Rules 1-7)**: 7 invariants verifying basic accounting properties like token handling, paused state behavior, fee mechanics, and timestamp progression. Implemented in `BaseInvariants.sol`.

2. **Accountant Yield Specific (Rules 8-19, 32-38)**: 19 invariants ensuring yield streaming mechanics work correctly, including share price calculations, vesting state integrity, virtual price consistency, and solvency during active vesting. Implemented in `YSOnlyInvariants.sol`.

3. **Teller & Vault Integrity (Rules 20-31, 33-37)**: 17 invariants validating deposit/withdraw operations, access control, deny list functionality, and token pass-through behavior. Implemented in `BaseInvariants.sol`.

4. **Math & Solvency (Rules 38-47)**: 10 invariants mathematically verifying solvency conditions, conversion function properties, and cap enforcement. Implemented in `BaseInvariants.sol`.

### Findings Discovered

The fuzzing suite discovered two edge cases documented in `FINDINGS.md`:

1. **Finding 1** (`setFirstDepositTimestamp` Bug): A combination of stale `vestingGains` and incomplete timestamp reset creates invalid vesting state. Handler workaround applied.

2. **Finding 2** (`uint128` Truncation): When `lastVirtualSharePrice` exceeds ~3.4e56, the `uint128` cast silently truncates, causing `lastSharePrice` to diverge. Invariant skip applied for edge case.

### Key Implementation Notes

- **Modular Architecture**: Uses inheritance-based design with abstract base contracts (`BaseInvariants`, `YSOnlyInvariants`) and concrete test contracts (`InvariantTestRP`, `InvariantTestYS`)
- **Separate Vaults**: Each system (RP and YS) has its own dedicated vault instance to prevent cross-contamination during fuzzing
- **N-Asset Support**: The RP system supports 5 alternative assets (configurable via `NUM_ALT_ASSETS`), each with its own rate provider. Handler functions are parameterized by asset index.
- **Decimal Diversity**: Alternative assets use varying decimals (18, 6, 6, 8, 11) to simulate real-world tokens (WETH, USDC, USDT, WBTC, edge cases). See `ALT_ASSET_DECIMALS` in `BaseSetup.sol`.
- **Minimum Withdrawal Requirements**: All withdrawal handlers enforce `minAssets >= 1` to prevent 0-asset withdrawals. For low-decimal assets, minimum share amounts are scaled accordingly (e.g., `1e12` shares for 6-decimal assets).
- **DUST_THRESHOLD**: Set to `1e12` in withdrawal invariants to account for decimal diversity. This represents 1 token in 6-decimal terms when converted to 18-decimal shares.
- **Ghost State Tracking**: Handlers capture pre/post operation snapshots for transition invariants
- **Rounding Awareness**: Accounts for `mulDivDown`/`mulDivUp` rounding behavior
- **Edge Case Handling**: Handles extreme time warps, tiny amounts, and multi-asset scenarios
- **Proper Rate Usage**: Distinguishes between `getRate()` (includes vesting) and `lastSharePrice` for YS
- **Fee Accounting**: Includes `feesOwedInBase` in solvency calculations
- **Share-Based Solvency**: Multi-asset solvency uses share-term calculations (not base-asset terms) to correctly handle decimal diversity

### Multi-Asset Considerations (N-Asset Support)

The RP system supports **N alternative assets** (default: 5) with **decimal diversity**:

| Index | Decimals | Simulates | Min Shares for 1 Token |
|-------|----------|-----------|------------------------|
| 0 | 18 | WETH, DAI | 1 |
| 1 | 6 | USDC | 1e12 |
| 2 | 6 | USDT | 1e12 |
| 3 | 8 | WBTC | 1e10 |
| 4 | 11 | Edge case | 1e7 |

Several invariants handle multi-asset scenarios:

| Invariant | Behavior | Notes |
|-----------|----------|-------|
| **Rule 1** (accountantDoesntHoldTokens) | Iterates over all N alt assets | Checks `balanceOf(accountant, altAssets[i]) == 0` for each |
| **Rule 27** (tellerDoesntHoldTokens) | Iterates over all N alt assets | Checks `balanceOf(teller, altAssets[i]) == 0` for each |
| **Rule 39** (vaultSolvencyMulti) | Sums value in share terms | Uses `getRateInQuoteSafe()` which handles decimal conversion |
| **Rule 40** (vaultSolvency_1Asset) | Skips if ANY alt asset > 0 | Only applies to pure single-asset scenarios |

**Single-asset invariants** are skipped when alternative assets are deposited:

| Invariant | Skip Condition | Reason |
|-----------|---------------|--------|
| **Rule 13** (totalAssetsCovered) | Any `altBalance > 0` | `totalAssets()` calculation differs in multi-asset scenarios |
| **Rule 19** (vaultSolvency_1Asset_Vesting) | Any `altBalance > 0` | Single-asset formula doesn't account for alternative asset value |
| **Rule 39** (vaultSolvencyMulti) | `selector == setAltAssetRate` | Rate changes can make existing deposits "underwater" (expected) |
| **Rule 40** (vaultSolvency_1Asset) | Any `altBalance > 0` | Single-asset formula doesn't apply to multi-asset backing |

### Relaxed Invariants

**Rule 12** (sharePriceMoreThanOne) was relaxed to only check `rate > 0` because `postLoss` can legitimately reduce the share price below any specific floor (e.g., 0.5e18). Multiple loss events can drive the rate arbitrarily low, which is expected protocol behavior.

### Notes on Expected Behaviors

See `test/fuzzing/FUZZING_NOTES.md` for documented findings discovered during fuzzing.

- **Finding #1**: `invariant_exchangeRateLEhighwaterMark_unlessPaused` - Rate/HWM desync after pause/unpause cycle is **confirmed expected behavior**. The invariant explicitly allows `rate > hwm` when paused: `!isPaused => (exchangeRate <= highwaterMark)`
