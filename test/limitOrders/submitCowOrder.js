import { ethers } from "ethers";
import { readFileSync, writeFileSync } from "fs";
import "dotenv/config";

// ==================== CONFIG ====================

const COW_API = "https://api.cow.fi/mainnet/api/v1";
const COW_SETTLEMENT = "0x9008D19f58AAbD9eD0D60971565AA8510560ab41";

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

const BORING_VAULT = "0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA";
const SWAPPER = "0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC";
const COWSWAP_ADAPTER = "0x90BA671D3062fEd8B169933Ce61AC443191196a6";

const ORDER_FILE = "./cow-order.json";

const COW_DOMAIN = {
    name: "Gnosis Protocol",
    version: "v2",
    chainId: 1,
    verifyingContract: COW_SETTLEMENT,
};

const ORDER_TYPE = {
    Order: [
        { name: "sellToken", type: "address" },
        { name: "buyToken", type: "address" },
        { name: "receiver", type: "address" },
        { name: "sellAmount", type: "uint256" },
        { name: "buyAmount", type: "uint256" },
        { name: "validTo", type: "uint32" },
        { name: "appData", type: "bytes32" },
        { name: "feeAmount", type: "uint256" },
        { name: "kind", type: "string" },
        { name: "partiallyFillable", type: "bool" },
        { name: "sellTokenBalance", type: "string" },
        { name: "buyTokenBalance", type: "string" },
    ],
};

// ==================== STEP 1: GENERATE ====================
// Picks a validTo, saves order params to cow-order.json, prints what to paste into Solidity

function generate() {
    const sellAmount = ethers.parseUnits("0.000001", 18).toString(); // 1e12 wei
    const buyAmount = ethers.parseUnits("0.0022", 6).toString();
    const validTo = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

    const order = {
        sellToken: WETH,
        buyToken: USDC,
        receiver: BORING_VAULT,
        sellAmount,
        buyAmount,
        validTo,
        appData: "0x0000000000000000000000000000000000000000000000000000000000000000",
        feeAmount: "0",
        kind: "sell",
        partiallyFillable: false,
        sellTokenBalance: "erc20",
        buyTokenBalance: "erc20",
    };

    const orderHash = ethers.TypedDataEncoder.hash(COW_DOMAIN, ORDER_TYPE, order);

    writeFileSync(ORDER_FILE, JSON.stringify({ ...order, orderHash }, null, 2));
    console.log(`Order saved to ${ORDER_FILE}`);

    console.log("\n=== Paste into Solidity _submitCowswapOrder ===");
    console.log(`sellAmount: ${sellAmount}`);
    console.log(`buyAmount:  ${buyAmount}`);
    console.log(`validTo:    ${validTo}`);
    console.log(`\nExpected hash: ${orderHash}`);
}

// ==================== STEP 2: SIMULATE ====================
// Calls isValidSignature on-chain to verify the swapper will accept this order

async function simulate() {
    const saved = JSON.parse(readFileSync(ORDER_FILE, "utf-8"));
    const signature = buildSignature(saved);

    const provider = new ethers.JsonRpcProvider(process.env.MAINNET_RPC_URL);
    const swapper = new ethers.Contract(SWAPPER, [
        "function isValidSignature(bytes32 _hash, bytes _signature) external view returns (bytes4)",
    ], provider);

    console.log("Simulating isValidSignature on-chain...");
    console.log(`Order hash: ${saved.orderHash}`);
    try {
        const calldata = swapper.interface.encodeFunctionData("isValidSignature", [saved.orderHash, signature]);
        const rawResult = await provider.call({ to: SWAPPER, data: calldata, from: COW_SETTLEMENT });
        const decoded = swapper.interface.decodeFunctionResult("isValidSignature", rawResult);
        const ok = decoded[0] === "0x1626ba7e";
        console.log(`Result: ${decoded[0]} — ${ok ? "VALID" : "INVALID (expected 0x1626ba7e)"}`);
    } catch (e) {
        const revertData = e.data || e.error?.data;
        console.error(`REVERTED: ${revertData}`);
        if (revertData && revertData.length > 10) {
            const selector = revertData.slice(0, 10);
            const knownErrors = {
                "0x773bab9e": "BoringSwapper__HashMismatch",
                "0xac02dec2": "BoringSwapper__AdapterNotApproved",
                "0xfb597802": "BoringSwapper__RateLimitExceeded",
            };
            console.error(`Error: ${knownErrors[selector] || selector}`);
        }
        console.error(e.message);
    }
}

// ==================== STEP 3: SUBMIT ====================
// Submits the saved order to the CoW API

async function submit() {
    const saved = JSON.parse(readFileSync(ORDER_FILE, "utf-8"));
    const signature = buildSignature(saved);

    const payload = {
        sellToken: saved.sellToken,
        buyToken: saved.buyToken,
        receiver: saved.receiver,
        sellAmount: saved.sellAmount,
        buyAmount: saved.buyAmount,
        validTo: saved.validTo,
        appData: saved.appData,
        feeAmount: saved.feeAmount,
        kind: saved.kind,
        partiallyFillable: saved.partiallyFillable,
        sellTokenBalance: saved.sellTokenBalance,
        buyTokenBalance: saved.buyTokenBalance,
        signingScheme: "eip1271",
        signature,
        from: SWAPPER,
    };

    console.log("Submitting order to CoW API...");
    const res = await fetch(`${COW_API}/orders`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });

    if (!res.ok) {
        const err = await res.text();
        throw new Error(`Submission failed: ${res.status} ${err}`);
    }

    const uid = (await res.text()).replace(/"/g, "");
    console.log(`\nOrder submitted! UID: ${uid}`);
    console.log(`View: https://explorer.cow.fi/orders/${uid}`);
}

// ==================== STEP 4: CHECK ====================
// Looks up the saved order on the CoW API

async function check() {
    const saved = JSON.parse(readFileSync(ORDER_FILE, "utf-8"));
    const res = await fetch(`${COW_API}/orders/${saved.orderHash}`);
    const data = await res.json();
    if (!res.ok) {
        console.error(`API error ${res.status}:`, JSON.stringify(data, null, 2));
        return;
    }
    console.log("Order hash:", saved.orderHash);
    console.log(JSON.stringify(data, null, 2));
}

// ==================== HELPERS ====================

function buildSignature(order) {
    const abiCoder = ethers.AbiCoder.defaultAbiCoder();

    const swapData = abiCoder.encode(
        ["tuple(address sellToken, address buyToken, address receiver, uint256 sellAmount, uint256 buyAmount, uint32 validTo, bytes32 appData, uint256 feeAmount, bytes32 kind, bool partiallyFillable, bytes32 sellTokenBalance, bytes32 buyTokenBalance)"],
        [{
            sellToken: order.sellToken,
            buyToken: order.buyToken,
            receiver: order.receiver,
            sellAmount: order.sellAmount,
            buyAmount: order.buyAmount,
            validTo: order.validTo,
            appData: order.appData,
            feeAmount: order.feeAmount,
            kind: ethers.keccak256(ethers.toUtf8Bytes("sell")),
            partiallyFillable: order.partiallyFillable,
            sellTokenBalance: ethers.keccak256(ethers.toUtf8Bytes("erc20")),
            buyTokenBalance: ethers.keccak256(ethers.toUtf8Bytes("erc20")),
        }]
    );

    return abiCoder.encode(
        ["tuple(tuple(address tokenIn, address tokenOut) tokenRoute, address adapter, address quoteAsset, bytes swapData, uint256 slippageBps, address receiver)"],
        [{
            tokenRoute: { tokenIn: WETH, tokenOut: USDC },
            adapter: COWSWAP_ADAPTER,
            quoteAsset: USDC,
            swapData,
            slippageBps: 500,
            receiver: BORING_VAULT,
        }]
    );
}

// ==================== CLI ====================

const mode = process.argv[2];
if (mode === "generate") {
    generate();
} else if (mode === "simulate") {
    simulate().catch(console.error);
} else if (mode === "submit") {
    submit().catch(console.error);
} else if (mode === "check") {
    check().catch(console.error);
} else {
    console.log("Usage: node submitCowOrder.js <generate|simulate|submit|check>");
    console.log("  generate  — pick validTo, save order params, print Solidity paste");
    console.log("  simulate  — call isValidSignature on-chain to verify swapper accepts");
    console.log("  submit    — submit saved order to CoW API");
    console.log("  check     — look up saved order on CoW API");
}
