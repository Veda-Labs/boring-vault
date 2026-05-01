/**
 * Transaction builders and pre-flight validation for BoringVault operations.
 *
 * Functions return TransactionRequest objects ready to be passed to
 * walletClient.sendTransaction() or wagmi's writeContract — they do not
 * submit transactions themselves, keeping them framework-agnostic.
 */

import type { Address, PublicClient } from "viem";
import { encodeFunctionData } from "viem";
import { tellerAbi } from "./abis/teller.js";
import { accountantAbi } from "./abis/accountant.js";
import { atomicQueueAbi } from "./abis/atomicQueue.js";
import { boringOnChainQueueAbi } from "./abis/boringOnChainQueue.js";
import { delayedWithdrawAbi } from "./abis/delayedWithdraw.js";
import type {
  DepositParams,
  DepositWithPermitParams,
  WithdrawalRequestParams,
  DelayedWithdrawRequestParams,
  TransactionRequest,
  DepositValidationResult,
  SimulateDepositResult,
} from "./types.js";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000" as Address;

const erc20Abi = [
  {
    name: "balanceOf",
    type: "function",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
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
    name: "decimals",
    type: "function",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
] as const;

/**
 * Builds a calldata-ready deposit transaction.
 * The caller must have already approved the Teller to spend depositAsset.
 *
 * @example
 * ```ts
 * const tx = await buildDepositTx({
 *   boringVault: "0x...",
 *   teller: "0x...",
 *   depositAsset: usdcAddress,
 *   depositAmount: parseUnits("1000", 6),
 *   minimumMint: parseUnits("990", 18),
 * });
 * await walletClient.sendTransaction(tx);
 * ```
 */
export function buildDepositTx(params: DepositParams): TransactionRequest {
  const data = encodeFunctionData({
    abi: tellerAbi,
    functionName: "deposit",
    args: [
      params.depositAsset,
      params.depositAmount,
      params.minimumMint,
      params.referralAddress ?? ZERO_ADDRESS,
    ],
  });

  return { to: params.teller, data, value: 0n };
}

/**
 * Builds a deposit-with-permit transaction for EIP-2612 tokens (e.g. USDC v2).
 * No prior approve() call is required — the permit is included in the calldata.
 *
 * @example
 * ```ts
 * const { v, r, s } = await signPermit({ ... });
 * const tx = await buildDepositWithPermitTx({
 *   ...depositParams,
 *   deadline: BigInt(Math.floor(Date.now() / 1000) + 3600),
 *   v, r, s,
 * });
 * ```
 */
export function buildDepositWithPermitTx(
  params: DepositWithPermitParams
): TransactionRequest {
  const data = encodeFunctionData({
    abi: tellerAbi,
    functionName: "depositWithPermit",
    args: [
      params.depositAsset,
      params.depositAmount,
      params.minimumMint,
      params.deadline,
      params.v,
      params.r,
      params.s,
      params.referralAddress ?? ZERO_ADDRESS,
    ],
  });

  return { to: params.teller, data, value: 0n };
}

/**
 * Builds a withdrawal request transaction for either queue type.
 *
 * For "atomic" (AtomicQueue): user sets atomicPrice (min price per share, 1e18 scaled).
 * For "boring-onchain" (BoringOnChainQueue): user sets discount in BPS + deadline duration.
 */
export function buildWithdrawalRequestTx(
  params: WithdrawalRequestParams
): TransactionRequest {
  if (params.queueType === "atomic") {
    const data = encodeFunctionData({
      abi: atomicQueueAbi,
      functionName: "updateAtomicRequest",
      args: [
        params.offerToken,
        params.wantToken,
        {
          deadline: params.deadline,
          atomicPrice: params.atomicPrice,
          offerAmount: params.offerAmount,
          inSolve: false,
        },
      ],
    });
    return { to: params.atomicQueue, data, value: 0n };
  }

  // boring-onchain
  const data = encodeFunctionData({
    abi: boringOnChainQueueAbi,
    functionName: "requestOnChainWithdraw",
    args: [
      params.assetOut,
      params.amountOfShares,
      params.discount,
      params.secondsToDeadline,
    ],
  });
  return { to: params.boringQueue, data, value: 0n };
}

/**
 * Validates whether a deposit would succeed without submitting a transaction.
 *
 * @example
 * ```ts
 * const result = await validateDeposit(client, {
 *   boringVault, teller, depositAsset, depositAmount, userAddress,
 * });
 * if (!result.valid) showError(result.reason);
 * ```
 */
export async function validateDeposit(
  publicClient: PublicClient,
  params: {
    boringVault: Address;
    teller: Address;
    depositAsset: Address;
    depositAmount: bigint;
    userAddress: Address;
  }
): Promise<DepositValidationResult> {
  try {
    const [isPaused, isSupported, balance, allowance] = await Promise.all([
      publicClient.readContract({
        address: params.teller,
        abi: tellerAbi,
        functionName: "isPaused",
      }),
      publicClient.readContract({
        address: params.teller,
        abi: tellerAbi,
        functionName: "isSupported",
        args: [params.depositAsset],
      }),
      publicClient.readContract({
        address: params.depositAsset,
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [params.userAddress],
      }),
      publicClient.readContract({
        address: params.depositAsset,
        abi: erc20Abi,
        functionName: "allowance",
        args: [params.userAddress, params.teller],
      }),
    ]);

    if (isPaused) return { valid: false, reason: "teller_paused" };
    if (!isSupported) return { valid: false, reason: "asset_not_supported" };
    if (balance < params.depositAmount) return { valid: false, reason: "insufficient_balance" };
    if (allowance < params.depositAmount) return { valid: false, reason: "insufficient_allowance" };

    return { valid: true };
  } catch {
    return { valid: false, reason: "unknown" };
  }
}

/**
 * Simulates a deposit to preview the shares that would be minted.
 *
 * @example
 * ```ts
 * const sim = await simulateDeposit(client, {
 *   depositAsset: lbtcAddr,
 *   depositAmount: parseUnits("0.1", 8),
 *   boringVault: vaultAddr,
 *   accountant: accountantAddr,
 * });
 * // sharesOut uses base asset decimals (8 for BTC-denominated vaults, 18 for ETH)
 * console.log(`Would receive ${formatUnits(sim.sharesOut, decimals)} shares`);
 * ```
 */
export async function simulateDeposit(
  publicClient: PublicClient,
  params: {
    depositAsset: Address;
    depositAmount: bigint;
    boringVault: Address;
    accountant: Address;
  }
): Promise<SimulateDepositResult> {
  try {
    // Fetch decimals alongside rateInQuote — BoringVault shares mirror the
    // base asset decimals (e.g. 8 for BTC vaults), NOT always 18. Using a
    // hardcoded 1e18 here is off by 10^10 for BTC-denominated vaults.
    const [rateInQuote, decimals] = await Promise.all([
      publicClient.readContract({
        address: params.accountant,
        abi: accountantAbi,
        functionName: "getRateInQuote",
        args: [params.depositAsset],
      }),
      publicClient.readContract({
        address: params.accountant,
        abi: accountantAbi,
        functionName: "decimals",
      }),
    ]);

    const sharesOut = (params.depositAmount * BigInt(10 ** decimals)) / rateInQuote;

    return { sharesOut, wouldSucceed: true };
  } catch (err: unknown) {
    const revertReason = err instanceof Error ? err.message : "Unknown error";
    return { sharesOut: 0n, wouldSucceed: false, revertReason };
  }
}


// ── DelayedWithdraw transaction builders ──────────────────────────────────

/**
 * Builds a requestWithdraw transaction for DelayedWithdraw vaults.
 * Shares are locked until maturity; user calls completeWithdraw after that window.
 *
 * @example
 * ```ts
 * const tx = buildDelayedWithdrawRequestTx({
 *   delayedWithdraw: "0x...",
 *   asset: wethAddress,
 *   shares: parseUnits("10", 18),
 *   maxLoss: 50,   // 0.5% max slippage
 *   allowThirdPartyToComplete: false,
 * });
 * await walletClient.sendTransaction(tx);
 * ```
 */
export function buildDelayedWithdrawRequestTx(
  params: DelayedWithdrawRequestParams
): TransactionRequest {
  const data = encodeFunctionData({
    abi: delayedWithdrawAbi,
    functionName: "requestWithdraw",
    args: [
      params.asset,
      params.shares,
      params.maxLoss,
      params.allowThirdPartyToComplete,
    ],
  });
  return { to: params.delayedWithdraw, data, value: 0n };
}

/**
 * Builds a cancelWithdraw transaction — cancels a pending delayed withdraw request
 * and returns the locked shares to the user.
 */
export function buildCancelDelayedWithdrawTx(
  delayedWithdraw: Address,
  asset: Address
): TransactionRequest {
  const data = encodeFunctionData({
    abi: delayedWithdrawAbi,
    functionName: "cancelWithdraw",
    args: [asset],
  });
  return { to: delayedWithdraw, data, value: 0n };
}

/**
 * Builds a completeWithdraw transaction — can be called by the user or (if allowed)
 * a third party once the maturity timestamp has been reached.
 *
 * @param account - The user whose request is being completed (may differ from caller)
 */
export function buildCompleteDelayedWithdrawTx(
  delayedWithdraw: Address,
  asset: Address,
  account: Address
): TransactionRequest {
  const data = encodeFunctionData({
    abi: delayedWithdrawAbi,
    functionName: "completeWithdraw",
    args: [asset, account],
  });
  return { to: delayedWithdraw, data, value: 0n };
}
