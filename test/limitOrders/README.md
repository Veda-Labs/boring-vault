# Limit Order & Swap Testing

Scripts for submitting live orders through the BoringSwapper on mainnet.

---

## Deployed Addresses

### Vault Ecosystem
| Contract | Address |
|---|---|
| BoringVault | `0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA` |
| BoringSwapper | `0xA19a28547d07C35B2F9C71DFDF7cEBA89C41E6CC` |
| Manager | `0x1AE3346BC6d3267b860De524D5E38E19679A1DB0` |
| Accountant | `0xD1135B891143d3c5DfE158C6b4961937a27b8AE4` |
| Decoder | `0xd9Bb301D37BEB60EbeD71093Cd9c63eFd20C72f4` |
| AdapterRegistry | `0x291cf51d077F71509C0B41C26f857149Bb26D21b` |
| RolesAuthority | `0x13b92D87894E24B266A947255CD022749Fb52755` |

### Adapters
| Adapter | Address |
|---|---|
| UniswapV3Adapter | `0x0B368fc268d2BbF641b4DD29bFE01FBF19f609d1` |
| CowswapAdapter | `0x90BA671D3062fEd8B169933Ce61AC443191196a6` |
| OneInchAdapter | `0x48EE2f75E67dE1Cc686b02F81EB3dFe95341DFC1` |

### External Protocols
| Protocol | Address |
|---|---|
| 1inch Router v6 | `0x111111125421cA6dc452d289314280a0f8842A65` |
| 1inch FeeTaker | `0xc0DFdB9E7a392c3dBBE7c6FBe8FBC1789C9FE05e` |
| CoW Settlement | `0x9008D19f58AAbD9eD0D60971565AA8510560ab41` |

### Tokens (Mainnet)
| Token | Address |
|---|---|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| USDT | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |

---

## How It Works

The BoringSwapper implements EIP-1271. When a solver (CoW, 1inch) wants to fill an order, it calls `isValidSignature(orderHash, signature)` on the swapper. The signature is an ABI-encoded `SwapConfig` struct. The swapper checks that:
1. The order was previously submitted on-chain via `submitOrder`
2. The hash of the reconstructed order matches `orderHash`
3. The price is within `slippageBps` of the oracle price

This means every order must be submitted on-chain **before** being posted to an external API.

---

## 1inch Limit Orders

**Script:** `submitOneInchOrder.js`  
**Solidity:** `script/Test/TestLimitOrder.s.sol` → `_submitOneInchOrder()`

### Step 1 — Generate
```
node submitOneInchOrder.js generate
```
Creates a fresh order via the 1inch SDK (which attaches the fee extension), saves it to `order.json`, and prints the params to paste into Solidity.

### Step 2 — Paste & Broadcast
Copy `salt`, `makerTraits`, and `extension` into `_submitOneInchOrder()` in `TestLimitOrder.s.sol`, then:
```
source .env && forge script script/Test/TestLimitOrder.s.sol:TestLimitOrderScript --broadcast
```
This calls `BoringSwapper.submitOrder`, storing the order on-chain.

### Step 3 — Submit
```
node submitOneInchOrder.js submit
```
Reads `order.json`, verifies the hash matches the saved hash, builds the EIP-1271 signature (ABI-encoded `SwapConfig`), and posts to the 1inch orderbook API.

### Step 4 — Check
```
node submitOneInchOrder.js check
```
Fetches the order status from the 1inch orderbook API by hash.

---

## CoW Protocol Orders

**Script:** `submitCowOrder.js`  
**Solidity:** `script/Test/TestLimitOrder.s.sol` → `_submitCowswapOrder()`

### Step 1 — Generate
```
node submitCowOrder.js generate
```
Picks a `validTo` (now + 1 hour) and saves order params to `cow-order.json`. Prints what to paste into Solidity.

### Step 2 — Paste & Broadcast
Copy `sellAmount`, `buyAmount`, and `validTo` into `_submitCowswapOrder()` in `TestLimitOrder.s.sol`, then:
```
source .env && forge script script/Test/TestLimitOrder.s.sol:TestLimitOrderScript --broadcast
```

### Step 3 — Simulate (optional)
```
node submitCowOrder.js simulate
```
Calls `isValidSignature` on-chain via `eth_call` from the CoW settlement address. Should return `0x1626ba7e`. Useful to verify the on-chain state before submitting.

### Step 4 — Submit
```
node submitCowOrder.js submit
```
Posts the order to the CoW API with `signingScheme: eip1271`.

### Step 5 — Check
```
node submitCowOrder.js check
```
Fetches the order status from the CoW API.

---

## Regular Swaps (1inch)

**Script:** `swapOneInch.js`

Fetches a live swap quote from the 1inch swap API and prints the calldata to use in `_submitOneInchRegularSwap()`. No order.json involved — swap executes atomically.

```
node swapOneInch.js
```

Copy the printed `swapData` into `_submitOneInchRegularSwap()` and broadcast.

---

## Environment Variables

```
ONEINCH_API_KEY=
MAINNET_RPC_URL=
BORING_DEVELOPER=   # private key for broadcasting
EVM_NETWORK_ID=1
```
