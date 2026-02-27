# BoringVault Fuzzing Suite

Invariant fuzzing test suite for the BoringVault system using **Foundry** and **Medusa**.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Running Foundry Tests](#running-foundry-tests)
- [Running Medusa Tests](#running-medusa-tests)
- [Invariants Summary](#invariants-summary)
- [Known Issues & Workarounds](#known-issues--workarounds)
- [Assumptions and Simplifications](#assumptions-and-simplifications)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Overview

This suite tests two vault system configurations:

| System | Accountant | Teller | Description |
|--------|------------|--------|-------------|
| **RP** | `AccountantWithRateProviders` | `TellerWithMultiAssetSupport` | Multi-asset support with external rate providers |
| **YS** | `AccountantWithYieldStreaming` | `TellerWithYieldStreaming` | Yield streaming with vesting mechanics |

### Dual Fuzzer Architecture

The suite maintains **two parallel implementations**:

| Fuzzer | Location | Purpose |
|--------|----------|---------|
| **Foundry** | `test/fuzzing/` | Primary suite using Foundry's native invariant testing |
| **Medusa** | `test/fuzzing/medusa/` | Adapted suite for Medusa fuzzer with `require()` assertions |

Key differences between implementations:
- **Assertions**: Foundry uses `assertEq`/`assertGe`/etc., Medusa uses `require()`
- **Cheatcodes**: Medusa doesn't support `deal()`, uses `mint()`/`burn()` instead
- **Setup**: Medusa runs setup in constructor, not `setUp()`

---

## Prerequisites

### Foundry (Required)

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version  # Should be 0.2.0 or higher
```

### Medusa (Optional - for extended fuzzing)

```bash
# Install Medusa via Go (recommended)
go install github.com/crytic/medusa@latest

# Verify installation
medusa --version
```

> **Note**: Medusa requires `crytic-compile`. The `medusa.json` is pre-configured to use Foundry's compilation framework (`--compile-force-framework foundry`) to avoid solc-select network issues.

### Dependencies

```bash
# Install project dependencies
forge install
```

If you encounter git submodule issues (e.g., "already exists in the index" or shallow clone errors):

```bash
# Reset and reinitialize all submodules
git submodule deinit --all -f
git submodule update --init --recursive

# If submodules are still broken, remove and re-add
rm -rf lib/*
git submodule update --init --recursive --force

# For shallow clone issues specifically
git submodule foreach 'git fetch --unshallow || true'
git submodule update --init --recursive
```

---

## Directory Structure

```
test/fuzzing/
├── README.md                       # This file
├── example-foundry.toml            # Config used during initial fuzzing engagement, copy to root
├── example-medusa.toml             # Config used during initial fuzzing engagement, copy to root
├── BaseSetup.sol                   # Shared test infrastructure
├── InvariantTestRP.sol             # Foundry RP system entry point
├── InvariantTestYS.sol             # Foundry YS system entry point
├── handlers/
│   ├── AccountantHandler.sol       # Foundry accountant handlers
│   └── TellerHandler.sol           # Teller operation handlers (shared)
├── invariants/
│   ├── BaseInvariants.sol          # Foundry shared invariants
│   └── YSOnlyInvariants.sol        # Foundry YS-specific invariants
├── mocks/                          # Mock contracts (shared by both suites)
│   ├── MockERC20Extended.sol       # ERC20 with mint/burn and configurable decimals
│   ├── MockRateProvider.sol        # Configurable rate provider
│   └── MockWETH.sol                # WETH mock
└── medusa/                         # Medusa-specific adaptations
    ├── MedusaInvariantTestRP.sol   # Medusa RP system entry point
    ├── MedusaInvariantTestYS.sol   # Medusa YS system entry point
    ├── handlers/
    │   └── AccountantHandler.sol   # Medusa accountant handlers (uses mint/burn)
    └── invariants/
        ├── BaseInvariants.sol      # Medusa shared invariants (uses require())
        └── YSOnlyInvariants.sol    # Medusa YS invariants (uses require())
```

### Why Separate Medusa Folder?

1. **Different assertion styles**: Foundry uses `assertEq()`, Medusa requires `require()`
2. **Different cheatcode support**: Medusa doesn't support `deal()`, requires `mint()`/`burn()`
3. **Isolation**: Keeps both suites independently runnable without conflicts

---

## Running Foundry Tests

### Configuration (`foundry.toml`)

```toml
[invariant]
runs = 256          # Number of test runs
depth = 128         # Call depth per run
fail_on_revert = false
shrink_run_limit = 5000

# Exclude medusa folder (uses require() instead of assert*())
no_match_path = "test/fuzzing/medusa/*"
```

### Commands

```bash
# Run all invariant tests (both RP and YS systems)
forge test --match-contract "InvariantTest" -vvv

# Run only RP system tests
forge test --match-contract "InvariantTestRP" -vvv

# Run only YS system tests
forge test --match-contract "InvariantTestYS" -vvv

# Run with custom depth/runs
forge test --match-contract "InvariantTest" -vvv --invariant-depth 256 --invariant-runs 512

# Quick iteration (reduced coverage)
forge test --match-contract "InvariantTest" --invariant-depth 32 --invariant-runs 64 -vvv
```

---

## Running Medusa Tests

### Configuration (`medusa.json`)

Key settings:

```json
{
  "fuzzing": {
    "workers": 4,
    "timeout": 3600,
    "callSequenceLength": 100,
    "transactionGasLimit": 100000000,
    "targetContracts": ["MedusaInvariantTestRP"],
    "testing": {
      "propertyTesting": {
        "enabled": true,
        "testPrefixes": ["invariant_"]
      }
    }
  },
  "compilation": {
    "platform": "crytic-compile",
    "platformConfig": {
      "args": ["--foundry-out-directory", "out", "--foundry-compile-all", "--compile-force-framework", "foundry"]
    }
  }
}
```

### Switching Target Systems

Medusa can only target **one contract at a time** (it mixes state between multiple targets). Edit `medusa.json`:

```json
// For RP system:
"targetContracts": ["MedusaInvariantTestRP"]

// For YS system:
"targetContracts": ["MedusaInvariantTestYS"]
```

### Commands

```bash
# Ensure project compiles first
forge build

# Run Medusa fuzzer (uses medusa.json config)
medusa fuzz

# Run for specific duration (seconds)
medusa fuzz --timeout 7200  # 2 hours

# Run with more workers
medusa fuzz --workers 8
```

### Generated Files

Medusa generates the following (gitignored):

| Directory/File | Purpose |
|----------------|---------|
| `medusa-corpus/` | Saved inputs that increased coverage |
| `medusa-logs/` | Detailed execution logs |
| `crytic-export/` | Compilation artifacts |

---

## Invariants Summary

### Group 1: Accountant Properties (Both Systems)

| Rule | Invariant | Description |
|------|-----------|-------------|
| 1 | `accountantDoesntHoldTokens` | Accountant never holds tokens |
| 2 | `accountantPaused_valuesFrozen` | When paused, fees only change via `resetHighwaterMark` |
| 3 | `feesCanOnlyDecreaseViaClaimFees` | Fees decrease only via `claimFees` |
| 4 | `highwaterMarkNeverDecreases` | HWM never decreases except via reset |
| 5 | `lastUpdateTimestampNeverDecreases` | Timestamp monotonically increases |
| 6 | `allowedExchangeRateChangeBounds` | Rate bounds are valid (upper >= 100%, lower <= 100%) |
| 7 | `exchangeRateLEhighwaterMark` | After successful update: rate <= HWM |

### Group 2: YS-Specific Properties

| Rule | Invariant | Description |
|------|-----------|-------------|
| 8 | `cumulativeSupplyBounded` | Cumulative supply tracking is monotonic |
| 9 | `exchangeRateEqlastSharePrice` | After sync ops: rate == lastSharePrice |
| 10-11 | `sharePriceBounded{Upper,Lower}` | Share price within expected bounds |
| 12 | `sharePriceMoreThanOne` | Rate > 0 when assets exist |
| 13 | `totalAssetsCovered` | totalAssets <= vaultBalance |
| 14 | `startVestingTimeLEendVestingTime` | startTime <= endTime (see [Finding 1](#finding-1-setfirstdeposittimestamp-bug-ys-system)) |
| 15 | `vestingGainsIntegrity` | vestingGains > 0 implies startTime < endTime |
| 16-17 | `lastVestingUpdate*` | Vesting timestamp monotonicity |
| 18 | `exchangeRatePostLoss` | After postLoss: rate <= HWM |
| 19 | `vaultSolvency_1Asset_Vesting` | Solvency with pending vesting gains |

### Group 3: Teller & Vault Properties

| Rule | Invariant | Description |
|------|-----------|-------------|
| 20 | `integrityOfDeposit` | Deposit mints shares proportionally |
| 21 | `integrityOfWithdraw` | Withdraw returns assets |
| 22 | `noFreeAssets` | Round-trip doesn't create value |
| 23 | `tellerDoesntHoldTokens` | Teller never holds tokens |
| 24 | `vaultCannotChange` | Teller.vault is immutable |
| 25 | `depositNonceNeverGoesDown` | Nonce monotonically increases |
| 26-27 | `tellerPaused_*` | Paused state behavior |
| 28 | `dustFavorsTheHouse` | Rounding favors protocol |

### Group 4: Math & Permissions

| Rule | Invariant | Description |
|------|-----------|-------------|
| 36-37 | `deniedUsers_balance*` | Deny list enforcement |
| 38-39 | `vaultSolvency*` | Single and multi-asset solvency |
| 40-47 | `conversion*` | Math conversion properties |

---

## Known Issues & Workarounds

### Finding 1: `setFirstDepositTimestamp` Bug (YS System)

**Status**: Open (Handler Workaround Applied)  
**Invariant**: Rule 14 - `startVestingTimeLEendVestingTime`  
**Severity**: Info

#### Description

A combination of two issues creates an invalid vesting state where `startVestingTime > endVestingTime`:

1. `_updateExchangeRate()` doesn't clear `vestingGains` when `totalSupply == 0`
2. `setFirstDepositTimestamp()` only updates `startVestingTime`, leaving stale `endVestingTime`

#### Reproduction Sequence

```
1. depositYS       → creates shares
2. vestYield       → sets vestingGains, startTime, endTime
3. warpTime(huge)  → time passes endTime
4. withdrawYS(all) → totalSupply = 0, vestingGains NOT cleared
5. warpTime        → more time passes
6. bulkDepositYS   → triggers setFirstDepositTimestamp
                     startTime = now (large), endTime = old (small)
                     Result: startTime > endTime
```

#### Handler Workaround

The fuzzing handlers work around this bug:

1. **`TellerHandler.depositYS()`**: Tracks if vault was empty before deposit
2. **`AccountantHandler.fixVestingStateAfterFirstDeposit()`**: Called after deposit to empty vault, performs a minimal `vestYield` to reset timestamps

```solidity
// In TellerHandler.depositYS():
bool vaultWasEmpty = vaultYS.totalSupply() == 0;
// ... deposit ...
if (vaultWasEmpty && succeeded) {
    accountantHandler.fixVestingStateAfterFirstDeposit();
}
```

#### Suggested Source Contract Fix

```solidity
function setFirstDepositTimestamp() external requiresAuth {
    vestingState.startVestingTime = uint64(block.timestamp);
    if (vestingState.endVestingTime < block.timestamp) {
        vestingState.endVestingTime = uint64(block.timestamp);
        vestingState.vestingGains = 0;  // Clear stale gains
    }
}
```

### Finding 2: `uint128` Truncation in Virtual Share Price (YS System)

**Status**: Open (Invariant Skip Applied)  
**Invariant**: Rule 36 - `virtualPriceUpperBound`  
**Severity**: Info (Edge Case)

#### Description

When `lastVirtualSharePrice` becomes extremely large (after vesting large yields with very few shares), the `uint128` cast in `_calculateSharePriceFromVirtual()` silently truncates the value, causing `lastSharePrice` to diverge from the true converted virtual price.

#### Impact

- Edge case only: Requires extreme conditions (very large yield, very few shares)
- Silent truncation can cause ~500x difference between values
- Unlikely in production but could affect accounting precision

#### Invariant Skip

The virtual price invariants (Rules 36-37) now skip when `convertedPrice > type(uint128).max`:

```solidity
uint256 convertedPrice = virtualPrice.mulDivDown(ONE_SHARE, RAY);
if (convertedPrice > type(uint128).max) return true;
```

See `FINDINGS.md` for full details.

---

## Assumptions and Simplifications

### System Configuration
- One Teller per Vault (multiple Tellers not tested)
- `BoringVault.manage()` is never called (strategist operations excluded)
- Roles (`owner`, `strategist`, `solver`) are pre-configured and immutable

### Asset Configuration
- Base asset: 18 decimals
- Alternative assets: varying decimals (6, 8, 11, 18) to test decimal diversity
- Mock contracts used for assets and rate providers
- **Rate provider rates bounded: 50% to 200% of base rate** (realistic range to avoid rounding edge cases)

### Bounds
- Deposit/withdrawal amounts: 1 wei to 100,000 tokens
- Exchange rates: 0.001 to 1000 tokens per share
- Time warps: 1 second to 365 days
- Vesting durations: 1 hour to 90 days

### Contract Linking
```
Teller.vault        == BoringVault
BoringVault.hook    == Teller
Teller.accountant   == Accountant
Accountant.vault    == BoringVault
```

---

## Troubleshooting

### Foundry Issues

**Tests timeout with no output**
```bash
# Reduce depth and runs for faster iteration
forge test --match-contract "InvariantTest" --invariant-depth 32 --invariant-runs 64 -vvv
```

**Stack too deep errors**
- The handlers use minimal state structs to avoid this
- If modifying, keep snapshot functions simple

### Medusa Issues

**solc-select HTTP 403 error**
```
error while executing `solc-select install`:
urllib.error.HTTPError: HTTP Error 403: Forbidden
```

This is a known issue with solc-select's network calls. The `medusa.json` is already configured to bypass this using `--compile-force-framework foundry`. If you still encounter it:

```bash
# Ensure Foundry compiles successfully first
forge build

# Clear any stale Medusa artifacts
rm -rf medusa-corpus medusa-logs crytic-export

# Re-run Medusa
medusa fuzz
```

**Invariants all reverting with `address(0)` calls**

This indicates the constructor setup didn't run. Ensure:
1. Target contract has setup logic in `constructor()` (not just `setUp()`)
2. `medusa.json` targets the correct contract name (e.g., `MedusaInvariantTestRP`)
3. Run `forge build` before `medusa fuzz`

**State mixing between RP and YS tests**

Medusa doesn't isolate state between multiple target contracts. Always target **one contract at a time**:

```json
// CORRECT - single target
"targetContracts": ["MedusaInvariantTestRP"]

// INCORRECT - will cause state mixing
"targetContracts": ["MedusaInvariantTestRP", "MedusaInvariantTestYS"]
```

### Debug a Failing Sequence

```bash
# Foundry - verbose output
forge test --match-contract "InvariantTestYS" -vvvvv

# Medusa - check logs
tail -100 medusa-logs/log-*.log
```

---

## Contributing

### Adding New Invariants

1. Add the invariant function to appropriate file:
   - `invariants/BaseInvariants.sol` for shared invariants
   - `invariants/YSOnlyInvariants.sol` for YS-specific invariants
2. If adding Medusa support, also update:
   - `medusa/invariants/BaseInvariants.sol` (convert `assert*()` to `require()`)
   - `medusa/invariants/YSOnlyInvariants.sol`
3. Update this README with invariant documentation
4. Run full fuzzing suite to verify no regressions

### Adding New Handlers

1. Add handler function to `handlers/AccountantHandler.sol` or `handlers/TellerHandler.sol`
2. Register the handler in `InvariantTestRP.sol` / `InvariantTestYS.sol`
3. If Medusa support needed:
   - Update `medusa/handlers/AccountantHandler.sol` (replace `deal()` with `mint()`/`burn()`)
   - The `TellerHandler.sol` is shared (no Medusa-specific version needed)

### Handler Selectors

**RP System (31 selectors)**:
- Deposits: `depositMAS`, `bulkDepositMAS`, `depositAltMAS`, `depositTinyMAS`, `depositNearCapMAS`
- Withdrawals: `withdrawMAS`, `bulkWithdrawMAS`, `withdrawAltMAS`, `withdrawLockedMAS`, `withdrawZeroMinMAS`
- Admin: `pauseMAS`, `unpauseMAS`, `setShareLockPeriodMAS`, `setDepositCapMAS`, `updateAssetDataMAS`
- Deny List: `denyUserMAS`, `allowUserMAS`, `denyFromMAS`, `denyToMAS`, `allowFromMAS`, `allowToMAS`
- Accountant: `updateExchangeRateRP`, `claimFeesRP`, `pauseRP`, `unpauseRP`, `setAltAssetRate`

**YS System (16 selectors)**:
- Deposits: `depositYS`, `bulkDepositYS`
- Withdrawals: `withdrawYS`, `bulkWithdrawYS`
- Admin: `pauseYS`, `unpauseYS`
- Yield: `vestYield`, `postLoss`, `updateExchangeRateYS`, `updateVestingParams`
- Time: `warpTime`
- Accountant: `claimFeesYS`, `resetHighwaterMarkYS`

---

## Verification Notations

| Status | Meaning |
|--------|---------|
| **Fuzz Verified** | Invariant held across all fuzz runs with no violations |
| **Fuzz Verified (Workaround)** | Invariant held after handler-level workaround for known source bug |
| **Conditionally Verified** | Invariant holds under documented preconditions |
| **Violated** | Counter-example found exposing a bug (documented in FINDINGS.md) |

### Conditionally Verified Invariants

| Rule | Condition | Reason |
|------|-----------|--------|
| 7 | Only after successful `updateExchangeRate` | Rate/HWM relationship only guaranteed after successful updates |
| 9 | Only after sync operations | `exchangeRate` and `lastSharePrice` diverge between syncs |
| 13, 19 | Skip after fee claims | Fee extraction temporarily breaks accounting until next sync |
| 36-37 | Skip when `convertedPrice > uint128.max` | Protocol truncation causes divergence (see Finding 2) |
| 38-39 | Skip after fee claims or rate changes | Temporary valuation mismatches |

---

## License

MIT
