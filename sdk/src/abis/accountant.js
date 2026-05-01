/**
 * ABI fragments for AccountantWithRateProviders.
 * Source: src/base/Roles/AccountantWithRateProviders.sol
 */
export const accountantAbi = [
    // ── Rate queries ───────────────────────────────────────────────────────
    {
        name: "getRate",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ name: "rate", type: "uint256" }],
    },
    {
        name: "getRateSafe",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ name: "rate", type: "uint256" }],
    },
    {
        name: "getRateInQuote",
        type: "function",
        stateMutability: "view",
        inputs: [{ name: "quote", type: "address" }],
        outputs: [{ name: "rateInQuote", type: "uint256" }],
    },
    {
        name: "getRateInQuoteSafe",
        type: "function",
        stateMutability: "view",
        inputs: [{ name: "quote", type: "address" }],
        outputs: [{ name: "rateInQuote", type: "uint256" }],
    },
    // ── State ─────────────────────────────────────────────────────────────
    // Field order matches the on-chain struct exactly — do not reorder.
    // [0] payoutAddress, [1] highwaterMark, [2] feesOwedInBase,
    // [3] totalSharesLastUpdate, [4] exchangeRate,
    // [5] allowedExchangeRateChangeUpper, [6] allowedExchangeRateChangeLower,
    // [7] lastUpdateTimestamp, [8] isPaused,
    // [9] minimumUpdateDelayInSeconds, [10] managementFee, [11] performanceFee
    {
        name: "accountantState",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [
            { name: "payoutAddress", type: "address" },
            { name: "highwaterMark", type: "uint96" },
            { name: "feesOwedInBase", type: "uint128" },
            { name: "totalSharesLastUpdate", type: "uint128" },
            { name: "exchangeRate", type: "uint96" },
            { name: "allowedExchangeRateChangeUpper", type: "uint16" },
            { name: "allowedExchangeRateChangeLower", type: "uint16" },
            { name: "lastUpdateTimestamp", type: "uint64" },
            { name: "isPaused", type: "bool" },
            { name: "minimumUpdateDelayInSeconds", type: "uint24" },
            { name: "managementFee", type: "uint16" },
            { name: "performanceFee", type: "uint16" },
        ],
    },
    {
        name: "base",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ name: "", type: "address" }],
    },
    {
        name: "decimals",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ name: "", type: "uint8" }],
    },
    // ── Rate provider data ─────────────────────────────────────────────────
    {
        name: "rateProviderData",
        type: "function",
        stateMutability: "view",
        inputs: [{ name: "asset", type: "address" }],
        outputs: [
            { name: "isPeggedToBase", type: "bool" },
            { name: "rateProvider", type: "address" },
        ],
    },
    // ── Events ────────────────────────────────────────────────────────────
    {
        name: "ExchangeRateUpdated",
        type: "event",
        inputs: [
            { name: "oldExchangeRate", type: "uint96", indexed: false },
            { name: "newExchangeRate", type: "uint96", indexed: false },
            { name: "currentTime", type: "uint64", indexed: false },
        ],
    },
    { name: "Paused", type: "event", inputs: [] },
    { name: "Unpaused", type: "event", inputs: [] },
];
//# sourceMappingURL=accountant.js.map