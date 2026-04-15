// Quick script to confirm OpenOcean Limit Order Protocol address on mainnet
// via the official @openocean.finance/limitorder-sdk

// The SDK uses CommonJS internally; import the compiled lib directly.
import { createRequire } from "module";
const require = createRequire(import.meta.url);

const sdk = require("@openocean.finance/limitorder-sdk");

// LimitOrderNodeSdk.getLimitContractAddress(chainName, mode)
// - mode undefined / not 'Fusion' / not 'Dca'  → returns the standard v2 address
const LimitOrderNodeSdk = sdk.LimitOrderNodeSdk || sdk.openoceanLimitOrderSdk;

if (LimitOrderNodeSdk && typeof LimitOrderNodeSdk.prototype?.getLimitContractAddress === "function") {
    // instantiate with dummy args — we only need getLimitContractAddress
    try {
        const inst = new LimitOrderNodeSdk({}, {});
        console.log("ETH Limit Order Protocol (standard):", inst.getLimitContractAddress("eth"));
        console.log("ETH Limit Order Protocol (Fusion):  ", inst.getLimitContractAddress("eth", "Fusion"));
    } catch (e) {
        // constructor may throw without real args — extract from source directly
        const src = require("fs").readFileSync(
            require.resolve("@openocean.finance/limitorder-sdk/lib/limitOrderNodeSdk.js"),
            "utf8"
        );
        const match = src.match(/eth:\s*"(0x[a-fA-F0-9]{40})"/);
        console.log("ETH Limit Order Protocol (from source):", match?.[1] ?? "not found");
    }
} else {
    // fallback: read source directly
    const src = require("fs").readFileSync(
        require.resolve("@openocean.finance/limitorder-sdk/lib/limitOrderNodeSdk.js"),
        "utf8"
    );
    const matches = [...src.matchAll(/eth:\s*"(0x[a-fA-F0-9]{40})"/g)];
    matches.forEach((m, i) => console.log(`eth address [${i}]: ${m[1]}`));
}
