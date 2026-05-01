# @boring-vault/sdk

TypeScript SDK for interacting with the BoringVault system. Pure [viem](https://viem.sh) — no framework lock-in, works with wagmi, React, Node scripts, or anything else.

---

## Contract Architecture

The BoringVault system is made up of several cooperating contracts. Understanding them helps you pick the right SDK function.

```
┌─────────────────────────────────────────────────────────┐
│                      BoringVault                        │
│  ERC20 share token + custody contract. Holds all assets │
│  on behalf of depositors. Shares mirror base asset      │
│  decimals (8 for BTC-denominated, 18 for ETH).          │
└──────────┬──────────────────────────┬───────────────────┘
           │                          │
    ┌──────▼──────┐           ┌───────▼────────┐
    │   Teller    │           │   Accountant   │
    │             │           │                │
    │ Handles all │           │ Tracks share   │
    │ deposits.   │           │ price via an   │
    │ Enforces    │           │ exchange rate. │
    │ share lock  │           │ Source of      │
    │ period.     │           │ truth for TVL  │
    │ Supports    │           │ and APY.       │
    │ EIP-2612    │           │                │
    │ permit.     │           └────────────────┘
    └─────────────┘

┌─────────────────────────────────────────────────────────┐
│                   Withdrawal Queues                     │
│                                                         │
│  AtomicQueue (older vaults)                             │
│    Users submit a request with a min price. Off-chain   │
│    solvers fill it when the price is met.               │
│                                                         │
│  BoringOnChainQueue (vaults after mid-2025)             │
│    Users submit a request with a discount in BPS.       │
│    An on-chain BoringSolver fills it — no off-chain     │
│    infrastructure needed.                               │
│                                                         │
│  DelayedWithdraw (time-locked vaults)                   │
│    User locks shares, waits a maturity window, then     │
│    completes the withdrawal. A completion window        │
│    follows — requests that expire must be resubmitted.  │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│               ArcticArchitectureLens                    │
│  Read-only helper contract. Batches common queries into │
│  a single call (TVL, user position, deposit pre-flight, │
│  delayed withdraw preview).                             │
└─────────────────────────────────────────────────────────┘
```

### Contract source files

| Contract | Source |
|---|---|
| `BoringVault` | `src/base/BoringVault.sol` |
| `AccountantWithRateProviders` | `src/base/Roles/AccountantWithRateProviders.sol` |
| `TellerWithMultiAssetSupport` | `src/base/Roles/TellerWithMultiAssetSupport.sol` |
| `AtomicQueue` | `src/atomic-queue/AtomicQueue.sol` |
| `BoringOnChainQueue` | `src/base/Roles/BoringQueue/BoringOnChainQueue.sol` |
| `DelayedWithdraw` | `src/base/Roles/DelayedWithdraw.sol` |
| `ArcticArchitectureLens` | `src/helper/ArcticArchitectureLens.sol` |

---

## Setup

### Prerequisites

- Node.js ≥ 20
- npm / pnpm / yarn

### Install

```bash
cd sdk
npm install
```

`viem ^2.0.0` is a peer dependency — install it in the consuming project if it isn't already:

```bash
npm install viem
```

### Build (compile to `dist/`)

```bash
npm run build
```

### Type-check without emitting

```bash
npm run typecheck
```

---

## Quick Start

```ts
import { createPublicClient, http } from "viem";
import { mainnet } from "viem/chains";
import { fetchTVL, getSharePrice, getUserPosition } from "@boring-vault/sdk";

const client = createPublicClient({
  chain: mainnet,
  transport: http("https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"),
});

const VAULT     = "0x..." as const; // BoringVault address
const ACCOUNTANT = "0x..." as const; // AccountantWithRateProviders address
const USER      = "0x..." as const; // wallet address

const [tvl, price, position] = await Promise.all([
  fetchTVL(client, VAULT, ACCOUNTANT),
  getSharePrice(client, ACCOUNTANT),
  getUserPosition(client, USER, VAULT, ACCOUNTANT),
]);

console.log(`TVL: ${tvl.formatted}`);
console.log(`Share price: ${price.formatted}`);
console.log(`Your position: ${position.sharesFormatted} shares ≈ ${position.assetsFormatted}`);
```

---

## API Reference

### Vault reads (`vault.ts`)

#### `fetchTVL(client, vaultAddress, accountantAddress)`

Returns the total value locked in the vault.

```ts
const tvl = await fetchTVL(client, vaultAddr, accountantAddr);
// tvl.raw        → bigint (in base asset decimals)
// tvl.formatted  → "4,231.8700"
// tvl.baseAsset  → "0x..." (base asset address)
```

#### `getSharePrice(client, accountantAddress)`

Returns the current exchange rate from the Accountant.

```ts
const price = await getSharePrice(client, accountantAddr);
// price.rate       → bigint
// price.formatted  → "1.042100"
// price.timestamp  → unix seconds of last update (0 if unavailable)
```

#### `getVaultStatus(client, accountantAddress)`

Returns `"active"` or `"paused"`. Use this to show a pause banner.

```ts
const status = await getVaultStatus(client, accountantAddr);
if (status === "paused") showBanner("Deposits temporarily paused");
```

#### `getLastRebalanceTimestamp(client, accountantAddress)`

Returns the unix timestamp (seconds) of the last exchange rate update.

```ts
const ts = await getLastRebalanceTimestamp(client, accountantAddr);
const hoursAgo = Math.floor((Date.now() / 1000 - ts) / 3600);
```

#### `getStrategyAllocations(client, vaultAddress, positions)`

Queries each position in your config and returns live on-chain balances and percentages. Supports `erc20`, `erc4626`, and `morpho-blue` position types.

```ts
import type { StrategyPosition } from "@boring-vault/sdk";

const positions: StrategyPosition[] = [
  { type: "erc20",   protocol: "Aave v3",  tokenAddress: "0x4d5f..." },
  { type: "erc4626", protocol: "Euler",    vaultAddress: "0xd8b2..." },
  { type: "morpho-blue", protocol: "Morpho", morphoAddress: "0xBBBB...", marketId: "0xabc..." },
];

const allocations = await getStrategyAllocations(client, vaultAddr, positions);
// [{ protocol: "Aave v3", percentage: 62.4, balance: 4200000n }, ...]
```

#### `discoverStrategyAllocations(client, vaultAddress, fromBlock, toBlock)`

Auto-discovers strategies by scanning Transfer events — no config needed. Useful when you don't know the vault's positions in advance.

```ts
const latest = await client.getBlockNumber();
const allocations = await discoverStrategyAllocations(client, vaultAddr, 19_000_000n, latest);
```

---

### User position reads (`user.ts`)

#### `getUserPosition(client, userAddress, vaultAddress, accountantAddress)`

Returns share balance and asset-equivalent value for a wallet.

```ts
const pos = await getUserPosition(client, user, vault, accountant);
// pos.shares          → bigint
// pos.sharesFormatted → "10.5000"
// pos.assetsValue     → bigint
// pos.assetsFormatted → "10.5000"
```

#### `getUnlockTime(client, userAddress, tellerAddress)`

Returns the `Date` after which the user's shares are transferable, or `null` if already unlocked.

```ts
const unlock = await getUnlockTime(client, user, teller);
if (unlock) console.log(`Shares unlock at ${unlock.toLocaleString()}`);
```

#### `getWithdrawalRequests(client, queueType, queueAddress, userAddress, offerToken, wantTokens)`

Fetches active withdrawal requests from either queue type.

```ts
// AtomicQueue
const requests = await getWithdrawalRequests(
  client, "atomic", atomicQueueAddr, user, vaultAddr, [usdcAddr, wethAddr]
);

// BoringOnChainQueue (scans last ~50k blocks)
const requests = await getWithdrawalRequests(
  client, "boring-onchain", boringQueueAddr, user, vaultAddr, []
);
```

#### `getDelayedWithdrawRequest(client, delayedWithdrawAddress, userAddress, asset)`

Reads a user's pending delayed withdrawal request and the asset's config in one call. Returns `null` for `request` when no active request exists.

```ts
const { request, assetConfig } = await getDelayedWithdrawRequest(
  client, delayedWithdrawAddr, user, wethAddr
);

if (request) {
  const ready = Date.now() / 1000 >= request.maturity;
  console.log(`${request.shares} shares, ${ready ? "ready to complete" : "still maturing"}`);
  console.log(`Withdraw fee: ${assetConfig.withdrawFee / 100}%`);
}
```

---

### Transaction builders (`transactions.ts`)

All builders return a `TransactionRequest` (`{ to, data, value }`) — pass it directly to `walletClient.sendTransaction()` or wagmi's `writeContract`.

#### `buildDepositTx(params)`

```ts
import { parseUnits } from "viem";

const tx = buildDepositTx({
  boringVault:    "0x...",
  teller:         "0x...",
  depositAsset:   usdcAddress,
  depositAmount:  parseUnits("1000", 6),
  minimumMint:    parseUnits("990", 18),   // slippage protection
  referralAddress: "0x...",               // optional, omit or pass zero address
});

await walletClient.sendTransaction(tx);
```

> The user must have approved the Teller contract to spend `depositAsset` first.

#### `buildDepositWithPermitTx(params)`

No prior `approve()` needed — the EIP-2612 permit is bundled in the calldata.

```ts
const { v, r, s } = await signPermit({ ... }); // sign with walletClient.signTypedData

const tx = buildDepositWithPermitTx({
  ...depositParams,
  deadline: BigInt(Math.floor(Date.now() / 1000) + 3600),
  v, r, s,
});
```

#### `buildWithdrawalRequestTx(params)`

Handles both queue types via a discriminated union on `queueType`.

```ts
// AtomicQueue — set min price per share
const tx = buildWithdrawalRequestTx({
  queueType:    "atomic",
  atomicQueue:  atomicQueueAddr,
  offerToken:   vaultAddr,
  wantToken:    usdcAddr,
  offerAmount:  parseUnits("10", 18),
  atomicPrice:  parseUnits("9.9", 6) * 10n ** 12n, // scaled to 1e18
  deadline:     BigInt(Math.floor(Date.now() / 1000) + 86400),
});

// BoringOnChainQueue — set discount in BPS
const tx = buildWithdrawalRequestTx({
  queueType:        "boring-onchain",
  boringQueue:      boringQueueAddr,
  assetOut:         lbtcAddr,
  amountOfShares:   parseUnits("10", 8),
  discount:         100,        // 1% discount from share price
  secondsToDeadline: 86400,
});
```

#### Delayed withdraw builders

```ts
// 1. Lock shares for withdrawal
const tx = buildDelayedWithdrawRequestTx({
  delayedWithdraw:         delayedWithdrawAddr,
  asset:                   wethAddr,
  shares:                  parseUnits("5", 18),
  maxLoss:                 50,     // 0.5% — use 0 to inherit asset global
  allowThirdPartyToComplete: false,
});

// 2. After maturity — complete the withdrawal
const tx = buildCompleteDelayedWithdrawTx(delayedWithdrawAddr, wethAddr, userAddr);

// 3. Cancel before maturity (shares returned)
const tx = buildCancelDelayedWithdrawTx(delayedWithdrawAddr, wethAddr);
```

#### `validateDeposit(client, params)`

Pre-flight check — returns `{ valid: true }` or `{ valid: false, reason }` without submitting anything.

```ts
const result = await validateDeposit(client, {
  boringVault:   vaultAddr,
  teller:        tellerAddr,
  depositAsset:  usdcAddr,
  depositAmount: parseUnits("1000", 6),
  userAddress:   user,
});

if (!result.valid) {
  // reason: "teller_paused" | "asset_not_supported" |
  //         "insufficient_balance" | "insufficient_allowance"
  console.error(result.reason);
}
```

#### `simulateDeposit(client, params)`

Previews how many shares a deposit would mint without sending a transaction.

```ts
const sim = await simulateDeposit(client, {
  depositAsset:  lbtcAddr,
  depositAmount: parseUnits("0.1", 8),
  boringVault:   vaultAddr,
  accountant:    accountantAddr,
});

if (sim.wouldSucceed) {
  console.log(`Would receive ${formatUnits(sim.sharesOut, 8)} shares`);
}
```

---

### Analytics (`analytics.ts`)

#### `getExchangeRateHistory(client, accountantAddress, fromBlock, toBlock, decimals?)`

Fetches historical exchange rates from `ExchangeRateUpdated` events. Capped at 500k blocks per call to stay within free-tier RPC limits.

```ts
const latest = await client.getBlockNumber();
const history = await getExchangeRateHistory(client, accountantAddr, latest - 200_000n, latest);
// [{ timestamp, rate, rateFormatted, blockNumber }, ...]
```

#### `getTVLHistory(client, vaultAddress, fromBlock, toBlock, decimals?)`

Reconstructs TVL over time from `Enter`/`Exit` events. Returns share-count history — multiply by share price to get dollar-denominated TVL.

```ts
const tvlHistory = await getTVLHistory(client, vaultAddr, latest - 200_000n, latest);
```

#### `estimateAPY(rateHistory, windowDays)`

Computes compound APY from a rate history array. Pass `7` or `30` for the lookback window.

```ts
const history = await getExchangeRateHistory(client, accountantAddr, from, to);
const apy30d  = estimateAPY(history, 30);
console.log(`30-day APY: ${(apy30d * 100).toFixed(2)}%`);
```

---

## ABI-only imports

The ABI objects are also exported directly for use with viem's `readContract` / `writeContract` or any other tool:

```ts
import {
  boringVaultAbi,
  accountantAbi,
  tellerAbi,
  atomicQueueAbi,
  boringOnChainQueueAbi,
  delayedWithdrawAbi,
  lensAbi,
} from "@boring-vault/sdk/abis"; // or import individually from "./abis/accountant.js" etc.
```

---

## Types

All public types are re-exported from the root entry point:

```ts
import type {
  // Vault state
  TVLResult, SharePrice, VaultStatus, StrategyAllocation, StrategyPosition,
  Erc20Position, Erc4626Position, MorphoBluePosition,

  // User
  UserPosition, WithdrawalRequest,
  DelayedWithdrawRequest, DelayedWithdrawAsset, PreviewWithdrawResult,

  // Transactions
  DepositParams, DepositWithPermitParams,
  WithdrawalRequestParams, AtomicWithdrawalRequestParams, OnChainWithdrawalRequestParams,
  DelayedWithdrawRequestParams, TransactionRequest,
  DepositValidationResult, SimulateDepositResult,

  // Analytics
  RatePoint, TVLPoint,
} from "@boring-vault/sdk";
```

---

## Notes

- **RPC requirements** — `discoverStrategyAllocations`, `getExchangeRateHistory`, and `getTVLHistory` use `eth_getLogs`. Public RPCs often throttle broad log queries; use Alchemy or Infura for reliable results.
- **Share decimals** — BoringVault shares mirror the base asset decimals (e.g. 8 for BTC-denominated vaults, 18 for ETH). Do not hardcode 18.
- **`referralAddress`** — optional on deposit functions. Pass `undefined` or omit it; the SDK defaults to the zero address.
- **Permit signing** — `buildDepositWithPermitTx` expects a pre-computed `(v, r, s)`. Use viem's [`signTypedData`](https://viem.sh/docs/actions/wallet/signTypedData) with the EIP-2612 domain to generate them.
