import { ethers } from "ethers";
import { readFileSync, writeFileSync } from "fs";
import "dotenv/config";

// ==================== CONFIG ====================

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

const SWAPPER             = "0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC"; // deployed BoringSwapper
const OPENOCEAN_ADAPTER   = "0x2db93eb31209e3D9aE855bC68993AEBf4a05E45B";
const BORING_VAULT        = "0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA";
const OPENOCEAN_ROUTER    = "0x6352a56caadC4F1E25CD6c75970Fa768A3304e64";
const OPENOCEAN_CALLER    = "0x7Baa298D36fE21Df2F6B54510Da76445661A91Ed";
const OPENOCEAN_LO_PROTO  = "0xcC8d695603ce0b43D352891892FcC716c6a7C9f4"; // limit order protocol v2
const CHAIN_ID            = 1;

const ORDER_FILE = "./oo-order.json";

// ==================== POOL ADDRESSES ====================

// Uniswap V2 USDC/WETH — token0=USDC, token1=WETH
const WETH_USDC_V2 = "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc";

// Uniswap V3 0.05% USDC/WETH — token0=USDC, token1=WETH
const WETH_USDC_V3_005 = "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640";

// ==================== BIT MASKS ====================

// UniV2: REVERSE_MASK (bit 255) → output is token0 instead of token1
const REVERSE_MASK      = 1n << 255n;

// UniV3: ONE_FOR_ZERO_MASK (bit 255) → zeroForOne = false (token1 → token0)
const ONE_FOR_ZERO_MASK = 1n << 255n;

// ==================== SELL AMOUNT ====================

const SELL_AMOUNT = 1_000_000_000_000_000n; // 0.001 WETH in wei

// ==================== EIP-712 DOMAIN & TYPE ====================

const OO_DOMAIN = {
    name: "openocean Limit Order Protocol",
    version: "2",
    chainId: 1,
    verifyingContract: OPENOCEAN_LO_PROTO,
};

// Matches OpenOceanLimitOrder in DecoderCustomTypes.sol and OpenOceanAdapter.sol
const ORDER_TYPE = {
    Order: [
        { name: "salt",           type: "uint256" },
        { name: "makerAsset",     type: "address" },
        { name: "takerAsset",     type: "address" },
        { name: "maker",          type: "address" },
        { name: "receiver",       type: "address" },
        { name: "allowedSender",  type: "address" },
        { name: "makingAmount",   type: "uint256" },
        { name: "takingAmount",   type: "uint256" },
        { name: "makerAssetData", type: "bytes" },
        { name: "takerAssetData", type: "bytes" },
        { name: "getMakerAmount", type: "bytes" },
        { name: "getTakerAmount", type: "bytes" },
        { name: "predicate",      type: "bytes" },
        { name: "permit",         type: "bytes" },
        { name: "interaction",    type: "bytes" },
    ],
};

// ==================== ABIs (for regular swap calldata) ====================

const IFACE = new ethers.Interface([
    // swap()
    `function swap(
        address caller,
        tuple(address srcToken, address dstToken, address srcReceiver, address dstReceiver,
              uint256 amount, uint256 minReturnAmount, uint256 guaranteedAmount,
              uint256 flags, address referrer, bytes permit) desc,
        tuple(uint256 target, uint256 gasLimit, uint256 value, bytes data)[] calls
    ) returns (uint256)`,

    // simpleSwap()
    `function simpleSwap(
        address caller,
        tuple(address srcToken, address dstToken, address srcReceiver, address dstReceiver,
              uint256 amount, uint256 minReturnAmount,
              uint256 flags, address referrer, bytes permit) desc,
        tuple(uint256 target, uint256 gasLimit, uint256 value, bytes data)[] calls
    ) returns (uint256)`,

    // callUniswap()
    `function callUniswap(
        address srcToken,
        uint256 amount,
        uint256 minReturn,
        bytes32[] pools
    ) returns (uint256)`,

    // callUniswapTo()
    `function callUniswapTo(
        address srcToken,
        uint256 amount,
        uint256 minReturn,
        bytes32[] pools,
        address recipient
    ) returns (uint256)`,

    // uniswapV3SwapTo()
    `function uniswapV3SwapTo(
        address recipient,
        uint256 amount,
        uint256 minReturn,
        uint256[] pools
    ) returns (uint256)`,
]);

// ==================== REGULAR SWAP CALLDATA BUILDERS ====================

// swap() — live from API so the router can actually execute it
async function buildSwap() {
    const params = new URLSearchParams({
        inTokenAddress: WETH,
        outTokenAddress: USDC,
        amount: "0.001",
        gasPrice: "5",
        slippage: "1",
        account: SWAPPER,
    });
    const res = await fetch(`https://open-api.openocean.finance/v3/eth/swap_quote?${params}`);
    const json = await res.json();
    if (json.code !== 200) throw new Error(`API error: ${JSON.stringify(json)}`);
    return json.data.data;
}

// simpleSwap() — manually constructed; empty calls[] so router will fail but adapter validates
function buildSimpleSwap() {
    return IFACE.encodeFunctionData("simpleSwap", [
        OPENOCEAN_CALLER,
        {
            srcToken:        WETH,
            dstToken:        USDC,
            srcReceiver:     OPENOCEAN_CALLER,
            dstReceiver:     SWAPPER,
            amount:          SELL_AMOUNT,
            minReturnAmount: 0n,
            flags:           0n,
            referrer:        ethers.ZeroAddress,
            permit:          "0x",
        },
        [], // no call descriptions — swap fails at router, but adapter passes
    ]);
}

// callUniswap() — single-hop UniV2, selling WETH (token1) → USDC (token0), REVERSE_MASK set
function buildCallUniswap() {
    const pool = BigInt(WETH_USDC_V2) | REVERSE_MASK;
    return IFACE.encodeFunctionData("callUniswap", [
        WETH,
        SELL_AMOUNT,
        0n,
        [ethers.toBeHex(pool, 32)],
    ]);
}

// callUniswapTo() — same as callUniswap but with explicit recipient = SWAPPER
function buildCallUniswapTo() {
    const pool = BigInt(WETH_USDC_V2) | REVERSE_MASK;
    return IFACE.encodeFunctionData("callUniswapTo", [
        WETH,
        SELL_AMOUNT,
        0n,
        [ethers.toBeHex(pool, 32)],
        SWAPPER,
    ]);
}

// uniswapV3SwapTo() — single-hop UniV3, selling WETH (token1) → USDC (token0), ONE_FOR_ZERO_MASK set
function buildUniswapV3SwapTo() {
    const pool = BigInt(WETH_USDC_V3_005) | ONE_FOR_ZERO_MASK;
    return IFACE.encodeFunctionData("uniswapV3SwapTo", [
        SWAPPER,
        SELL_AMOUNT,
        0n,
        [pool],
    ]);
}

// ==================== LIMIT ORDER COMMANDS ====================

// STEP 1: Generate — build order, compute hash, save to oo-order.json, print Solidity params
async function generate() {
    const makingAmount = 1_000_000_000_000_000n; // 0.001 WETH
    const takingAmount = 2_250_000n;             // 2.25 USDC (~$2250/ETH, ~3.8% below oracle)

    // Random salt — low entropy is fine since the order is fully constrained by the hash
    const salt = BigInt(Math.floor(Math.random() * 2 ** 52));

    // All dynamic bytes fields MUST be empty — the adapter enforces this
    const order = {
        salt,
        makerAsset:     WETH,
        takerAsset:     USDC,
        maker:          SWAPPER,
        receiver:       BORING_VAULT,
        allowedSender:  ethers.ZeroAddress,
        makingAmount,
        takingAmount,
        makerAssetData: "0x",
        takerAssetData: "0x",
        getMakerAmount: "0x",
        getTakerAmount: "0x",
        predicate:      "0x",
        permit:         "0x",
        interaction:    "0x",
    };

    const orderHash = ethers.TypedDataEncoder.hash(OO_DOMAIN, ORDER_TYPE, order);

    const saved = {
        salt:          salt.toString(),
        makerAsset:    order.makerAsset,
        takerAsset:    order.takerAsset,
        maker:         order.maker,
        receiver:      order.receiver,
        allowedSender: order.allowedSender,
        makingAmount:  makingAmount.toString(),
        takingAmount:  takingAmount.toString(),
        orderHash,
    };
    writeFileSync(ORDER_FILE, JSON.stringify(saved, null, 2));
    console.log(`Order saved to ${ORDER_FILE}`);

    console.log("\n=== Paste into _submitOpenOceanOrder() in TestLimitOrder.s.sol ===");
    console.log(`salt:         ${salt}`);
    console.log(`makingAmount: ${makingAmount}`);
    console.log(`takingAmount: ${takingAmount}`);
    console.log(`\nExpected orderHash: ${orderHash}`);
}

// STEP 2: Submit — read oo-order.json, build EIP-1271 signature, POST to OpenOcean API
async function submit() {
    const saved = JSON.parse(readFileSync(ORDER_FILE, "utf-8"));

    if (OPENOCEAN_ADAPTER === "DEPLOY_AND_PASTE_ADDRESS_HERE") {
        throw new Error("Update OPENOCEAN_ADAPTER at the top of this file with the deployed adapter address");
    }

    const abiCoder = ethers.AbiCoder.defaultAbiCoder();

    // swapData = abi.encode(OpenOceanLimitOrder)
    const swapData = abiCoder.encode(
        [
            "tuple(uint256 salt, address makerAsset, address takerAsset, address maker, address receiver, address allowedSender, uint256 makingAmount, uint256 takingAmount, bytes makerAssetData, bytes takerAssetData, bytes getMakerAmount, bytes getTakerAmount, bytes predicate, bytes permit, bytes interaction)",
        ],
        [
            {
                salt:          saved.salt,
                makerAsset:    saved.makerAsset,
                takerAsset:    saved.takerAsset,
                maker:         saved.maker,
                receiver:      saved.receiver,
                allowedSender: saved.allowedSender,
                makingAmount:  saved.makingAmount,
                takingAmount:  saved.takingAmount,
                makerAssetData: "0x",
                takerAssetData: "0x",
                getMakerAmount: "0x",
                getTakerAmount: "0x",
                predicate:      "0x",
                permit:         "0x",
                interaction:    "0x",
            },
        ]
    );

    // EIP-1271 signature = abi.encode(SwapConfig) — verified on-chain by BoringSwapper.isValidSignature
    const signature = abiCoder.encode(
        [
            "tuple(tuple(address tokenIn, address tokenOut) tokenRoute, address adapter, address quoteAsset, bytes swapData, uint256 slippageBps, address receiver)",
        ],
        [
            {
                tokenRoute: { tokenIn: WETH, tokenOut: USDC },
                adapter:    OPENOCEAN_ADAPTER,
                quoteAsset: USDC,
                swapData,
                slippageBps: 500,
                receiver:    BORING_VAULT,
            },
        ]
    );

    console.log("Order hash:", saved.orderHash);
    console.log("Submitting to OpenOcean limit order API...");

    const body = {
        orderMaker:  SWAPPER,
        makerAsset:  saved.makerAsset,
        takerAsset:  saved.takerAsset,
        makerAmount: saved.makingAmount,
        takerAmount: saved.takingAmount,
        expireTime:  0, // no expiry — order valid until cancelled
        data: {
            salt:           saved.salt,
            makerAsset:     saved.makerAsset,
            takerAsset:     saved.takerAsset,
            maker:          saved.maker,
            receiver:       saved.receiver,
            allowedSender:  saved.allowedSender,
            makingAmount:   saved.makingAmount,
            takingAmount:   saved.takingAmount,
            makerAssetData: "0x",
            takerAssetData: "0x",
            getMakerAmount: "0x",
            getTakerAmount: "0x",
            predicate:      "0x",
            permit:         "0x",
            interaction:    "0x",
        },
        signature,
        orderHash: saved.orderHash,
    };

    try {
        const res = await fetch(`https://open-api.openocean.finance/v2/${CHAIN_ID}/limit-order`, {
            method:  "POST",
            headers: { "Content-Type": "application/json" },
            body:    JSON.stringify(body),
        });
        const data = await res.json();
        if (!res.ok) {
            console.error(`API error ${res.status}:`, JSON.stringify(data, null, 2));
            return;
        }
        console.log("Order submitted successfully!");
        console.log(JSON.stringify(data, null, 2));
    } catch (e) {
        console.error("Request failed:", e.message);
    }
}

// STEP 3: Check — look up the saved order on the OpenOcean orderbook
async function check() {
    const saved = JSON.parse(readFileSync(ORDER_FILE, "utf-8"));
    const res = await fetch(
        `https://open-api.openocean.finance/v2/${CHAIN_ID}/limit-order/address/${SWAPPER}`
    );
    const data = await res.json();
    if (!res.ok) {
        console.error(`API error ${res.status}:`, JSON.stringify(data, null, 2));
        return;
    }
    // Find our specific order by hash
    const orders = Array.isArray(data) ? data : (data.data ?? []);
    const match = orders.find(o => o.orderHash?.toLowerCase() === saved.orderHash.toLowerCase());
    if (match) {
        console.log("Order found:");
        console.log(JSON.stringify(match, null, 2));
    } else {
        console.log(`Order ${saved.orderHash} not found. All orders:`);
        console.log(JSON.stringify(orders, null, 2));
    }
}

// ==================== REGULAR SWAP CALLDATA OUTPUT ====================

async function printSwapCalldata() {
    console.log("Building calldata...\n");

    const [swapCalldata] = await Promise.all([buildSwap()]);

    const entries = [
        { name: "swap",            calldata: swapCalldata },
        { name: "simpleSwap",      calldata: buildSimpleSwap() },
        { name: "callUniswap",     calldata: buildCallUniswap() },
        { name: "callUniswapTo",   calldata: buildCallUniswapTo() },
        { name: "uniswapV3SwapTo", calldata: buildUniswapV3SwapTo() },
    ];

    for (const { name, calldata } of entries) {
        const sel = calldata.slice(0, 10);
        console.log(`${"=".repeat(60)}`);
        console.log(`${name} (${sel})`);
        console.log(`length: ${(calldata.length - 2) / 2} bytes`);
        console.log(`Full swapData:\n${calldata}`);
        console.log();
    }
}

// ==================== CLI ====================

const mode = process.argv[2];
if (mode === "generate") {
    generate().catch(console.error);
} else if (mode === "submit") {
    submit().catch(console.error);
} else if (mode === "check") {
    check().catch(console.error);
} else {
    // Default: print swap calldata (original behavior)
    printSwapCalldata().catch(console.error);
}
