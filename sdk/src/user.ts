/**
 * User-position read functions for BoringVault.
 * All functions are independently importable and tree-shakeable.
 */

import type { Address, PublicClient } from "viem";
import { formatUnits } from "viem";
import { atomicQueueAbi } from "./abis/atomicQueue.js";
import { accountantAbi } from "./abis/accountant.js";
import { boringVaultAbi } from "./abis/boringVault.js";
import { tellerAbi } from "./abis/teller.js";
import { delayedWithdrawAbi } from "./abis/delayedWithdraw.js";
import type { UserPosition, WithdrawalRequest, DelayedWithdrawRequest, DelayedWithdrawAsset } from "./types.js";

/**
 * Fetches the complete user position: share balance + asset-equivalent value.
 *
 * @example
 * ```ts
 * const pos = await getUserPosition(client, userAddr, vaultAddr, accountantAddr);
 * console.log(`${pos.sharesFormatted} shares ≈ ${pos.assetsFormatted}`);
 * ```
 */
export async function getUserPosition(
  publicClient: PublicClient,
  userAddress: Address,
  vaultAddress: Address,
  accountantAddress: Address
): Promise<UserPosition> {
  const [shares, rate, decimals] = await Promise.all([
    publicClient.readContract({
      address: vaultAddress,
      abi: boringVaultAbi,
      functionName: "balanceOf",
      args: [userAddress],
    }),
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

  const assetsValue = (shares * rate) / BigInt(10 ** decimals);
  return formatPosition(shares, assetsValue, decimals);
}

function formatPosition(shares: bigint, assetsValue: bigint, decimals: number): UserPosition {
  const sharesFormatted = Number(formatUnits(shares, decimals)).toLocaleString("en-US", {
    minimumFractionDigits: 4,
    maximumFractionDigits: 4,
  });
  const assetsFormatted = Number(formatUnits(assetsValue, decimals)).toLocaleString("en-US", {
    minimumFractionDigits: 4,
    maximumFractionDigits: 4,
  });
  return { shares, sharesFormatted, assetsValue, assetsFormatted };
}

/**
 * Returns the date/time at which a user's shares become transferable.
 * Returns null if the share lock period has already elapsed.
 *
 * @example
 * ```ts
 * const unlock = await getUnlockTime(client, userAddr, tellerAddr);
 * if (unlock) console.log(`Shares unlock at ${unlock.toLocaleString()}`);
 * ```
 */
export async function getUnlockTime(
  publicClient: PublicClient,
  userAddress: Address,
  tellerAddress: Address
): Promise<Date | null> {
  const unlockTimestamp = await publicClient.readContract({
    address: tellerAddress,
    abi: tellerAbi,
    functionName: "shareUnlockTime",
    args: [userAddress],
  });

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (unlockTimestamp <= BigInt(nowSeconds)) return null;

  return new Date(Number(unlockTimestamp) * 1000);
}

/**
 * Fetches active withdrawal requests for a user from either queue type.
 *
 * @example
 * ```ts
 * const requests = await getWithdrawalRequests(
 *   client, "atomic", queue, user, vaultAddr, [usdcAddr, wethAddr]
 * );
 * requests.forEach(r => console.log(`Withdrawing ${r.offerAmount} shares`));
 * ```
 */
export async function getWithdrawalRequests(
  publicClient: PublicClient,
  queueType: "atomic" | "boring-onchain",
  queueAddress: Address,
  userAddress: Address,
  offerToken: Address,
  wantTokens: Address[]
): Promise<WithdrawalRequest[]> {
  if (queueType === "atomic") {
    return getAtomicQueueRequests(publicClient, queueAddress, userAddress, offerToken, wantTokens);
  }
  return getBoringOnChainRequests(publicClient, queueAddress, userAddress);
}

async function getAtomicQueueRequests(
  publicClient: PublicClient,
  queueAddress: Address,
  userAddress: Address,
  offerToken: Address,
  wantTokens: Address[]
): Promise<WithdrawalRequest[]> {
  const results = await Promise.all(
    wantTokens.map((wantToken) =>
      publicClient.readContract({
        address: queueAddress,
        abi: atomicQueueAbi,
        functionName: "getUserAtomicRequest",
        args: [userAddress, offerToken, wantToken],
      })
    )
  );

  const requests: WithdrawalRequest[] = [];
  for (let i = 0; i < results.length; i++) {
    const result = results[i];
    const wantToken = wantTokens[i];
    if (!result || !wantToken) continue;

    const { deadline, atomicPrice, offerAmount, inSolve } = result;
    if (offerAmount === 0n) continue;

    requests.push({
      offerAmount,
      atomicPrice,
      deadline: Number(deadline),
      inSolve,
      offerToken,
      wantToken,
      requestId: "",
    });
  }

  return requests;
}

const ON_CHAIN_WITHDRAW_REQUESTED_EVENT = {
  name: "OnChainWithdrawRequested",
  type: "event",
  inputs: [
    { name: "requestId", type: "bytes32", indexed: true },
    { name: "user", type: "address", indexed: true },
    { name: "assetOut", type: "address", indexed: true },
    { name: "amountOfShares", type: "uint128", indexed: false },
    { name: "amountOfAssets", type: "uint128", indexed: false },
    { name: "creationTime", type: "uint40", indexed: false },
    { name: "secondsToMaturity", type: "uint24", indexed: false },
    { name: "secondsToDeadline", type: "uint24", indexed: false },
  ],
} as const;

const ON_CHAIN_WITHDRAW_CANCELLED_EVENT = {
  name: "OnChainWithdrawCancelled",
  type: "event",
  inputs: [
    { name: "requestId", type: "bytes32", indexed: true },
    { name: "user", type: "address", indexed: true },
    { name: "timestamp", type: "uint256", indexed: false },
  ],
} as const;

async function getBoringOnChainRequests(
  publicClient: PublicClient,
  queueAddress: Address,
  userAddress: Address
): Promise<WithdrawalRequest[]> {
  const currentBlock = await publicClient.getBlockNumber();
  const fromBlock = currentBlock - 50_000n; // ~7 days on mainnet

  const [requested, cancelled] = await Promise.all([
    publicClient.getLogs({
      address: queueAddress,
      event: ON_CHAIN_WITHDRAW_REQUESTED_EVENT,
      args: { user: userAddress },
      fromBlock,
      toBlock: currentBlock,
    }),
    publicClient.getLogs({
      address: queueAddress,
      event: ON_CHAIN_WITHDRAW_CANCELLED_EVENT,
      args: { user: userAddress },
      fromBlock,
      toBlock: currentBlock,
    }),
  ]);

  const cancelledIds = new Set(cancelled.map((l) => l.args.requestId));
  const nowSeconds = Math.floor(Date.now() / 1000);
  const requests: WithdrawalRequest[] = [];

  for (const log of requested) {
    const { requestId, assetOut, amountOfShares, creationTime, secondsToDeadline } = log.args;

    if (!requestId || !assetOut || amountOfShares === undefined || creationTime === undefined || secondsToDeadline === undefined) continue;
    if (cancelledIds.has(requestId)) continue;

    const deadline = Number(creationTime) + secondsToDeadline;
    if (deadline < nowSeconds) continue;

    requests.push({
      offerAmount: amountOfShares,
      wantToken: assetOut,
      deadline,
      offerToken: queueAddress,
      atomicPrice: 0n,
      inSolve: false,
      requestId,
    });
  }

  return requests;
}

// ── DelayedWithdraw reads ──────────────────────────────────────────────────

/**
 * Reads a user's pending delayed withdrawal request and the associated asset
 * configuration from the DelayedWithdraw contract.
 *
 * Returns null for both fields when no request exists (shares === 0n).
 *
 * @example
 * ```ts
 * const { request, asset } = await getDelayedWithdrawRequest(
 *   client, delayedWithdrawAddr, userAddr, wethAddr
 * );
 * if (request && request.shares > 0n) {
 *   const ready = Date.now() / 1000 >= request.maturity;
 *   console.log(`Withdraw ${ready ? "ready" : "pending"}`);
 * }
 * ```
 */
export async function getDelayedWithdrawRequest(
  publicClient: PublicClient,
  delayedWithdrawAddress: Address,
  userAddress: Address,
  asset: Address
): Promise<{ request: DelayedWithdrawRequest | null; assetConfig: DelayedWithdrawAsset }> {
  const [req, assetConfig] = await Promise.all([
    publicClient.readContract({
      address: delayedWithdrawAddress,
      abi: delayedWithdrawAbi,
      functionName: "withdrawRequests",
      args: [userAddress, asset],
    }),
    publicClient.readContract({
      address: delayedWithdrawAddress,
      abi: delayedWithdrawAbi,
      functionName: "withdrawAssets",
      args: [asset],
    }),
  ]);

  const mappedAsset: DelayedWithdrawAsset = {
    allowWithdraws:    assetConfig[0],
    withdrawDelay:     assetConfig[1],
    completionWindow:  assetConfig[2],
    outstandingShares: assetConfig[3],
    withdrawFee:       assetConfig[4],
    maxLoss:           assetConfig[5],
  };

  if (req[3] === 0n) return { request: null, assetConfig: mappedAsset };

  return {
    request: {
      allowThirdPartyToComplete:   req[0],
      maxLoss:                     req[1],
      maturity:                    req[2],
      shares:                      req[3],
      exchangeRateAtTimeOfRequest: req[4],
    },
    assetConfig: mappedAsset,
  };
}
