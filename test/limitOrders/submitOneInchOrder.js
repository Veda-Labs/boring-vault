import {
    Sdk,
    LimitOrder,
    Extension,
    MakerTraits,
    Address,
    randBigInt,
    FetchProviderConnector,
    getLimitOrderV4Domain,
} from "@1inch/limit-order-sdk";
import { ethers, JsonRpcProvider, FetchRequest } from "ethers";
import { readFileSync, writeFileSync } from "fs";
import "dotenv/config";

// ==================== CONFIG ====================

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const SWAPPER = "0x2802eAaa79601619D11fA83CB42fc4A7aD4f127b";
const ONEINCH_ADAPTER = "0x1c5d8ca5662E1C0c5979659c0035955C89101206";
const BORING_VAULT = "0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA";

const UINT_40_MAX = (1n << 40n) - 1n;
const API_KEY = process.env.ONEINCH_API_KEY;
const CHAIN_ID = Number(process.env.EVM_NETWORK_ID || "1");
const ORDER_FILE = "./order.json";

if (!API_KEY) {
    throw new Error("Missing ONEINCH_API_KEY in environment");
}

const sdk = new Sdk({
    authKey: API_KEY,
    networkId: CHAIN_ID,
    httpConnector: new FetchProviderConnector(),
});

// ==================== STEP 1: GENERATE ====================
// Creates the order via SDK (gets fee extension), saves to order.json
// Then paste the params into Solidity TestLimitOrder and submit on-chain

async function generate() {
    const makingAmount = 100_000n; // 0.1 USDC
    const takingAmount = 62_000_000_000_000n; // ~0.000062 WETH, tune to market before on-chain submit

    const expiresIn = 36000n; // 10 hours
    const expiration = BigInt(Math.floor(Date.now() / 1000)) + expiresIn;
    // Partial + multiple fills: the public 1inch orderbook rejects bit-invalidator (FOK) orders
    // ("Bit invalidator only supported for RFQ orders. Allow partial and multiple fills..."). This
    // shape uses the RemainingInvalidator, tracked by orderHash. OneInchAdapter.verifyLimitOrder
    // requires partialAllowed == multipleAllowed, so both flags must be on, and filledAmount reads
    // the RemainingInvalidator slot for this shape.
    const makerTraits = MakerTraits.default()
        .withExpiration(expiration)
        .allowPartialFills()
        .allowMultipleFills();

    if (makerTraits.isBitInvalidatorMode()) {
        throw new Error("makerTraits must NOT be BitInvalidator mode; backend only accepts RemainingInvalidator (partial+multiple) orders");
    }
    const NO_PARTIAL_FILLS_FLAG = 1n << 255n;
    const ALLOW_MULTIPLE_FILLS_FLAG = 1n << 254n;
    const t = makerTraits.asBigInt();
    if ((t & NO_PARTIAL_FILLS_FLAG) !== 0n) {
        throw new Error("NO_PARTIAL_FILLS_FLAG (bit 255) must be clear");
    }
    if ((t & ALLOW_MULTIPLE_FILLS_FLAG) === 0n) {
        throw new Error("ALLOW_MULTIPLE_FILLS_FLAG (bit 254) must be set");
    }

    console.log("Creating order via SDK...");
    const order = await sdk.createOrder(
        {
            makerAsset: new Address(USDC),
            takerAsset: new Address(WETH),
            makingAmount,
            takingAmount,
            maker: new Address(SWAPPER),
            receiver: new Address(BORING_VAULT),
        },
        makerTraits
    );

    const orderData = order.build();
    const extensionHex = order.extension.encode();
    const orderHash = order.getOrderHash(CHAIN_ID);

    // Save to file so step 3 can reuse the exact same order
    const saved = {
        salt: orderData.salt.toString(),
        maker: orderData.maker,
        receiver: orderData.receiver,
        makerAsset: orderData.makerAsset,
        takerAsset: orderData.takerAsset,
        makingAmount: orderData.makingAmount.toString(),
        takingAmount: orderData.takingAmount.toString(),
        makerTraits: orderData.makerTraits.toString(),
        extension: extensionHex,
        orderHash,
    };
    writeFileSync(ORDER_FILE, JSON.stringify(saved, null, 2));
    console.log(`\nOrder saved to ${ORDER_FILE}`);

    console.log("\n=== Order Details ===");
    console.log(JSON.stringify(saved, null, 2));

    console.log("\n=== Paste into Solidity TestLimitOrder ===");
    console.log(`salt:        ${saved.salt}`);
    console.log(`makerTraits: ${saved.makerTraits}`);
    console.log(`receiver:    ${saved.receiver}`);
    console.log(`makingAmount:${saved.makingAmount}`);
    console.log(`takingAmount:${saved.takingAmount}`);
    console.log(`extension:   ${extensionHex}`);
    console.log(`\nExpected hash: ${orderHash}`);
}

// ==================== STEP 2: VERIFY ====================
// After submitting on-chain, verify the hashes match

function verify() {
    const saved = JSON.parse(readFileSync(ORDER_FILE, "utf-8"));

    // Compute hash using ethers TypedDataEncoder (same as SDK)
    const domain = getLimitOrderV4Domain(CHAIN_ID);
    const ORDER_TYPE = {
        Order: [
            { name: "salt", type: "uint256" },
            { name: "maker", type: "address" },
            { name: "receiver", type: "address" },
            { name: "makerAsset", type: "address" },
            { name: "takerAsset", type: "address" },
            { name: "makingAmount", type: "uint256" },
            { name: "takingAmount", type: "uint256" },
            { name: "makerTraits", type: "uint256" },
        ],
    };
    const jsHash = ethers.TypedDataEncoder.hash(domain, ORDER_TYPE, {
        salt: saved.salt,
        maker: saved.maker,
        receiver: saved.receiver,
        makerAsset: saved.makerAsset,
        takerAsset: saved.takerAsset,
        makingAmount: saved.makingAmount,
        takingAmount: saved.takingAmount,
        makerTraits: saved.makerTraits,
    });

    console.log("Saved hash:   ", saved.orderHash);
    console.log("Computed hash: ", jsHash);
    console.log("Match:         ", saved.orderHash === jsHash ? "YES" : "NO");
}

// ==================== STEP 3: SUBMIT ====================
// Reads order.json, reconstructs the order, builds EIP-1271 signature, submits to API

async function submit() {
    const saved = JSON.parse(readFileSync(ORDER_FILE, "utf-8"));

    // Reconstruct the LimitOrder from saved data + extension
    const ext = Extension.decode(saved.extension);
    const order = LimitOrder.fromDataAndExtension(
        {
            salt: BigInt(saved.salt),
            maker: saved.maker,
            receiver: saved.receiver,
            makerAsset: saved.makerAsset,
            takerAsset: saved.takerAsset,
            makingAmount: BigInt(saved.makingAmount),
            takingAmount: BigInt(saved.takingAmount),
            makerTraits: BigInt(saved.makerTraits),
        },
        ext
    );

    const orderHash = order.getOrderHash(CHAIN_ID);
    console.log("Order hash:", orderHash);
    console.log("Saved hash:", saved.orderHash);
    if (orderHash !== saved.orderHash) {
        console.error("HASH MISMATCH — aborting");
        return;
    }

    // Build EIP-1271 signature: abi.encode(SwapConfig)
    const abiCoder = ethers.AbiCoder.defaultAbiCoder();

    const swapData = abiCoder.encode(
        [
            "tuple(uint256 salt, address maker, address receiver, address makerAsset, address takerAsset, uint256 makingAmount, uint256 takingAmount, uint256 makerTraits)",
            "bytes",
        ],
        [
            {
                salt: saved.salt,
                maker: saved.maker,
                receiver: saved.receiver,
                makerAsset: saved.makerAsset,
                takerAsset: saved.takerAsset,
                makingAmount: saved.makingAmount,
                takingAmount: saved.takingAmount,
                makerTraits: saved.makerTraits,
            },
            saved.extension,
        ]
    );

    const signature = abiCoder.encode(
        [
            "tuple(tuple(address tokenIn, address tokenOut) tokenRoute, address adapter, address quoteAsset, bytes swapData, uint256 slippageBps, address receiver)",
        ],
        [
            {
                tokenRoute: { tokenIn: USDC, tokenOut: WETH },
                adapter: ONEINCH_ADAPTER,
                quoteAsset: USDC,
                swapData,
                slippageBps: 500,
                receiver: BORING_VAULT,
            },
        ]
    );

    console.log("\nSubmitting order to 1inch API...");
    try {
        await sdk.submitOrder(order, signature);
        console.log("Order submitted successfully!");
        console.log(`Order hash: ${orderHash}`);
    } catch (e) {
        console.error("API error:", e.message?.slice(0, 500));
    }
}

// ==================== STEP 4: CHECK ====================
// Looks up the saved order hash on the 1inch orderbook API

async function check() {
    const saved = JSON.parse(readFileSync(ORDER_FILE, "utf-8"));
    const url = `https://api.1inch.dev/orderbook/v4.0/${CHAIN_ID}/order/${saved.orderHash}`;
    const res = await fetch(url, {
        headers: { Authorization: `Bearer ${API_KEY}` },
    });
    const data = await res.json();
    if (!res.ok) {
        console.error(`API error ${res.status}:`, JSON.stringify(data, null, 2));
        return;
    }
    console.log("Order hash:", saved.orderHash);
    console.log(JSON.stringify(data, null, 2));
}

// ==================== SUBMIT RAW (NO FEE TAKER) ====================
// Builds a plain limit order WITHOUT any FeeTaker extension — receiver = boring vault, no extension —
// and POSTs it raw to the orderbook endpoint, to see whether the backend rejects orders with no fee taker.
// NOTE: read the response REASON, not just accept/reject. A rejection that mentions the signature / ERC-1271
// is a different failure (the order isn't approvedHashes-set on-chain) and does NOT prove a fee-taker
// requirement. A rejection mentioning fee/extension/receiver, or an acceptance, is the signal we want.

async function submitRaw() {
    const makingAmount = 100_000n; // 0.1 USDC
    const takingAmount = 62_000_000_000_000n; // ~0.000062 WETH, tune to market before on-chain submit
    const expiration = BigInt(Math.floor(Date.now() / 1000)) + 36000n;

    const makerTraits = MakerTraits.default()
        .withExpiration(expiration)
        .allowPartialFills()
        .allowMultipleFills();

    // Plain LimitOrder: no extension, receiver = vault directly.
    const order = new LimitOrder(
        {
            makerAsset: new Address(USDC),
            takerAsset: new Address(WETH),
            makingAmount,
            takingAmount,
            maker: new Address(SWAPPER),
            receiver: new Address(BORING_VAULT),
        },
        makerTraits
    );

    const data = order.build();
    const extensionHex = order.extension.encode(); // expect "0x" — no fee taker
    const orderHash = order.getOrderHash(CHAIN_ID);

    console.log("hasExtension flag:", makerTraits.hasExtension());
    console.log("extension:", extensionHex, "(expect 0x)");
    console.log("receiver:", data.receiver, "(boring vault)");
    console.log("orderHash:", orderHash);

    // ERC-1271 signature blob = abi.encode(SwapConfig), extension = 0x
    const abiCoder = ethers.AbiCoder.defaultAbiCoder();
    const swapData = abiCoder.encode(
        [
            "tuple(uint256 salt, address maker, address receiver, address makerAsset, address takerAsset, uint256 makingAmount, uint256 takingAmount, uint256 makerTraits)",
            "bytes",
        ],
        [
            {
                salt: data.salt,
                maker: data.maker,
                receiver: data.receiver,
                makerAsset: data.makerAsset,
                takerAsset: data.takerAsset,
                makingAmount: data.makingAmount,
                takingAmount: data.takingAmount,
                makerTraits: data.makerTraits,
            },
            extensionHex,
        ]
    );
    const signature = abiCoder.encode(
        [
            "tuple(tuple(address tokenIn, address tokenOut) tokenRoute, address adapter, address quoteAsset, bytes swapData, uint256 slippageBps, address receiver)",
        ],
        [
            {
                tokenRoute: { tokenIn: USDC, tokenOut: WETH },
                adapter: ONEINCH_ADAPTER,
                quoteAsset: USDC,
                swapData,
                slippageBps: 500,
                receiver: BORING_VAULT,
            },
        ]
    );

    const url = `https://api.1inch.dev/orderbook/v4.1/${CHAIN_ID}/`; // SDK posts to ${base}/${chain}/
    const body = {
        orderHash,
        signature,
        data: {
            makerAsset: data.makerAsset,
            takerAsset: data.takerAsset,
            maker: data.maker,
            receiver: data.receiver,
            makingAmount: String(data.makingAmount),
            takingAmount: String(data.takingAmount),
            salt: String(data.salt),
            extension: extensionHex,
            makerTraits: String(data.makerTraits),
        },
    };

    console.log("\nPOST", url);
    const res = await fetch(url, {
        method: "POST",
        headers: { Authorization: `Bearer ${API_KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });
    const text = await res.text();
    console.log("status:", res.status);
    console.log("response:", text);
}

// ==================== CLI ====================

const mode = process.argv[2];
if (mode === "generate") {
    generate().catch(console.error);
} else if (mode === "verify") {
    verify();
} else if (mode === "submit") {
    submit().catch(console.error);
} else if (mode === "check") {
    check().catch(console.error);
} else if (mode === "submitRaw") {
    submitRaw().catch(console.error);
} else {
    console.log("Usage: node submitOneInchOrder.js <generate|verify|submit|check|submitRaw>");
    console.log("  generate  — create order via SDK, save to order.json");
    console.log("  verify    — check hash matches between JS and Solidity");
    console.log("  submit    — submit saved order to 1inch API");
    console.log("  check     — look up saved order on the 1inch orderbook");
    console.log("  submitRaw — POST a plain order WITHOUT a fee taker, print the backend's response");
}
