import { ethers } from "ethers";
import "dotenv/config";

// ==================== CONFIG ====================

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

const SWAPPER          = "0x1d1499e622D69689cdf9004d05Ec547d650Ff211"; // test-deployed BoringSwapper
const OPENOCEAN_ADAPTER = "0xA4AD4f68d0b91CFD19687c881e50f3A00242828c";
const BORING_VAULT     = "0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA";
const OPENOCEAN_ROUTER = "0x6352a56caadC4F1E25CD6c75970Fa768A3304e64";
const OPENOCEAN_CALLER = "0x7Baa298D36fE21Df2F6B54510Da76445661A91Ed";
const CHAIN            = "eth";

// ==================== POOL ADDRESSES ====================

// Uniswap V2 USDC/WETH — token0=USDC, token1=WETH
const WETH_USDC_V2 = "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc";

// Uniswap V3 0.05% USDC/WETH — token0=USDC, token1=WETH
const WETH_USDC_V3_005 = "0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640";

// ==================== BIT MASKS ====================

// UniV2: REVERSE_MASK (bit 255) → output is token0 instead of token1
const REVERSE_MASK     = 1n << 255n;

// UniV3: ONE_FOR_ZERO_MASK (bit 255) → zeroForOne = false (token1 → token0)
const ONE_FOR_ZERO_MASK = 1n << 255n;

// ==================== SELL AMOUNT ====================

const SELL_AMOUNT = 1_000_000_000_000_000n; // 0.001 WETH in wei

// ==================== ABIs ====================

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

// ==================== CALLDATA BUILDERS ====================

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
    const res = await fetch(`https://open-api.openocean.finance/v3/${CHAIN}/swap_quote?${params}`);
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

// ==================== MAIN ====================

async function main() {
    console.log("Building calldata...\n");

    const [swapCalldata] = await Promise.all([buildSwap()]);

    const entries = [
        { name: "swap",             calldata: swapCalldata },
        { name: "simpleSwap",       calldata: buildSimpleSwap() },
        { name: "callUniswap",      calldata: buildCallUniswap() },
        { name: "callUniswapTo",    calldata: buildCallUniswapTo() },
        { name: "uniswapV3SwapTo",  calldata: buildUniswapV3SwapTo() },
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

main().catch(console.error);
