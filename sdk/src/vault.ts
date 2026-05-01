/**
 * Vault-level read functions for BoringVault state.
 *
 * Every function is independently importable and tree-shakeable.
 * All contract interaction uses viem — no framework dependencies.
 */

import type { Address, PublicClient } from "viem";
import { formatUnits, parseAbiItem } from "viem";

import { accountantAbi } from "./abis/accountant.js";
import { boringVaultAbi } from "./abis/boringVault.js";
import type { TVLResult, SharePrice, VaultStatus, StrategyAllocation, StrategyPosition } from "./types.js";

// ── Minimal ABIs for strategy position queries ────────────────────────────

const erc20BalanceAbi = [
  {
    name: "balanceOf",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

const erc4626Abi = [
  {
    name: "balanceOf",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    name: "convertToAssets",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "shares", type: "uint256" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

// Morpho Blue: position(Id, address) → (supplyShares, borrowShares, collateral)
// market(Id) → (totalSupplyAssets, totalSupplyShares, ...)
const morphoBlueAbi = [
  {
    name: "position",
    type: "function",
    stateMutability: "view",
    inputs: [
      { name: "id", type: "bytes32" },
      { name: "user", type: "address" },
    ],
    outputs: [
      { name: "supplyShares", type: "uint256" },
      { name: "borrowShares", type: "uint128" },
      { name: "collateral", type: "uint256" },
    ],
  },
  {
    name: "market",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "id", type: "bytes32" }],
    outputs: [
      { name: "totalSupplyAssets", type: "uint128" },
      { name: "totalSupplyShares", type: "uint128" },
      { name: "totalBorrowAssets", type: "uint128" },
      { name: "totalBorrowShares", type: "uint128" },
      { name: "lastUpdate", type: "uint128" },
      { name: "fee", type: "uint128" },
    ],
  },
] as const;

/**
 * Fetches the total value locked in the vault.
 *
 * @param publicClient - viem PublicClient connected to the target chain
 * @param vaultAddress - BoringVault contract address
 * @param accountantAddress - AccountantWithRateProviders contract address
 * @returns TVL in raw bigint and human-readable formatted string
 *
 * @example
 * ```ts
 * import { createPublicClient, http } from "viem";
 * import { mainnet } from "viem/chains";
 * import { fetchTVL } from "@boring-vault/sdk/vault";
 *
 * const client = createPublicClient({ chain: mainnet, transport: http() });
 * const tvl = await fetchTVL(client, vaultAddr, accountantAddr);
 * console.log(tvl.formatted); // "4,231.87"
 * ```
 */
export async function fetchTVL(
  publicClient: PublicClient,
  vaultAddress: Address,
  accountantAddress: Address
): Promise<TVLResult> {
  const [totalSupply, rate, baseAsset, decimals] = await Promise.all([
    publicClient.readContract({
      address: vaultAddress,
      abi: boringVaultAbi,
      functionName: "totalSupply",
    }),
    publicClient.readContract({
      address: accountantAddress,
      abi: accountantAbi,
      functionName: "getRate",
    }),
    publicClient.readContract({
      address: accountantAddress,
      abi: accountantAbi,
      functionName: "base",
    }),
    publicClient.readContract({
      address: accountantAddress,
      abi: accountantAbi,
      functionName: "decimals",
    }),
  ]);

  // BoringVault shares mirror base asset decimals (e.g. 8 for BTC).
  // Divide by 10^decimals, NOT 10^18 — dividing by 1e18 truncates to 0 for small BTC amounts.
  const rawAssets = (totalSupply * rate) / BigInt(10 ** decimals);
  const tvlFloat = Number(formatUnits(rawAssets, decimals));
  const formatted = tvlFloat.toLocaleString("en-US", {
    minimumFractionDigits: 4,
    maximumFractionDigits: 6,
  });

  return { raw: rawAssets, formatted, baseAsset };
}

/**
 * Returns the current share price from the Accountant.
 *
 * @param publicClient - viem PublicClient
 * @param accountantAddress - AccountantWithRateProviders address
 * @returns Current share price with timestamp
 *
 * @example
 * ```ts
 * const price = await getSharePrice(client, accountantAddr);
 * console.log(price.formatted); // "1.0421"
 * ```
 */
export async function getSharePrice(
  publicClient: PublicClient,
  accountantAddress: Address
): Promise<SharePrice> {
  const [rate, decimals] = await Promise.all([
    publicClient.readContract({
      address: accountantAddress,
      abi: accountantAbi,
      functionName: "getRate",
    }),
    publicClient.readContract({
      address: accountantAddress,
      abi: accountantAbi,
      functionName: "decimals",
    }),
  ]);

  // accountantState is optional — fetch it separately so a failure doesn't block the price
  let timestamp = 0;
  try {
    const state = await publicClient.readContract({
      address: accountantAddress,
      abi: accountantAbi,
      functionName: "accountantState",
    });
    timestamp = Number(state[7]); // lastUpdateTimestamp (index 7 in 12-field struct)
  } catch {
    // accountantState ABI may differ across contract versions — timestamp degrades to 0
  }

  const formatted = Number(formatUnits(rate, decimals)).toFixed(6);
  return { rate, formatted, timestamp };
}

/**
 * Checks whether the vault is active (accepting deposits) or paused.
 * Reads the isPaused flag from the Accountant state.
 *
 * @param publicClient - viem PublicClient
 * @param accountantAddress - AccountantWithRateProviders address
 * @returns "active" or "paused"
 *
 * @example
 * ```ts
 * const status = await getVaultStatus(client, accountantAddr);
 * if (status === "paused") showPauseBanner();
 * ```
 */
export async function getVaultStatus(
  publicClient: PublicClient,
  accountantAddress: Address
): Promise<VaultStatus> {
  try {
    const state = await publicClient.readContract({
      address: accountantAddress,
      abi: accountantAbi,
      functionName: "accountantState",
    });
    return state[8] ? "paused" : "active"; // index 8 in 12-field struct
  } catch {
    return "active";
  }
}

/**
 * Returns the Unix timestamp (seconds) of the last exchange rate update,
 * which corresponds to the most recent vault rebalance trigger.
 *
 * @param publicClient - viem PublicClient
 * @param accountantAddress - AccountantWithRateProviders address
 * @returns Unix timestamp in seconds
 *
 * @example
 * ```ts
 * const ts = await getLastRebalanceTimestamp(client, accountantAddr);
 * const ago = Date.now() / 1000 - ts;
 * console.log(`Last rebalance ${Math.floor(ago / 3600)}h ago`);
 * ```
 */
export async function getLastRebalanceTimestamp(
  publicClient: PublicClient,
  accountantAddress: Address
): Promise<number> {
  try {
    const state = await publicClient.readContract({
      address: accountantAddress,
      abi: accountantAbi,
      functionName: "accountantState",
    });
    return Number(state[7]); // index 7 in 12-field struct
  } catch {
    return 0;
  }
}

/**
 * Returns the live on-chain strategy allocation breakdown for the vault.
 *
 * Queries each position defined in the `strategyPositions` config and resolves
 * their current asset balances directly from the relevant protocol contracts:
 *
 * - `"erc20"`       → `token.balanceOf(vaultAddress)` — covers Aave aTokens,
 *                     Compound cTokens, and idle ERC20s held in the vault.
 * - `"erc4626"`     → `convertToAssets(vault.balanceOf(vaultAddress))` — covers
 *                     Euler, Spark, Yearn, and any ERC4626 vault.
 * - `"morpho-blue"` → `position(marketId, vaultAddress).supplyShares *
 *                     totalSupplyAssets / totalSupplyShares` — Morpho Blue supply.
 *
 * @param publicClient - viem PublicClient
 * @param vaultAddress - BoringVault address whose balance is being queried
 * @param positions - Array of StrategyPosition descriptors
 * @returns Array of StrategyAllocation sorted largest-first, excluding zero balances
 */
export async function getStrategyAllocations(
  publicClient: PublicClient,
  vaultAddress: Address,
  positions: readonly StrategyPosition[]
): Promise<StrategyAllocation[]> {
  if (positions.length === 0) return [];

  const balances = await Promise.all(
    positions.map((pos) => resolvePositionBalance(publicClient, vaultAddress, pos))
  );

  const totalBalance = balances.reduce((sum, b) => sum + b, 0n);
  if (totalBalance === 0n) return [];

  const result: StrategyAllocation[] = [];
  for (let i = 0; i < positions.length; i++) {
    const balance = balances[i] ?? 0n;
    if (balance === 0n) continue;
    const pos = positions[i];
    if (!pos) continue;

    const percentage = Math.round((Number(balance) / Number(totalBalance)) * 1000) / 10;
    result.push({ protocol: pos.protocol, percentage, balance });
  }

  return result.sort((a, b) => (a.balance > b.balance ? -1 : 1));
}

async function resolvePositionBalance(
  publicClient: PublicClient,
  vaultAddress: Address,
  position: StrategyPosition
): Promise<bigint> {
  try {
    if (position.type === "erc20") {
      return await publicClient.readContract({
        address: position.tokenAddress,
        abi: erc20BalanceAbi,
        functionName: "balanceOf",
        args: [vaultAddress],
      });
    }

    if (position.type === "erc4626") {
      const shares = await publicClient.readContract({
        address: position.vaultAddress,
        abi: erc4626Abi,
        functionName: "balanceOf",
        args: [vaultAddress],
      });
      if (shares === 0n) return 0n;
      return publicClient.readContract({
        address: position.vaultAddress,
        abi: erc4626Abi,
        functionName: "convertToAssets",
        args: [shares],
      });
    }

    if (position.type === "morpho-blue") {
      const [pos, mkt] = await Promise.all([
        publicClient.readContract({
          address: position.morphoAddress,
          abi: morphoBlueAbi,
          functionName: "position",
          args: [position.marketId, vaultAddress],
        }),
        publicClient.readContract({
          address: position.morphoAddress,
          abi: morphoBlueAbi,
          functionName: "market",
          args: [position.marketId],
        }),
      ]);

      const supplyShares = pos[0];
      const totalSupplyAssets = mkt[0];
      const totalSupplyShares = mkt[1];

      if (supplyShares === 0n || totalSupplyShares === 0n) return 0n;

      // Standard Morpho shares-to-assets conversion (rounds down)
      return (supplyShares * BigInt(totalSupplyAssets)) / BigInt(totalSupplyShares);
    }
  } catch {
    // Position query failed (e.g. vault not in this market) — treat as zero
    return 0n;
  }

  return 0n;
}

const TRANSFER_EVENT = parseAbiItem(
  "event Transfer(address indexed from, address indexed to, uint256 value)"
);

/**
 * Discovers vault strategy allocations by scanning on-chain Transfer events
 * directed at the vault address — no config required.
 *
 * @param publicClient  - viem PublicClient (archive node recommended)
 * @param vaultAddress  - BoringVault address to discover positions for
 * @param fromBlock     - Start of scan range (vault deployment block)
 * @param toBlock       - End of scan range (use current block)
 * @returns Array of StrategyAllocation sorted largest-first
 */
export async function discoverStrategyAllocations(
  publicClient: PublicClient,
  vaultAddress: Address,
  fromBlock: bigint,
  toBlock: bigint
): Promise<StrategyAllocation[]> {
  const logs = await publicClient.getLogs({
    event: TRANSFER_EVENT,
    args: { to: vaultAddress },
    fromBlock,
    toBlock,
  });

  const tokenAddresses = [...new Set(logs.map((l: { address: Address }) => l.address.toLowerCase() as Address))];

  if (tokenAddresses.length === 0) return [];

  const balances = await Promise.all(
    tokenAddresses.map((token) =>
      publicClient
        .readContract({
          address: token,
          abi: erc20BalanceAbi,
          functionName: "balanceOf",
          args: [vaultAddress],
        })
        .catch(() => 0n)
    )
  );

  const active: { token: Address; balance: bigint }[] = [];
  for (let i = 0; i < tokenAddresses.length; i++) {
    const balance = balances[i] ?? 0n;
    const token = tokenAddresses[i];
    if (balance > 0n && token) active.push({ token, balance });
  }

  if (active.length === 0) return [];

  const totalBalance = active.reduce((s, { balance }) => s + balance, 0n);

  return active
    .sort((a, b) => (a.balance > b.balance ? -1 : 1))
    .map(({ token, balance }) => ({
      protocol: token,
      percentage: Math.round((Number(balance) / Number(totalBalance)) * 1000) / 10,
      balance,
    }));
}
