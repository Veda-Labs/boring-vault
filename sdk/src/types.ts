/**
 * Shared TypeScript types for the BoringVault SDK.
 * All types are strict — no `any`, no optional chains on required fields.
 */

import type { Address } from "viem";

// ── Vault state ────────────────────────────────────────────────────────────

export interface TVLResult {
  /** Raw TVL in base asset decimals (8 for BTC-denominated vaults, 18 for ETH) */
  raw: bigint;
  /** Human-readable TVL string, e.g. "4,231.87" */
  formatted: string;
  /** The base asset address the accountant is denominated in */
  baseAsset: Address;
}

export interface SharePrice {
  /** Rate in base asset decimals per 1e18 vault share */
  rate: bigint;
  /** Rate formatted as a decimal string, e.g. "1.0421" */
  formatted: string;
  /** Unix timestamp (seconds) when this price was observed */
  timestamp: number;
}

export type VaultStatus = "active" | "paused";

export interface StrategyAllocation {
  /** Human-readable protocol name, e.g. "Aave v3" */
  protocol: string;
  /** Percentage of TVL, 0–100 */
  percentage: number;
  /** Raw asset balance in this strategy (base decimals) */
  balance: bigint;
}

// ── User position ─────────────────────────────────────────────────────────

export interface UserPosition {
  /** Share balance in vault token decimals (mirrors base asset — 8 for BTC, 18 for ETH) */
  shares: bigint;
  /** Share balance formatted, e.g. "10.500" */
  sharesFormatted: string;
  /** Equivalent asset value in base asset decimals */
  assetsValue: bigint;
  /** Asset value formatted, e.g. "10.500 WETH" */
  assetsFormatted: string;
}

export interface WithdrawalRequest {
  /** Share amount being offered */
  offerAmount: bigint;
  /** Token the user wants to receive */
  wantToken: Address;
  /** Unix timestamp (seconds) after which request expires */
  deadline: number;
  /** Token the user is offering (vault share address) — AtomicQueue only */
  offerToken: Address;
  /** Minimum acceptable price in want-asset terms (1e18 scaled) — AtomicQueue only, 0n for BoringOnChainQueue */
  atomicPrice: bigint;
  /** True if currently being processed by a solver — AtomicQueue only */
  inSolve: boolean;
  /** requestId from BoringOnChainQueue — empty string for AtomicQueue */
  requestId: `0x${string}` | "";
}

// ── Transactions ──────────────────────────────────────────────────────────

export interface DepositParams {
  /** Vault share token address (BoringVault) */
  boringVault: Address;
  /** Teller contract address */
  teller: Address;
  /** ERC20 asset being deposited */
  depositAsset: Address;
  /** Amount in depositAsset decimals */
  depositAmount: bigint;
  /** Minimum shares to receive (slippage protection) */
  minimumMint: bigint;
  /** Optional referral address — pass zero address if unused */
  referralAddress?: Address;
}

export interface DepositWithPermitParams extends DepositParams {
  /** EIP-2612 permit deadline */
  deadline: bigint;
  /** Permit signature v */
  v: number;
  /** Permit signature r */
  r: `0x${string}`;
  /** Permit signature s */
  s: `0x${string}`;
}

/** AtomicQueue withdrawal — for older vaults */
export interface AtomicWithdrawalRequestParams {
  queueType: "atomic";
  /** AtomicQueue contract address */
  atomicQueue: Address;
  /** Vault share token address being offered */
  offerToken: Address;
  /** Asset to receive in exchange */
  wantToken: Address;
  /** Share amount to withdraw */
  offerAmount: bigint;
  /**
   * Minimum price per share in wantToken terms, scaled to 1e18.
   * E.g. if wantToken is USDC (6 dec), a price of 1 USDC = 1_000_000n * 10n**12n
   */
  atomicPrice: bigint;
  /** Unix timestamp (seconds) after which request auto-expires */
  deadline: number;
}

/**
 * BoringOnChainQueue withdrawal — for vaults deployed after mid-2025.
 * User specifies a discount from share price rather than an absolute atomicPrice.
 */
export interface OnChainWithdrawalRequestParams {
  queueType: "boring-onchain";
  /** BoringOnChainQueue contract address */
  atomicQueue: Address;
  /** Asset to receive (must be enabled in withdrawAssets mapping) */
  assetOut: Address;
  /** Shares to withdraw — uint128 max */
  amountOfShares: bigint;
  /**
   * Discount in basis points (BPS). 100 = 1%.
   * Must be within [minDiscount, maxDiscount] from withdrawAssets(assetOut).
   */
  discount: number;
  /** Seconds from now until the request expires. Must be >= minimumSecondsToDeadline. */
  secondsToDeadline: number;
}

/** Discriminated union — pass either shape to buildWithdrawalRequestTx */
export type WithdrawalRequestParams =
  | AtomicWithdrawalRequestParams
  | OnChainWithdrawalRequestParams;

export interface TransactionRequest {
  to: Address;
  data: `0x${string}`;
  value: bigint;
}

// ── Analytics ─────────────────────────────────────────────────────────────

export interface RatePoint {
  /** Unix timestamp (seconds) */
  timestamp: number;
  /** Exchange rate in base asset decimals per 1e18 share */
  rate: bigint;
  /** Rate as a human-readable decimal string, e.g. "1.0421" */
  rateFormatted: string;
  /** Block number when this rate was recorded */
  blockNumber: bigint;
}

export interface TVLPoint {
  /** Unix timestamp (seconds) */
  timestamp: number;
  /** TVL in base asset decimals */
  tvl: bigint;
  /** TVL formatted, e.g. "4231.87" */
  tvlFormatted: string;
  /** Block number */
  blockNumber: bigint;
}

export interface DepositValidationResult {
  valid: boolean;
  /**
   * Human-readable reason if invalid. Possible values:
   * - "insufficient_balance"
   * - "teller_paused"
   * - "asset_not_supported"
   * - "insufficient_allowance"
   */
  reason?: string;
}

export interface SimulateDepositResult {
  /** Expected shares minted */
  sharesOut: bigint;
  /** Whether the deposit would succeed (no revert) */
  wouldSucceed: boolean;
  /** Error reason if wouldSucceed is false */
  revertReason?: string;
}

// ── Strategy positions ────────────────────────────────────────────────────

/** ERC20 balance query — covers Aave aTokens, Compound cTokens, idle holdings */
export interface Erc20Position {
  type: "erc20";
  protocol: string;
  tokenAddress: Address;
}

/**
 * ERC4626 vault position — covers Euler, Spark, Yearn, and any standard vault.
 * Balance = convertToAssets(vault.balanceOf(boringVault))
 */
export interface Erc4626Position {
  type: "erc4626";
  protocol: string;
  vaultAddress: Address;
}

/**
 * Morpho Blue supply position.
 * Balance = supplyShares * totalSupplyAssets / totalSupplyShares
 */
export interface MorphoBluePosition {
  type: "morpho-blue";
  protocol: string;
  morphoAddress: Address;
  /** keccak256(abi.encode(loanToken, collateralToken, oracle, irm, lltv)) */
  marketId: `0x${string}`;
}

export type StrategyPosition = Erc20Position | Erc4626Position | MorphoBluePosition;

// ── DelayedWithdraw ───────────────────────────────────────────────────────

/** On-chain WithdrawRequest struct returned by DelayedWithdraw.withdrawRequests() */
export interface DelayedWithdrawRequest {
  /** Whether a third party can call completeWithdraw on the user's behalf */
  allowThirdPartyToComplete: boolean;
  /** User-set max loss in BPS (0 = use global asset maxLoss) */
  maxLoss: number;
  /** Unix timestamp (seconds) after which the withdrawal can be completed */
  maturity: number;
  /** Share amount locked for withdrawal */
  shares: bigint;
  /** Exchange rate at the time of the request — used for maxLoss check */
  exchangeRateAtTimeOfRequest: bigint;
}

/** On-chain WithdrawAsset config returned by DelayedWithdraw.withdrawAssets() */
export interface DelayedWithdrawAsset {
  allowWithdraws: boolean;
  /** Seconds between request and earliest completion */
  withdrawDelay: number;
  /** Seconds after maturity in which the request is valid */
  completionWindow: number;
  /** Total shares currently pending withdrawal for this asset */
  outstandingShares: bigint;
  /** Fee in BPS charged on completion */
  withdrawFee: number;
  /** Global max loss in BPS for this asset */
  maxLoss: number;
}

export interface DelayedWithdrawRequestParams {
  /** DelayedWithdraw contract address */
  delayedWithdraw: Address;
  /** Asset to withdraw */
  asset: Address;
  /** Share amount to lock — uint96 max */
  shares: bigint;
  /**
   * User-specific max loss in BPS. Use 0 to inherit the asset-level global maxLoss.
   * The contract reverts if (minRate * (1e4 + maxLoss) / 1e4) < maxRate.
   */
  maxLoss: number;
  /** Allow a third party to call completeWithdraw on this request */
  allowThirdPartyToComplete: boolean;
}

export interface PreviewWithdrawResult {
  /** Expected assets the user receives after fees */
  assetsOut: bigint;
  /** True if withdrawals are disabled for this asset */
  withdrawsNotAllowed: boolean;
  /** True if maturity has not yet been reached */
  withdrawNotMatured: boolean;
  /** True if the user has no pending shares */
  noShares: boolean;
  /** True if the exchange rate moved beyond the user's maxLoss tolerance */
  maxLossExceeded: boolean;
  /** True if the contract/vault does not hold enough assets to pay out */
  notEnoughAssetsForWithdraw: boolean;
}
