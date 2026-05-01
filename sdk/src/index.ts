// Vault-level reads
export { fetchTVL, getSharePrice, getVaultStatus, getLastRebalanceTimestamp, getStrategyAllocations, discoverStrategyAllocations } from "./vault.js";

// User position reads
export { getUserPosition, getUnlockTime, getWithdrawalRequests, getDelayedWithdrawRequest } from "./user.js";

// Transaction builders + validation
export { buildDepositTx, buildDepositWithPermitTx, buildWithdrawalRequestTx, validateDeposit, simulateDeposit, buildDelayedWithdrawRequestTx, buildCancelDelayedWithdrawTx, buildCompleteDelayedWithdrawTx } from "./transactions.js";

// Analytics / history
export { getExchangeRateHistory, getTVLHistory, estimateAPY } from "./analytics.js";

// Types
export type {
  TVLResult,
  SharePrice,
  VaultStatus,
  StrategyAllocation,
  StrategyPosition,
  Erc20Position,
  Erc4626Position,
  MorphoBluePosition,
  UserPosition,
  WithdrawalRequest,
  DepositParams,
  DepositWithPermitParams,
  WithdrawalRequestParams,
  AtomicWithdrawalRequestParams,
  OnChainWithdrawalRequestParams,
  TransactionRequest,
  DepositValidationResult,
  SimulateDepositResult,
  RatePoint,
  TVLPoint,
  DelayedWithdrawRequest,
  DelayedWithdrawAsset,
  DelayedWithdrawRequestParams,
  PreviewWithdrawResult,
} from "./types.js";
