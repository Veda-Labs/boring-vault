import { ethers } from "ethers";
import "dotenv/config";

const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const SWAPPER = "0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC";
const SELL_AMOUNT = "1000000000000000"; // 0.001 WETH

// Protocol encoded in bits 253-255 of the dex uint256
const PROTOCOL_UNIV3 = BigInt(1) << BigInt(253);
const PROTOCOL_CURVE = BigInt(2) << BigInt(253);

// bit 247 = 1 means zeroForOne (token0→token1)
const ZERO_FOR_ONE = BigInt(1) << BigInt(247);

// Known mainnet UniV3 pools
const WETH_DAI_POOL  = "0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8"; // WETH/DAI 0.3%  token0=DAI token1=WETH
const DAI_USDC_POOL  = "0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168"; // DAI/USDC 0.01% token0=DAI token1=USDC
const USDC_USDT_POOL = "0x3416cF6C708Da44DB2624D63ea0AAef7113527C6"; // USDC/USDT 0.01% token0=USDC token1=USDT

// Curve 3pool: coins(0)=DAI, coins(1)=USDC, coins(2)=USDT
const CURVE_3POOL = "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7";

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

// =====================================================================
// unoswap Curve: USDT → USDC via Curve 3pool
// Encoding per UnoswapRouter._curfe bit layout:
//   bits 253-255 (_PROTOCOL_OFFSET):               protocol = 2 (Curve)
//   bits 232-239 (_CURVE_TO_TOKEN_OFFSET):          j = 1 (USDC, exchange() arg)
//   bits 224-231 (_CURVE_FROM_TOKEN_OFFSET):        i = 2 (USDT, exchange() arg)
//   bits 216-223 (_CURVE_TO_COINS_ARG_OFFSET):      toCoinsIndex = 1 → coins(1) = USDC
//   bits 208-215 (_CURVE_TO_COINS_SELECTOR_OFFSET): 0 → coins(uint256) selector
//   bits 200-207 (_CURVE_FROM_COINS_ARG_OFFSET):    fromCoinsIndex = 2 → coins(2) = USDT
//   bits 192-199 (_CURVE_FROM_COINS_SELECTOR_OFFSET): 0 → coins(uint256) selector
//   bits 184-191 (_CURVE_SWAP_SELECTOR_IDX_OFFSET): 0 → exchange(int128,int128,uint256,uint256)
//   bits 0-159:                                     Curve 3pool address
const curveDex_USDT_USDC =
    BigInt(CURVE_3POOL)   // pool address (bits 0-159)
    | PROTOCOL_CURVE      // protocol = 2 (bits 253-255)
    | (1n << 232n)        // TO_TOKEN j=1 (USDC)
    | (2n << 224n)        // FROM_TOKEN i=2 (USDT)
    | (1n << 216n)        // TO_COINS_ARG = 1
    | (2n << 200n);       // FROM_COINS_ARG = 2

const unoswapCurveData = "0x83800a8e" + abiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256"],
    [BigInt(USDT), 1000000n, 0n, curveDex_USDT_USDC]
).slice(2);

// =====================================================================
// unoswap2: WETH → DAI → USDC
//   hop1: WETH/DAI pool, WETH=token1→DAI=token0, zeroForOne=false → bit247=0
//   hop2: DAI/USDC pool, DAI=token0→USDC=token1, zeroForOne=true  → bit247=1
const unoswap2Data = "0x8770ba91" + abiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "uint256"],
    [
        BigInt(WETH),
        BigInt(SELL_AMOUNT),
        0n,
        BigInt(WETH_DAI_POOL)  | PROTOCOL_UNIV3,
        BigInt(DAI_USDC_POOL)  | PROTOCOL_UNIV3 | ZERO_FOR_ONE,
    ]
).slice(2);

// unoswap3: WETH → DAI → USDC → USDT
//   hop1: WETH/DAI pool, WETH=token1→DAI=token0,   zeroForOne=false → bit247=0
//   hop2: DAI/USDC pool, DAI=token0→USDC=token1,   zeroForOne=true  → bit247=1
//   hop3: USDC/USDT pool, USDC=token0→USDT=token1, zeroForOne=true  → bit247=1
const unoswap3Data = "0x19367472" + abiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256"],
    [
        BigInt(WETH),
        BigInt(SELL_AMOUNT),
        0n,
        BigInt(WETH_DAI_POOL)  | PROTOCOL_UNIV3,
        BigInt(DAI_USDC_POOL)  | PROTOCOL_UNIV3 | ZERO_FOR_ONE,
        BigInt(USDC_USDT_POOL) | PROTOCOL_UNIV3 | ZERO_FOR_ONE,
    ]
).slice(2);

// unoswapTo/2/3: same routes but with explicit `to` as first param.
// `to` must equal msg.sender (the swapper) — the adapter enforces this.
const TO = BigInt(SWAPPER);

const unoswapToData = "0xe2c95c82" + abiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "uint256"],
    [TO, BigInt(WETH), BigInt(SELL_AMOUNT), 0n, BigInt("0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640") | PROTOCOL_UNIV3]
).slice(2);

const unoswapTo2Data = "0xea76dddf" + abiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256"],
    [TO, BigInt(WETH), BigInt(SELL_AMOUNT), 0n, BigInt(WETH_DAI_POOL) | PROTOCOL_UNIV3, BigInt(DAI_USDC_POOL) | PROTOCOL_UNIV3 | ZERO_FOR_ONE]
).slice(2);

const unoswapTo3Data = "0xf7a70056" + abiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256"],
    [TO, BigInt(WETH), BigInt(SELL_AMOUNT), 0n, BigInt(WETH_DAI_POOL) | PROTOCOL_UNIV3, BigInt(DAI_USDC_POOL) | PROTOCOL_UNIV3 | ZERO_FOR_ONE, BigInt(USDC_USDT_POOL) | PROTOCOL_UNIV3 | ZERO_FOR_ONE]
).slice(2);

console.log("=== unoswap Curve (USDT → USDC via Curve 3pool) ===");
console.log(`function: ${unoswapCurveData.slice(0, 10)}`);
console.log(unoswapCurveData);
console.log("\n=== unoswap2 (WETH → DAI → USDC) ===");
console.log(unoswap2Data);
console.log("\n=== unoswap3 (WETH → DAI → USDC → USDT) ===");
console.log(unoswap3Data);
console.log("\n=== unoswapTo (WETH → USDC, explicit to) ===");
console.log(unoswapToData);
console.log("\n=== unoswapTo2 (WETH → DAI → USDC, explicit to) ===");
console.log(unoswapTo2Data);
console.log("\n=== unoswapTo3 (WETH → DAI → USDC → USDT, explicit to) ===");
console.log(unoswapTo3Data);
