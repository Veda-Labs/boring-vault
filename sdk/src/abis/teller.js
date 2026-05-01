/**
 * ABI fragments for TellerWithMultiAssetSupport.
 * Source: src/base/Roles/TellerWithMultiAssetSupport.sol
 */
export const tellerAbi = [
    // ── Deposit ────────────────────────────────────────────────────────────
    {
        name: "deposit",
        type: "function",
        stateMutability: "payable",
        inputs: [
            { name: "depositAsset", type: "address" },
            { name: "depositAmount", type: "uint256" },
            { name: "minimumMint", type: "uint256" },
        ],
        outputs: [{ name: "shares", type: "uint256" }],
    },
    {
        name: "depositWithPermit",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            { name: "depositAsset", type: "address" },
            { name: "depositAmount", type: "uint256" },
            { name: "minimumMint", type: "uint256" },
            { name: "deadline", type: "uint256" },
            { name: "v", type: "uint8" },
            { name: "r", type: "bytes32" },
            { name: "s", type: "bytes32" },
        ],
        outputs: [{ name: "shares", type: "uint256" }],
    },
    {
        name: "bulkDeposit",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            { name: "depositAsset", type: "address" },
            { name: "depositAmount", type: "uint256" },
            { name: "minimumMint", type: "uint256" },
            { name: "to", type: "address" },
        ],
        outputs: [{ name: "shares", type: "uint256" }],
    },
    // ── Withdraw ───────────────────────────────────────────────────────────
    {
        name: "bulkWithdraw",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            { name: "withdrawAsset", type: "address" },
            { name: "shareAmount", type: "uint256" },
            { name: "minimumAssets", type: "uint256" },
            { name: "to", type: "address" },
        ],
        outputs: [{ name: "assetsOut", type: "uint256" }],
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
        name: "isSupported",
        type: "function",
        stateMutability: "view",
        inputs: [{ name: "asset", type: "address" }],
        outputs: [{ name: "", type: "bool" }],
    },
    {
        name: "shareLockPeriod",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ name: "", type: "uint64" }],
    },
    {
        name: "shareUnlockTime",
        type: "function",
        stateMutability: "view",
        inputs: [{ name: "account", type: "address" }],
        outputs: [{ name: "", type: "uint256" }],
    },
    // ── Events ────────────────────────────────────────────────────────────
    {
        name: "Deposit",
        type: "event",
        inputs: [
            { name: "nonce", type: "uint256", indexed: true },
            { name: "account", type: "address", indexed: true },
            { name: "depositAsset", type: "address", indexed: true },
            { name: "depositAmount", type: "uint256", indexed: false },
            { name: "shareAmount", type: "uint256", indexed: false },
            { name: "depositTimestamp", type: "uint256", indexed: false },
            { name: "shareLockPeriodAtTimeOfDeposit", type: "uint256", indexed: false },
        ],
    },
    {
        name: "Paused",
        type: "event",
        inputs: [],
    },
    {
        name: "Unpaused",
        type: "event",
        inputs: [],
    },
];
//# sourceMappingURL=teller.js.map