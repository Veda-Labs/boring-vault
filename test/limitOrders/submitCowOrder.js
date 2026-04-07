const { ethers } = require("ethers");
require("dotenv").config();

// ==================== CONFIG ====================
const COW_API = "https://api.cow.fi/mainnet/api/v1";
const COW_SETTLEMENT = "0x9008D19f58AAbD9eD0D60971565AA8510560ab41";

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";

// Vault ecosystem
const BORING_VAULT = "0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA";
const SWAPPER = "0x43a604FfD354b08ff0631F9542B9803e882CB4FF";

// Order params
const SELL_AMOUNT = ethers.parseUnits("0.001", 18).toString();
const BUY_AMOUNT = ethers.parseUnits("2.205", 6).toString();
const VALID_TO = 1774464683; // block timestamp + 3600

// ==================== EIP-712 (matches @cowprotocol/contracts) ====================

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

function hashOrder(order) {
  return ethers.TypedDataEncoder.hash(COW_DOMAIN, ORDER_TYPE, order);
}

// ==================== ORDER ====================

function getCowOrder() {
  return {
    sellToken: WETH,
    buyToken: USDC,
    receiver: BORING_VAULT,
    sellAmount: SELL_AMOUNT,
    buyAmount: BUY_AMOUNT,
    validTo: VALID_TO,
    appData: "0x0000000000000000000000000000000000000000000000000000000000000000",
    feeAmount: "0",
    kind: "sell",
    partiallyFillable: false,
    sellTokenBalance: "erc20",
    buyTokenBalance: "erc20",
  };
}

// ==================== SIGNATURE ====================

function buildEip1271Signature(order) {
  const abiCoder = ethers.AbiCoder.defaultAbiCoder();

  // swapData = abi.encode(GPv2OrderData) — on-chain struct uses keccak256 for kind/balance
  const swapData = abiCoder.encode(
    [
      "tuple(address sellToken, address buyToken, address receiver, uint256 sellAmount, uint256 buyAmount, uint32 validTo, bytes32 appData, uint256 feeAmount, bytes32 kind, bool partiallyFillable, bytes32 sellTokenBalance, bytes32 buyTokenBalance)",
    ],
    [
      {
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
      },
    ]
  );

  // abi.encode(SwapConfig) — what isValidSignature decodes
  return abiCoder.encode(
    [
      "tuple(tuple(address tokenIn, address tokenOut) tokenRoute, uint8 protocolId, address quoteAsset, bytes swapData, uint256 slippageBps, address receiver)",
    ],
    [
      {
        tokenRoute: { tokenIn: WETH, tokenOut: USDC },
        protocolId: 3, // COWSWAP
        quoteAsset: USDC,
        swapData,
        slippageBps: 10,
        receiver: BORING_VAULT,
      },
    ]
  );
}

// ==================== API ====================

async function submitOrder(order, signature) {
  const payload = {
    ...order,
    signingScheme: "eip1271",
    signature,
    from: SWAPPER,
  };

  console.log("\nSubmitting order to CoW API...");

  const res = await fetch(`${COW_API}/orders`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Order submission failed: ${res.status} ${err}`);
  }

  return (await res.text()).replace(/"/g, "");
}

// ==================== MAIN ====================

async function main() {
  const order = getCowOrder();
  const orderDigest = hashOrder(order);
  const signature = buildEip1271Signature(order);

  console.log(`=== CoW Protocol Limit Order (eip1271) ===`);
  console.log(`Swapper: ${SWAPPER}`);
  console.log(`Vault:   ${BORING_VAULT}`);
  console.log(`Sell:    ${ethers.formatUnits(SELL_AMOUNT, 18)} WETH`);
  console.log(`Buy:     ${ethers.formatUnits(BUY_AMOUNT, 6)} USDC`);
  console.log(`ValidTo: ${VALID_TO}`);
  console.log(`Digest:  ${orderDigest}`);
  console.log();

  // Debug: simulate isValidSignature on mainnet
  const provider = new ethers.JsonRpcProvider(process.env.MAINNET_RPC_URL);
  const swapper = new ethers.Contract(SWAPPER, [
    "function isValidSignature(bytes32 _hash, bytes _signature) external view returns (bytes4)"
  ], provider);

  console.log("Simulating isValidSignature on-chain...");
  try {
    const calldata = swapper.interface.encodeFunctionData("isValidSignature", [orderDigest, signature]);
    const rawResult = await provider.call({ to: SWAPPER, data: calldata, from: COW_SETTLEMENT });
    console.log(`Raw result: ${rawResult}`);
    const decoded = swapper.interface.decodeFunctionResult("isValidSignature", rawResult);
    console.log(`Result: ${decoded[0]} (expected 0x1626ba7e)`);
  } catch (e) {
    // Try to decode revert data
    const revertData = e.data || e.error?.data;
    console.error(`REVERTED with data: ${revertData}`);
    if (revertData && revertData.length > 10) {
      // Try common error selectors
      const selector = revertData.slice(0, 10);
      console.error(`Error selector: ${selector}`);
      // Try decoding as string revert
      try {
        const reason = ethers.AbiCoder.defaultAbiCoder().decode(["string"], "0x" + revertData.slice(10));
        console.error(`Revert reason: ${reason[0]}`);
      } catch (_) {
        // Try known selectors from BoringSwapper
        const knownErrors = {
          "0x773bab9e": "BoringSwapper__HashMismatch",
          "0x1be1cbbe": "BoringSwapper__RouteNotApproved",
          "0xac02dec2": "BoringSwapper__ProtocolNotApproved",
          "0xfb597802": "BoringSwapper__RateLimitExceeded",
        };
        console.error(`Known error: ${knownErrors[selector] || "unknown"}`);
      }
    }
    console.error(`Full error: ${e.message}`);
    return;
  }

  // Submit
  const uid = await submitOrder(order, signature);
  console.log(`\nOrder submitted! UID: ${uid}`);
  console.log(`View: https://explorer.cow.fi/orders/${uid}`);
}

main().catch(console.error);
