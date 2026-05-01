/**
 * ABI fragments for ArcticArchitectureLens.
 * Source: src/helper/ArcticArchitectureLens.sol
 *
 * The Lens contract provides read-only, gas-optimised views over the
 * BoringVault system so frontends can avoid multiple separate calls.
 */
export const lensAbi = [
  // ── TVL & pricing ─────────────────────────────────────────────────────
  {
    name: "totalAssets",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "boringVault", type: "address" },
      { name: "accountant", type: "address" },
    ],
    outputs: [
      { name: "asset", type: "address" },
      { name: "assets", type: "uint256" },
    ],
  },
  {
    name: "exchangeRate",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "accountant", type: "address" }],
    outputs: [{ name: "rate", type: "uint256" }],
  },
  // ── User position ─────────────────────────────────────────────────────
  {
    name: "balanceOf",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "account", type: "address" },
      { name: "boringVault", type: "address" },
    ],
    outputs: [{ name: "shares", type: "uint256" }],
  },
  {
    name: "balanceOfInAssets",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "account", type: "address" },
      { name: "boringVault", type: "address" },
      { name: "accountant", type: "address" },
    ],
    outputs: [{ name: "assets", type: "uint256" }],
  },
  {
    name: "userUnlockTime",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "account", type: "address" },
      { name: "teller", type: "address" },
    ],
    outputs: [{ name: "unlockTime", type: "uint256" }],
  },
  // ── Deposit pre-flight ─────────────────────────────────────────────────
  {
    name: "previewDeposit",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "depositAsset", type: "address" },
      { name: "depositAmount", type: "uint256" },
      { name: "boringVault", type: "address" },
      { name: "accountant", type: "address" },
    ],
    outputs: [{ name: "shares", type: "uint256" }],
  },
  {
    name: "checkUserDeposit",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "account", type: "address" },
      { name: "depositAsset", type: "address" },
      { name: "depositAmount", type: "uint256" },
      { name: "boringVault", type: "address" },
      { name: "teller", type: "address" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  // ── Teller state ──────────────────────────────────────────────────────
  {
    name: "isTellerPaused",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "teller", type: "address" }],
    outputs: [{ name: "", type: "bool" }],
  },
  // ── Withdrawal preview (DelayedWithdraw) ──────────────────────────────
  // Returns PreviewWithdrawResult struct — field order matches Solidity exactly.
  {
    name: "previewWithdraw",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "asset",          type: "address" },
      { name: "account",        type: "address" },
      { name: "boringVault",    type: "address" },
      { name: "accountant",     type: "address" },
      { name: "delayedWithdraw",type: "address" },
    ],
    outputs: [
      {
        name: "res",
        type: "tuple",
        components: [
          { name: "assetsOut",                type: "uint256" },
          { name: "withdrawsNotAllowed",       type: "bool"    },
          { name: "withdrawNotMatured",        type: "bool"    },
          { name: "noShares",                  type: "bool"    },
          { name: "maxLossExceeded",           type: "bool"    },
          { name: "notEnoughAssetsForWithdraw",type: "bool"    },
        ],
      },
    ],
  },
] as const;
