/**
 * ABI fragments for DelayedWithdraw.
 * Source: src/base/Roles/DelayedWithdraw.sol
 *
 * DelayedWithdraw is the timelocked withdrawal system. Users request a withdrawal,
 * wait for the maturity window, then complete it. A completion window follows —
 * requests that miss it expire and must be re-submitted.
 */
export const delayedWithdrawAbi = [
  // ── User write functions ───────────────────────────────────────────────
  {
    name: "requestWithdraw",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "asset", type: "address" },
      { name: "shares", type: "uint96" },
      { name: "maxLoss", type: "uint16" },
      { name: "allowThirdPartyToComplete", type: "bool" },
    ],
    outputs: [],
  },
  {
    name: "cancelWithdraw",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [{ name: "asset", type: "address" }],
    outputs: [],
  },
  {
    name: "completeWithdraw",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "asset", type: "address" },
      { name: "account", type: "address" },
    ],
    outputs: [{ name: "assetsOut", type: "uint256" }],
  },
  {
    name: "setAllowThirdPartyToComplete",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "asset", type: "address" },
      { name: "allow", type: "bool" },
    ],
    outputs: [],
  },
  // ── State queries ─────────────────────────────────────────────────────
  {
    name: "isPaused",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    name: "pullFundsFromVault",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "bool" }],
  },
  // withdrawAssets(asset) → WithdrawAsset struct
  {
    name: "withdrawAssets",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "asset", type: "address" }],
    outputs: [
      { name: "allowWithdraws",      type: "bool"    },
      { name: "withdrawDelay",       type: "uint32"  },
      { name: "completionWindow",    type: "uint32"  },
      { name: "outstandingShares",   type: "uint128" },
      { name: "withdrawFee",         type: "uint16"  },
      { name: "maxLoss",             type: "uint16"  },
    ],
  },
  // withdrawRequests(user, asset) → WithdrawRequest struct
  {
    name: "withdrawRequests",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "user",  type: "address" },
      { name: "asset", type: "address" },
    ],
    outputs: [
      { name: "allowThirdPartyToComplete",  type: "bool"   },
      { name: "maxLoss",                    type: "uint16" },
      { name: "maturity",                   type: "uint40" },
      { name: "shares",                     type: "uint96" },
      { name: "exchangeRateAtTimeOfRequest",type: "uint96" },
    ],
  },
  {
    name: "viewOutstandingDebt",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "asset", type: "address" }],
    outputs: [{ name: "debt", type: "uint256" }],
  },
  // ── Events ────────────────────────────────────────────────────────────
  {
    name: "WithdrawRequested",
    type: "event",
    inputs: [
      { name: "account",  type: "address", indexed: true  },
      { name: "asset",    type: "address", indexed: true  },
      { name: "shares",   type: "uint96",  indexed: false },
      { name: "maturity", type: "uint40",  indexed: false },
    ],
  },
  {
    name: "WithdrawCancelled",
    type: "event",
    inputs: [
      { name: "account", type: "address", indexed: true  },
      { name: "asset",   type: "address", indexed: true  },
      { name: "shares",  type: "uint96",  indexed: false },
    ],
  },
  {
    name: "WithdrawCompleted",
    type: "event",
    inputs: [
      { name: "account", type: "address", indexed: true  },
      { name: "asset",   type: "address", indexed: true  },
      { name: "shares",  type: "uint256", indexed: false },
      { name: "assets",  type: "uint256", indexed: false },
    ],
  },
] as const;
