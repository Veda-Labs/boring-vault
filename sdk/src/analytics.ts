/**
 * Analytics functions for historical vault data.
 *
 * Reads on-chain events via eth_getLogs. For production, replace log fetching
 * with an indexer (e.g. The Graph, Ponder) to avoid RPC rate limits and
 * make historical queries instant.
 */

import type { Address, PublicClient } from "viem";
import { formatUnits, parseAbiItem } from "viem";
import type { RatePoint, TVLPoint } from "./types.js";

const RATE_UPDATED_EVENT = parseAbiItem(
  "event ExchangeRateUpdated(uint96 oldExchangeRate, uint96 newExchangeRate, uint64 currentTime)"
);

const ENTER_EVENT = parseAbiItem(
  "event Enter(address indexed from, address indexed asset, uint256 amount, address indexed to, uint256 shares)"
);

const EXIT_EVENT = parseAbiItem(
  "event Exit(address indexed to, address indexed asset, uint256 amount, address indexed from, uint256 shares)"
);

/**
 * Fetches the historical exchange rate of vault shares by reading
 * ExchangeRateUpdated events from the Accountant contract.
 *
 * @param publicClient - viem PublicClient with eth_getLogs support
 * @param accountantAddress - AccountantWithRateProviders address
 * @param fromBlock - Starting block number for the query
 * @param toBlock - Ending block number (use "latest" equivalent)
 * @returns Array of RatePoint sorted ascending by timestamp
 *
 * @example
 * ```ts
 * const history = await getExchangeRateHistory(
 *   client, accountantAddr, 19_000_000n, 19_500_000n
 * );
 * const apy = estimateAPY(history, 30);
 * console.log(`30-day APY: ${(apy * 100).toFixed(2)}%`);
 * ```
 */
export async function getExchangeRateHistory(
  publicClient: PublicClient,
  accountantAddress: Address,
  fromBlock: bigint,
  toBlock: bigint,
  decimals = 8,
): Promise<RatePoint[]> {
  // Cap range to 500k blocks (~70 days) so Alchemy free tier doesn't 400
  const MAX_RANGE = 500_000n;
  const effectiveFrom = toBlock > fromBlock + MAX_RANGE ? toBlock - MAX_RANGE : fromBlock;

  let logs;
  try {
    logs = await publicClient.getLogs({
      address: accountantAddress,
      event: RATE_UPDATED_EVENT,
      fromBlock: effectiveFrom,
      toBlock,
    });
  } catch {
    return [];
  }

  const points: RatePoint[] = [];

  for (const log of logs) {
    if (!log.args.newExchangeRate || !log.args.currentTime) continue;

    const rate = BigInt(log.args.newExchangeRate);
    const timestamp = Number(log.args.currentTime);
    const rateFormatted = Number(formatUnits(rate, decimals)).toFixed(6);

    points.push({
      timestamp,
      rate,
      rateFormatted,
      blockNumber: log.blockNumber ?? 0n,
    });
  }

  return points.sort((a, b) => a.timestamp - b.timestamp);
}

/**
 * Reconstructs TVL history from BoringVault Enter (deposit) and Exit (withdraw)
 * events. Each data point is the cumulative net TVL at that block.
 *
 * Note: This gives share-count history, not USD-value history. Multiply by
 * the share price at each point to get dollar-denominated TVL.
 *
 * @param publicClient - viem PublicClient
 * @param vaultAddress - BoringVault address (emits Enter/Exit events)
 * @param fromBlock - Starting block
 * @param toBlock - Ending block
 * @returns Array of TVLPoint sorted ascending by timestamp
 */
export async function getTVLHistory(
  publicClient: PublicClient,
  vaultAddress: Address,
  fromBlock: bigint,
  toBlock: bigint,
  decimals = 8,
): Promise<TVLPoint[]> {
  const MAX_RANGE = 500_000n;
  const effectiveFrom = toBlock > fromBlock + MAX_RANGE ? toBlock - MAX_RANGE : fromBlock;

  let enterLogs, exitLogs;
  try {
    [enterLogs, exitLogs] = await Promise.all([
      publicClient.getLogs({ address: vaultAddress, event: ENTER_EVENT, fromBlock: effectiveFrom, toBlock }),
      publicClient.getLogs({ address: vaultAddress, event: EXIT_EVENT,  fromBlock: effectiveFrom, toBlock }),
    ]);
  } catch {
    return [];
  }

  interface LogEntry { blockNumber: bigint; shares: bigint; isDeposit: boolean; timestamp?: number }
  const allEvents: LogEntry[] = [];

  for (const log of enterLogs) {
    if (log.args.shares) {
      allEvents.push({
        blockNumber: log.blockNumber ?? 0n,
        shares: BigInt(log.args.shares),
        isDeposit: true,
      });
    }
  }

  for (const log of exitLogs) {
    if (log.args.shares) {
      allEvents.push({
        blockNumber: log.blockNumber ?? 0n,
        shares: BigInt(log.args.shares),
        isDeposit: false,
      });
    }
  }

  allEvents.sort((a, b) => (a.blockNumber < b.blockNumber ? -1 : 1));

  // Fetch block timestamps in batches (up to 50 at a time to avoid rate limits)
  const uniqueBlocks = [...new Set(allEvents.map((e) => e.blockNumber))];
  const blockTimestamps = new Map<bigint, number>();

  for (let i = 0; i < uniqueBlocks.length; i += 50) {
    const batch = uniqueBlocks.slice(i, i + 50);
    const blocks = await Promise.all(
      batch.map((bn) => publicClient.getBlock({ blockNumber: bn }))
    );
    for (const block of blocks) {
      blockTimestamps.set(block.number, Number(block.timestamp));
    }
  }

  const points: TVLPoint[] = [];
  let cumulativeShares = 0n;

  for (const event of allEvents) {
    cumulativeShares = event.isDeposit
      ? cumulativeShares + event.shares
      : cumulativeShares - event.shares;

    const timestamp = blockTimestamps.get(event.blockNumber) ?? 0;
    const tvlFormatted = Number(formatUnits(cumulativeShares, decimals)).toLocaleString("en-US", {
      minimumFractionDigits: 4,
      maximumFractionDigits: 6,
    });

    points.push({
      timestamp,
      tvl: cumulativeShares,
      tvlFormatted,
      blockNumber: event.blockNumber,
    });
  }

  return points;
}

/**
 * Estimates annualised APY from a series of exchange rate snapshots.
 *
 * Uses compound growth formula:
 *   APY = (rateEnd / rateStart) ^ (365 / windowDays) - 1
 *
 * @param rateHistory - Array of RatePoint from getExchangeRateHistory
 * @param windowDays - Lookback window in days (7 or 30)
 * @returns APY as a decimal fraction, e.g. 0.0842 = 8.42%
 *
 * @example
 * ```ts
 * const history = await getExchangeRateHistory(client, accountant, from, to);
 * const apy = estimateAPY(history, 30);
 * console.log(`APY: ${(apy * 100).toFixed(2)}%`);
 * ```
 */
export function estimateAPY(rateHistory: RatePoint[], windowDays: 30 | 7): number {
  if (rateHistory.length < 2) return 0;

  const latest = rateHistory[rateHistory.length - 1];
  if (!latest) return 0;

  const windowSeconds = windowDays * 24 * 3600;
  const cutoffTimestamp = latest.timestamp - windowSeconds;

  const basePoint = rateHistory.find((p) => p.timestamp >= cutoffTimestamp) ?? rateHistory[0];
  if (!basePoint || basePoint.timestamp === latest.timestamp) return 0;

  const rateStart = Number(basePoint.rate);
  const rateEnd = Number(latest.rate);
  if (rateStart === 0) return 0;

  const actualWindowDays = (latest.timestamp - basePoint.timestamp) / (24 * 3600);
  if (actualWindowDays < 1) return 0;

  const growthFactor = rateEnd / rateStart;
  const apy = Math.pow(growthFactor, 365 / actualWindowDays) - 1;

  return Math.max(0, apy);
}
