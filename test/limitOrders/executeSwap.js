import { ethers } from "ethers";
import "dotenv/config";

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const SWAPPER = "0x38856EF84FEE4eAF6651A75dE4a3Cf7ad95BA44c";
const CHAIN_ID = 1;
const SELL_AMOUNT = "1000000000000000"; // 0.001 WETH

const API_KEY = process.env.ONEINCH_API_KEY;
if (!API_KEY) throw new Error("Missing ONEINCH_API_KEY");

const knownSelectors = {
    "0x07ed2379": "swap",
    "0x83800a8e": "unoswap",
    "0xe2c95c82": "unoswapTo",
    "0x8770ba91": "unoswap2",
    "0xea76dddf": "unoswapTo2",
    "0x19367472": "unoswap3",
    "0xf7a70056": "unoswapTo3",
    "0x9fda64bd": "fillOrder",
};

const params = new URLSearchParams({
    src: WETH,
    dst: USDC,
    amount: SELL_AMOUNT,
    from: SWAPPER,
    receiver: SWAPPER,
    slippage: "1",
    disableEstimate: "true",
    protocols: "UNISWAP_V3,UNISWAP_V2,SUSHI,CURVE",
});

const res = await fetch(`https://api.1inch.dev/swap/v6.0/${CHAIN_ID}/swap?${params}`, {
    headers: { Authorization: `Bearer ${API_KEY}` },
});

if (!res.ok) {
    console.error(`API error ${res.status}: ${await res.text()}`);
    process.exit(1);
}

const data = await res.json();

const selector = data.tx.data.slice(0, 10);
const fnName = knownSelectors[selector] ?? selector;

if (!knownSelectors[selector]) {
    console.error(`Unknown selector ${selector} — adapter does not support this routing path. Try different protocols.`);
    process.exit(1);
}

console.log(`dstAmount: ${ethers.formatUnits(data.dstAmount, 6)} USDC`);
console.log(`function:  ${fnName}`);
console.log(`\nswapData (paste into oneInchSwapData):\n${data.tx.data}`);
