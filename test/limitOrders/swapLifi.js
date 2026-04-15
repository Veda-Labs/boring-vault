import { ethers } from "ethers";
import "dotenv/config";

// ==================== CONFIG ====================

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";

// Deployed on mainnet — update after deploy
const SWAPPER       = "DEPLOY_AND_PASTE_ADDRESS_HERE";
const LIFI_ADAPTER  = "DEPLOY_AND_PASTE_ADDRESS_HERE";
const BORING_VAULT  = "0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA";
const LIFI_ROUTER   = "0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE";

const CHAIN_ID   = 1;
const SELL_AMOUNT = "1000000000000000"; // 0.001 WETH

// ==================== KNOWN SELECTORS ====================

const SELECTORS = {
    "0x5fd9ae2e": "swapTokensGeneric (GenericSwapFacet V1)",
    "0x7a5d7a4f": "swapTokensSingleV3ERC20ToERC20 (GenericSwapFacetV3)",
    "0x085ace2d": "swapTokensMultipleV3ERC20ToERC20 (GenericSwapFacetV3)",
};

// ==================== QUOTE FETCHER ====================

async function fetchQuote(fromToken, toToken, receiver) {
    const params = new URLSearchParams({
        fromChain:   CHAIN_ID,
        toChain:     CHAIN_ID,
        fromToken,
        toToken,
        fromAmount:  SELL_AMOUNT,
        fromAddress: receiver,
        toAddress:   receiver,
        slippage:    "0.03",
    });

    const res = await fetch(`https://li.quest/v1/quote?${params}`);
    const json = await res.json();
    if (!res.ok) throw new Error(`LiFi API error: ${JSON.stringify(json)}`);
    return json;
}

// ==================== MAIN: print calldata for test pinning ====================

async function main() {
    const provider = new ethers.JsonRpcProvider(process.env.MAINNET_RPC_URL);
    const blockNumber = await provider.getBlockNumber();

    console.log(`Current block: ${blockNumber}`);
    console.log(`Pin your fork to this block, then paste the calldata below.\n`);

    const pairs = [
        { from: WETH, to: USDC, label: "WETH → USDC" },
        { from: WETH, to: USDT, label: "WETH → USDT" },
    ];

    // Fall back to zero address if SWAPPER isn't deployed yet — receiver in calldata will need to be updated
    const receiver = SWAPPER === "DEPLOY_AND_PASTE_ADDRESS_HERE"
        ? "0x0000000000000000000000000000000000000001"
        : SWAPPER;

    if (SWAPPER === "DEPLOY_AND_PASTE_ADDRESS_HERE") {
        console.log("Note: SWAPPER not deployed — using placeholder receiver. Update and re-run once deployed.\n");
    }

    for (const { from, to, label } of pairs) {
        console.log("=".repeat(60));
        console.log(label);

        let quote;
        try {
            quote = await fetchQuote(from, to, receiver);
        } catch (e) {
            console.error(`  Failed: ${e.message}`);
            continue;
        }

        const calldata = quote.transactionRequest.data;
        const selector = calldata.slice(0, 10);
        const toAmount = quote.estimate?.toAmount ?? quote.action?.toAmount ?? "unknown";

        console.log(`Selector:   ${selector}  →  ${SELECTORS[selector] ?? "unknown"}`);
        console.log(`To amount:  ${toAmount}`);
        console.log(`Router:     ${quote.transactionRequest.to}`);
        console.log(`\nFull calldata (swapData):\n${calldata}`);
        console.log();
    }
}

// ==================== SUBMIT: execute a live swap via BoringSwapper ====================

async function submit() {
    if (SWAPPER === "DEPLOY_AND_PASTE_ADDRESS_HERE") {
        throw new Error("Update SWAPPER and LIFI_ADAPTER at the top of this file with deployed addresses");
    }

    const provider = new ethers.JsonRpcProvider(process.env.MAINNET_RPC_URL);
    const signer = new ethers.Wallet(process.env.BORING_DEVELOPER, provider);

    const blockNumber = await provider.getBlockNumber();
    console.log(`Current block: ${blockNumber}`);

    console.log("Fetching WETH → USDC quote from LiFi...");
    const quote = await fetchQuote(WETH, USDC, SWAPPER);

    const calldata = quote.transactionRequest.data;
    const selector = calldata.slice(0, 10);
    console.log(`Selector: ${selector}  →  ${SELECTORS[selector] ?? "unknown"}`);
    console.log(`Min out:  ${quote.estimate?.toAmountMin ?? "unknown"} USDC`);

    const abiCoder = ethers.AbiCoder.defaultAbiCoder();
    const swapConfig = abiCoder.encode(
        [
            "tuple(tuple(address tokenIn, address tokenOut) tokenRoute, address adapter, address quoteAsset, bytes swapData, uint256 slippageBps, address receiver)",
        ],
        [
            {
                tokenRoute: { tokenIn: WETH, tokenOut: USDC },
                adapter:    LIFI_ADAPTER,
                quoteAsset: USDC,
                swapData:   calldata,
                slippageBps: 100,
                receiver:   BORING_VAULT,
            },
        ]
    );

    // swap(SwapConfig) selector
    const swapSelector = "0xf1c20222";
    const txData = swapSelector + swapConfig.slice(2);

    console.log(`\nSubmitting swap to BoringSwapper at ${SWAPPER}...`);
    const tx = await signer.sendTransaction({
        to:   SWAPPER,
        data: txData,
    });
    console.log(`Tx hash: ${tx.hash}`);
    await tx.wait();
    console.log("Swap confirmed.");
}

// ==================== CLI ====================

const mode = process.argv[2];
if (mode === "submit") {
    submit().catch(console.error);
} else {
    main().catch(console.error);
}
