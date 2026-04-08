import { ethers } from "ethers";
import "dotenv/config";

// ==================== CONFIG ====================

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const SWAPPER = "0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC";
const ONEINCH_ADAPTER = "0x48EE2f75E67dE1Cc686b02F81EB3dFe95341DFC1";
const BORING_VAULT = "0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA";
const ONEINCH_ROUTER = "0x111111125421cA6dc452d289314280a0f8842A65";

const API_KEY = process.env.ONEINCH_API_KEY;
const CHAIN_ID = 1;

if (!API_KEY) {
    throw new Error("Missing ONEINCH_API_KEY in environment");
}

// ==================== MAIN ====================

async function main() {
    const sellAmount = "1000000000000000"; // 0.001 WETH
    const slippage = 1; // 1%

    console.log("Fetching swap quote from 1inch API...");

    const params = new URLSearchParams({
        src: WETH,
        dst: USDC,
        amount: sellAmount,
        from: SWAPPER,
        receiver: SWAPPER,
        slippage: slippage.toString(),
        disableEstimate: "true",
    });

    const url = `https://api.1inch.dev/swap/v6.0/${CHAIN_ID}/swap?${params}`;
    const res = await fetch(url, {
        headers: {
            Authorization: `Bearer ${API_KEY}`,
        },
    });

    if (!res.ok) {
        const err = await res.text();
        console.error(`API error: ${res.status} ${err}`);
        return;
    }

    const data = await res.json();

    console.log("\n=== Swap Quote ===");
    console.log(`Sell:   ${ethers.formatUnits(sellAmount, 18)} WETH`);
    console.log(`Buy:    ${ethers.formatUnits(data.dstAmount, 6)} USDC`);
    console.log(`Router: ${data.tx.to}`);
    console.log(`Gas:    ${data.tx.gas}`);

    // The tx.data is the calldata to send to the 1inch router
    const swapCalldata = data.tx.data;
    const selector = swapCalldata.slice(0, 10);

    const knownSelectors = {
        "0x07ed2379": "swap",
        "0x0502b1c5": "unoswap",
        "0xe2c95c82": "unoswap2",
        "0xe2c95c83": "unoswap3",
    };
    console.log(`Function: ${knownSelectors[selector] || selector}`);

    // Build the BoringSwapper.SwapConfig
    const abiCoder = ethers.AbiCoder.defaultAbiCoder();
    const swapConfig = abiCoder.encode(
        [
            "tuple(tuple(address tokenIn, address tokenOut) tokenRoute, address adapter, address quoteAsset, bytes swapData, uint256 slippageBps, address receiver)",
        ],
        [
            {
                tokenRoute: { tokenIn: WETH, tokenOut: USDC },
                adapter: ONEINCH_ADAPTER,
                quoteAsset: USDC,
                swapData: swapCalldata,
                slippageBps: 10,
                receiver: BORING_VAULT,
            },
        ]
    );

    // Encode the full calldata for BoringSwapper.swap(SwapConfig)
    const swapSelector = "0xf1c20222"; // swap(((address,address),address,address,bytes,uint256,address))
    const boringSwapperCalldata = swapSelector + swapConfig.slice(2);

    console.log("\n=== For Solidity / Manager ===");
    console.log(`Target:   ${SWAPPER}`);
    console.log(`Calldata: ${boringSwapperCalldata.slice(0, 80)}...`);
    console.log(`\nFull 1inch calldata (swapData):\n${swapCalldata.slice(0, 80)}...`);

    // Also output the raw values for the Solidity script
    console.log("\n=== Raw Values ===");
    console.log(`swapData length: ${(swapCalldata.length - 2) / 2} bytes`);
    console.log(`dstAmount (minReturn): ${data.dstAmount}`);
    console.log(`Full swapData:\n${swapCalldata}`);
}

main().catch(console.error);
