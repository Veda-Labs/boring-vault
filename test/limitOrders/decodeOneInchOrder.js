import { Extension, FeeTakerExt } from "@1inch/limit-order-sdk";
import { readFileSync } from "fs";

// Decode a saved order's extension and print the FeeTaker fee structure.
// Usage: node decodeOneInchOrder.js [order.json]

const file = process.argv[2] || "./order.json";
const saved = JSON.parse(readFileSync(file, "utf-8"));

console.log(`=== decoding ${file} ===`);
console.log("order.receiver:", saved.receiver);

const ext = Extension.decode(saved.extension);
console.log("\n=== raw extension fields ===");
console.log("makerAssetSuffix:", ext.makerAssetSuffix);
console.log("takerAssetSuffix:", ext.takerAssetSuffix);
console.log("makingAmountData:", ext.makingAmountData);
console.log("takingAmountData:", ext.takingAmountData);
console.log("predicate:", ext.predicate);
console.log("makerPermit:", ext.makerPermit);
console.log("preInteraction:", ext.preInteraction);
console.log("postInteraction:", ext.postInteraction);
console.log("customData:", ext.customData);

const fee = FeeTakerExt.FeeTakerExtension.fromExtension(ext);
console.log("\n=== FeeTaker extension (parsed) ===");
console.log("feeTaker address:", fee.address?.toString?.() ?? fee.address);
console.log("customReceiver:", fee.customReceiver?.toString?.() ?? fee.customReceiver);

const integ = fee.getIntegratorFee?.();
const res = fee.getResolverFee?.();
console.log("\n=== fees ===");
console.log("integratorFee (raw):", JSON.stringify(integ, (k, v) => (typeof v === "bigint" ? v.toString() : v)));
console.log("resolverFee   (raw):", JSON.stringify(res, (k, v) => (typeof v === "bigint" ? v.toString() : v)));

// Full object dump for anything the getters miss
console.log("\n=== full fee object ===");
console.log(JSON.stringify(fee, (k, v) => (typeof v === "bigint" ? v.toString() : v), 2));
