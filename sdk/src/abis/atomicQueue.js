/**
 * ABI fragments for AtomicQueue.
 * Source: src/atomic-queue/AtomicQueue.sol
 *
 * The AtomicQueue implements a solver-based withdrawal system. Users submit
 * withdrawal requests that third-party solvers fulfil asynchronously.
 */
export const atomicQueueAbi = [
    // ── Request management ─────────────────────────────────────────────────
    {
        name: "updateAtomicRequest",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            { name: "offer", type: "address" },
            { name: "want", type: "address" },
            {
                name: "userRequest",
                type: "tuple",
                components: [
                    { name: "deadline", type: "uint64" },
                    { name: "atomicPrice", type: "uint88" },
                    { name: "offerAmount", type: "uint96" },
                    { name: "inSolve", type: "bool" },
                ],
            },
        ],
        outputs: [],
    },
    {
        name: "safeUpdateAtomicRequest",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
            { name: "offer", type: "address" },
            { name: "want", type: "address" },
            {
                name: "userRequest",
                type: "tuple",
                components: [
                    { name: "deadline", type: "uint64" },
                    { name: "atomicPrice", type: "uint88" },
                    { name: "offerAmount", type: "uint96" },
                    { name: "inSolve", type: "bool" },
                ],
            },
            { name: "accountant", type: "address" },
            { name: "maxDiscount", type: "uint256" },
        ],
        outputs: [],
    },
    // ── Query ─────────────────────────────────────────────────────────────
    {
        name: "getUserAtomicRequest",
        type: "function",
        stateMutability: "view",
        inputs: [
            { name: "user", type: "address" },
            { name: "offer", type: "address" },
            { name: "want", type: "address" },
        ],
        outputs: [
            {
                name: "request",
                type: "tuple",
                components: [
                    { name: "deadline", type: "uint64" },
                    { name: "atomicPrice", type: "uint88" },
                    { name: "offerAmount", type: "uint96" },
                    { name: "inSolve", type: "bool" },
                ],
            },
        ],
    },
    {
        name: "isAtomicRequestValid",
        type: "function",
        stateMutability: "view",
        inputs: [
            { name: "offer", type: "address" },
            { name: "user", type: "address" },
            {
                name: "userRequest",
                type: "tuple",
                components: [
                    { name: "deadline", type: "uint64" },
                    { name: "atomicPrice", type: "uint88" },
                    { name: "offerAmount", type: "uint96" },
                    { name: "inSolve", type: "bool" },
                ],
            },
        ],
        outputs: [{ name: "", type: "bool" }],
    },
    {
        name: "isPaused",
        type: "function",
        stateMutability: "view",
        inputs: [],
        outputs: [{ name: "", type: "bool" }],
    },
    // ── Verbose metadata (for UI status display) ───────────────────────────
    {
        name: "viewVerboseSolveMetaData",
        type: "function",
        stateMutability: "view",
        inputs: [
            { name: "offer", type: "address" },
            { name: "want", type: "address" },
            { name: "users", type: "address[]" },
        ],
        outputs: [
            {
                name: "",
                type: "tuple[]",
                components: [
                    { name: "user", type: "address" },
                    { name: "deadlineExceeded", type: "bool" },
                    { name: "zeroOfferAmount", type: "bool" },
                    { name: "insufficientOfferBalance", type: "bool" },
                    { name: "insufficientOfferAllowance", type: "bool" },
                    { name: "assetsToOffer", type: "uint256" },
                    { name: "assetsForWant", type: "uint256" },
                ],
            },
        ],
    },
    // ── Events ────────────────────────────────────────────────────────────
    {
        name: "AtomicRequestUpdated",
        type: "event",
        inputs: [
            { name: "user", type: "address", indexed: true },
            { name: "offerToken", type: "address", indexed: true },
            { name: "wantToken", type: "address", indexed: true },
            { name: "amount", type: "uint256", indexed: false },
            { name: "deadline", type: "uint64", indexed: false },
            { name: "minPrice", type: "uint88", indexed: false },
        ],
    },
    {
        name: "AtomicRequestFulfilled",
        type: "event",
        inputs: [
            { name: "user", type: "address", indexed: true },
            { name: "offerToken", type: "address", indexed: true },
            { name: "wantToken", type: "address", indexed: true },
            { name: "offerAmountSpent", type: "uint256", indexed: false },
            { name: "wantAmountReceived", type: "uint256", indexed: false },
        ],
    },
];
//# sourceMappingURL=atomicQueue.js.map