import {
    Sdk,
    LimitOrder,
    Extension,
    MakerTraits,
    Address,
    randBigInt,
    FetchProviderConnector,
    FeeTakerExt,
} from "@1inch/limit-order-sdk";
import "dotenv/config";

// Generate several real SDK orders across pairs/sizes and decode the extension shape of each,
// so we can see what is invariant (safe to pin on-chain) vs variable (must stay parameterized).

const API_KEY = process.env.ONEINCH_API_KEY;
const CHAIN_ID = Number(process.env.EVM_NETWORK_ID || "1");
const SWAPPER = "0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC";
const VAULT = "0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA";

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const DAI  = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const WBTC = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";

const UINT_40_MAX = (1n << 40n) - 1n;

const sdk = new Sdk({ authKey: API_KEY, networkId: CHAIN_ID, httpConnector: new FetchProviderConnector() });

// pair + amounts chosen to be roughly market-sane so the API doesn't reject the quote
const CASES = [
    { name: "WETH->USDC small",  makerAsset: WETH, takerAsset: USDC, makingAmount: 1_000_000_000_000_000n,    takingAmount: 2_200_000n },
    { name: "WETH->USDC large",  makerAsset: WETH, takerAsset: USDC, makingAmount: 5_000_000_000_000_000_000n, takingAmount: 11_000_000_000n },
    { name: "USDC->WETH",        makerAsset: USDC, takerAsset: WETH, makingAmount: 2_200_000n,                 takingAmount: 1_000_000_000_000_000n },
    { name: "USDC->DAI",         makerAsset: USDC, takerAsset: DAI,  makingAmount: 1_000_000n,                 takingAmount: 1_000_000_000_000_000_000n },
    { name: "WBTC->USDC",        makerAsset: WBTC, takerAsset: USDC, makingAmount: 1_000_000n,                 takingAmount: 600_000_000n },
    { name: "USDT->USDC",        makerAsset: USDT, takerAsset: USDC, makingAmount: 1_000_000n,                 takingAmount: 1_000_000n },
];

function fieldLens(ext) {
    return {
        makerAssetSuffix: ext.makerAssetSuffix.length,
        takerAssetSuffix: ext.takerAssetSuffix.length,
        makingAmountData: ext.makingAmountData.length,
        takingAmountData: ext.takingAmountData.length,
        predicate: ext.predicate.length,
        makerPermit: ext.makerPermit.length,
        preInteraction: ext.preInteraction.length,
        postInteraction: ext.postInteraction.length,
        customData: ext.customData.length,
    };
}

async function run() {
    const results = [];
    for (const c of CASES) {
        try {
            const makerTraits = MakerTraits.default()
                .withExpiration(BigInt(Math.floor(Date.now() / 1000)) + 36000n)
                .withNonce(randBigInt(UINT_40_MAX))
                .disablePartialFills()
                .disableMultipleFills();

            const order = await sdk.createOrder(
                {
                    makerAsset: new Address(c.makerAsset),
                    takerAsset: new Address(c.takerAsset),
                    makingAmount: c.makingAmount,
                    takingAmount: c.takingAmount,
                    maker: new Address(SWAPPER),
                    receiver: new Address(VAULT),
                },
                makerTraits
            );

            const extHex = order.extension.encode();
            const ext = Extension.decode(extHex);
            const fee = FeeTakerExt.FeeTakerExtension.fromExtension(ext);
            const data = order.build();

            const firstAddr = (hex) => (hex && hex.length >= 42 ? "0x" + hex.slice(2, 42) : hex);

            results.push({
                case: c.name,
                ok: true,
                receiver: data.receiver,
                feeTaker: fee.address?.toString?.(),
                customReceiver: fee.customReceiver?.toString?.(),
                makingGetterAddr: firstAddr(ext.makingAmountData),
                takingGetterAddr: firstAddr(ext.takingAmountData),
                postIxAddr: firstAddr(ext.postInteraction),
                resolverReceiver: fee.fees?.resolver?.receiver?.toString?.(),
                resolverFee: fee.fees?.resolver?.fee?.toString?.(),
                integratorFee: fee.fees?.integrator?.fee?.toString?.(),
                lens: fieldLens(ext),
            });
        } catch (e) {
            results.push({ case: c.name, ok: false, error: (e.message || String(e)).slice(0, 200) });
        }
    }

    console.log(JSON.stringify(results, (k, v) => (typeof v === "bigint" ? v.toString() : v), 2));

    // Invariance summary
    const ok = results.filter((r) => r.ok);
    if (ok.length > 1) {
        const allEq = (sel) => new Set(ok.map(sel)).size === 1;
        console.log("\n=== INVARIANCE (across", ok.length, "successful orders) ===");
        console.log("feeTaker stable:        ", allEq((r) => r.feeTaker), "->", [...new Set(ok.map((r) => r.feeTaker))]);
        console.log("resolverReceiver stable:", allEq((r) => r.resolverReceiver), "->", [...new Set(ok.map((r) => r.resolverReceiver))]);
        console.log("resolverFee values:     ", [...new Set(ok.map((r) => r.resolverFee))]);
        console.log("integratorFee values:   ", [...new Set(ok.map((r) => r.integratorFee))]);
        console.log("getter==feeTaker always:", ok.every((r) => r.makingGetterAddr?.toLowerCase() === r.feeTaker?.toLowerCase() && r.takingGetterAddr?.toLowerCase() === r.feeTaker?.toLowerCase() && r.postIxAddr?.toLowerCase() === r.feeTaker?.toLowerCase()));
        console.log("customReceiver==vault:  ", ok.every((r) => r.customReceiver?.toLowerCase() === VAULT.toLowerCase()));
        console.log("fields 0/1/4/5/6 empty: ", ok.every((r) => r.lens.makerAssetSuffix === 0 && r.lens.takerAssetSuffix === 0 && r.lens.predicate === 0 && r.lens.makerPermit === 0 && r.lens.preInteraction === 0));
        console.log("field length sets:      ", JSON.stringify({
            makingAmountData: [...new Set(ok.map((r) => r.lens.makingAmountData))],
            takingAmountData: [...new Set(ok.map((r) => r.lens.takingAmountData))],
            postInteraction: [...new Set(ok.map((r) => r.lens.postInteraction))],
        }));
    }
}

run().catch((e) => { console.error(e); process.exit(1); });
