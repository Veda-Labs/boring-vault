/**
 * ABI fragments for BoringVault — the central custody contract.
 * Source: src/base/BoringVault.sol
 */
export const boringVaultAbi = [
  // ── ERC20 ──────────────────────────────────────────────────────────────
  {
    name: "balanceOf",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "totalSupply",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "decimals",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
  {
    name: "allowance",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "approve",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
  // ── Vault core ────────────────────────────────────────────────────────
  {
    name: "enter",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "from", type: "address" },
      { name: "asset", type: "address" },
      { name: "assetAmount", type: "uint256" },
      { name: "to", type: "address" },
      { name: "shareAmount", type: "uint256" },
    ],
    outputs: [],
  },
  {
    name: "exit",
    type: "function",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "asset", type: "address" },
      { name: "assetAmount", type: "uint256" },
      { name: "from", type: "address" },
      { name: "shareAmount", type: "uint256" },
    ],
    outputs: [],
  },
  // ── Events ────────────────────────────────────────────────────────────
  {
    name: "Transfer",
    type: "event",
    inputs: [
      { name: "from", type: "address", indexed: true },
      { name: "to", type: "address", indexed: true },
      { name: "value", type: "uint256", indexed: false },
    ],
  },
  {
    name: "Enter",
    type: "event",
    inputs: [
      { name: "from", type: "address", indexed: true },
      { name: "asset", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
      { name: "to", type: "address", indexed: true },
      { name: "shares", type: "uint256", indexed: false },
    ],
  },
  {
    name: "Exit",
    type: "event",
    inputs: [
      { name: "to", type: "address", indexed: true },
      { name: "asset", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
      { name: "from", type: "address", indexed: true },
      { name: "shares", type: "uint256", indexed: false },
    ],
  },
] as const;
