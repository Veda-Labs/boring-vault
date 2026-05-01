/**
 * ABI fragments for BoringOnChainQueue.
 * The newer withdrawal queue (replaces AtomicQueue for vaults deployed after mid-2025).
 * Source: src/base/Roles/BoringOnChainQueue.sol
 *
 * Key difference vs AtomicQueue:
 *   - User specifies a discount (BPS) + secondsToDeadline, not an atomicPrice
 *   - withdrawAssets() mapping tells you the valid discount range per asset
 *   - BoringSolver fulfils requests on-chain; no external solver needed
 */
export const boringOnChainQueueAbi = [
    // ── Write ─────────────────────────────────────────────────────────────
    {
        name: "requestOnChainWithdraw",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            { name: "assetOut", type: "address" },
            { name: "amountOfShares", type: "uint128" },
            { name: "discount", type: "uint16" }, // BPS, e.g. 100 = 1%
            { name: "secondsToDeadline", type: "uint24" },
        ],
        outputs: [{ name: "requestId", type: "bytes32" }],
    },
    {
        name: "requestOnChainWithdrawWithPermit",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            { name: "assetOut", type: "address" },
            { name: "amountOfShares", type: "uint128" },
            { name: "discount", type: "uint16" },
            { name: "secondsToDeadline", type: "uint24" },
            { name: "permitDeadline", type: "uint256" },
            { name: "v", type: "uint8" },
            { name: "r", type: "bytes32" },
            { name: "s", type: "bytes32" },
        ],
        outputs: [{ name: "requestId", type: "bytes32" }],
    },
    {
        name: "cancelOnChainWithdraw",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            {
                name: "request",
                type: "tuple",
                components: [
                    { name: "user", type: "address" },
                    { name: "assetOut", type: "address" },
                    { name: "amountOfShares", type: "uint128" },
                    { name: "amountOfAssets", type: "uint128" },
                    { name: "creationTime", type: "uint40" },
                    { name: "secondsToMaturity", type: "uint24" },
                    { name: "secondsToDeadline", type: "uint24" },
                ],
            },
        ],
        outputs: [],
    },
    // ── Read ──────────────────────────────────────────────────────────────
    {
        name: "withdrawAssets",
        type: "function",
        stateMutability: "view",
        inputs: [{ name: "asset", type: "address" }],
        outputs: [
            { name: "allowWithdraws", type: "bool" },
            { name: "secondsToMaturity", type: "uint24" },
            { name: "minimumSecondsToDeadline", type: "uint24" },
            { name: "minDiscount", type: "uint16" },
            { name: "maxDiscount", type: "uint16" },
            { name: "minimumShares", type: "uint96" },
            { name: "withdrawCapacity", type: "uint256" },
        ],
    },
    {
        name: "previewAssetsOut",
        type: "function",
        stateMutability: "view",
        inputs: [
            { name: "assetOut", type: "address" },
            { name: "amountOfShares", type: "uint128" },
            { name: "discount", type: "uint16" },
        ],
        outputs: [{ name: "assetsOut", type: "uint256" }],
    },
    {
        name: "isPaused",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ name: "", type: "bool" }],
    },
    // ── Events ────────────────────────────────────────────────────────────
    {
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
    },
    {
        name: "OnChainWithdrawCancelled",
        type: "event",
        inputs: [
            { name: "requestId", type: "bytes32", indexed: true },
            { name: "user", type: "address", indexed: true },
            { name: "timestamp", type: "uint256", indexed: false },
        ],
    },
];
//# sourceMappingURL=boringOnChainQueue.js.map